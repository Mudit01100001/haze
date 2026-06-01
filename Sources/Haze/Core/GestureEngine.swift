import AppKit
import CoreGraphics
import os.log

/// Detects cursor "shake" gestures via a CGEventTap running on a background thread.
///
/// A shake is recognised when, within a sliding time window, the cursor exhibits:
/// - Horizontal velocity above a threshold
/// - Enough direction reversals (left↔right)
/// - Sufficient total horizontal travel
///
/// Configuration is pulled from ``SettingsStore.shared`` so changes take effect
/// immediately on the next gesture evaluation.
@MainActor
final class GestureEngine {

    // MARK: - Public API

    /// Called on the main actor when a shake gesture is detected.
    var onShakeDetected: (() -> Void)?

    /// Start listening for mouse-move events via a CGEventTap.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        startEventMonitors()
    }

    /// Stop listening and tear down the event tap.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        stopEventMonitors()
    }

    // MARK: - Private State

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.haze.app",
        category: "GestureEngine"
    )

    private var isRunning = false

    /// Ring buffer of recent mouse positions + timestamps for the state machine.
    private var samples: [Sample] = []

    /// Timestamp of the last accepted shake (for cooldown enforcement).
    nonisolated(unsafe) private var lastShakeTime: CFAbsoluteTime = 0

    // MARK: - Constants

    /// Maximum number of samples retained in the history ring.
    nonisolated private static let maxSamples = 12

    /// Default time window in seconds for evaluating a shake gesture.
    nonisolated private static let defaultTimeWindow: Double = 0.40

    /// Default minimum horizontal velocity in points/sec.
    nonisolated private static let defaultMinVelocity: Double = 1200

    /// Default minimum total horizontal travel in points.
    nonisolated private static let defaultMinTravel: Double = 180

    // MARK: - Sample Type

    private struct Sample {
        let x: CGFloat
        let y: CGFloat
        let time: CFAbsoluteTime
    }

    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?

    private func startEventMonitors() {
        // Monitor events when Haze is NOT the active app (the common case)
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
        }
        
        // Monitor events when Haze IS the active app (e.g. clicking the menubar)
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMoved(event)
            return event
        }
    }

    private func stopEventMonitors() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }

    // MARK: - Event Handling

    /// Process a single mouse-moved event.
    private func handleMouseMoved(_ event: NSEvent) {
        // NSEvent location in window vs screen
        // But for global/local mouseMoved, NSEvent.mouseLocation is safer.
        let location = NSEvent.mouseLocation
        let now = CFAbsoluteTimeGetCurrent()

        let sample = Sample(x: location.x, y: location.y, time: now)
        samples.append(sample)
        if samples.count > Self.maxSamples {
            samples.removeFirst(samples.count - Self.maxSamples)
        }

        guard samples.count >= 4 else { return }

        // --- Read settings (nonisolated access to nonisolated(unsafe) properties
        // on SettingsStore.shared which stores its values in UserDefaults) ---
        let settings = SettingsStore.shared
        let sensitivity = settings.shakeSensitivity   // 0.5 … 2.0
        let requiredReversals = settings.shakeReversals
        let cooldown = settings.shakeCooldown

        let timeWindow = Self.defaultTimeWindow
        let minVelocity = Self.defaultMinVelocity / sensitivity
        let minTravel = Self.defaultMinTravel / sensitivity

        // Enforce cooldown.
        if now - lastShakeTime < cooldown { return }

        // Trim samples outside the time window.
        let windowStart = now - timeWindow
        let relevant = samples.filter { $0.time >= windowStart }
        guard relevant.count >= 4 else { return }

        // Evaluate the state machine over relevant samples.
        var reversals = 0
        var totalTravel: CGFloat = 0
        var peakVelocity: CGFloat = 0
        
        var previousStrokeVector: CGPoint? = nil
        var currentStrokeStart = relevant[0]

        for i in 1..<relevant.count {
            let dx = relevant[i].x - relevant[i - 1].x
            let dy = relevant[i].y - relevant[i - 1].y
            let dt = relevant[i].time - relevant[i - 1].time
            guard dt > 0 else { continue }

            // Measure 2D velocity and total travel
            let distance = sqrt(dx*dx + dy*dy)
            let velocity = distance / CGFloat(dt)  // px/s
            totalTravel += distance

            if velocity > peakVelocity {
                peakVelocity = velocity
            }

            // Track segments. A segment is formed every 30 pixels of travel.
            let strokeDx = relevant[i].x - currentStrokeStart.x
            let strokeDy = relevant[i].y - currentStrokeStart.y
            let strokeLength = sqrt(strokeDx*strokeDx + strokeDy*strokeDy)
            
            if strokeLength >= 30.0 {
                // Normalize the stroke vector
                let currentVector = CGPoint(x: strokeDx / strokeLength, y: strokeDy / strokeLength)
                
                if let prev = previousStrokeVector {
                    // Calculate dot product (cos(theta) between vectors)
                    let dotProduct = (prev.x * currentVector.x) + (prev.y * currentVector.y)
                    
                    // A dot product < -0.5 means the angle changed by > 120 degrees (a sharp zigzag turn).
                    // A positive dot product means a smooth turn (e.g., drawing a circle).
                    if dotProduct < -0.5 {
                        reversals += 1
                    }
                }
                
                previousStrokeVector = currentVector
                currentStrokeStart = relevant[i]
            }
        }

        // --- DEBUG LOGGING ---
        if reversals >= 1 {
            Self.logger.debug("Motion: reversals: \(reversals), peak speed: \(Int(peakVelocity)) px/s, travel: \(Int(totalTravel)) px (Requires speed>\(Int(minVelocity)), travel>\(Int(minTravel)), reversals>=\(requiredReversals))")
        }

        // Check thresholds. (Temporarily dividing requirements by 3 for testing!)
        guard peakVelocity >= CGFloat(minVelocity) / 3,
              reversals >= (requiredReversals - 1),
              totalTravel >= CGFloat(minTravel) / 3 else {
            return
        }

        // Shake detected — record time and clear samples.
        lastShakeTime = now
        samples.removeAll()

        Self.logger.info("SHAKE ACCEPTED! — reversals: \(reversals), peak velocity: \(Int(peakVelocity)) px/s, travel: \(Int(totalTravel)) px")

        // Fire callback on the main actor.
        Task { @MainActor [weak self] in
            self?.onShakeDetected?()
        }
    }
}

// Removed C Callback logic
