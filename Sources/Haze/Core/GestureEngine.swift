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
        startEventTapThread()
    }

    /// Stop listening and tear down the event tap.
    func stop() {
        guard isRunning else { return }
        isRunning = false

        if let runLoop = tapRunLoop {
            CFRunLoopStop(runLoop)
        }
        tapRunLoop = nil
        tapThread = nil
    }

    // MARK: - Private State

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.haze.app",
        category: "GestureEngine"
    )

    private var isRunning = false

    /// Dedicated thread that hosts the CGEventTap run-loop.
    private var tapThread: Thread?

    /// The CFRunLoop on the background thread (kept to allow `stop()`).
    nonisolated(unsafe) private var tapRunLoop: CFRunLoop?

    /// Ring buffer of recent mouse positions + timestamps for the state machine.
    nonisolated(unsafe) private var samples: [Sample] = []

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

    // MARK: - Background Thread Bootstrap

    private func startEventTapThread() {
        let thread = Thread { [weak self] in
            self?.runEventTap()
        }
        thread.name = "com.haze.gesture-engine"
        thread.qualityOfService = .userInteractive
        tapThread = thread
        thread.start()
    }

    /// Runs entirely on the background thread.  Sets up the CGEventTap and
    /// enters a CFRunLoop.
    nonisolated private func runEventTap() {
        // We need a raw pointer to `self` for the C callback.  Using
        // Unmanaged keeps us from preventing deinit — the reference is
        // released when the run-loop is stopped and the source removed.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        let eventMask: CGEventMask = 1 << CGEventType.mouseMoved.rawValue

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: gestureEventTapCallback,
            userInfo: selfPtr
        ) else {
            Self.logger.error("Failed to create CGEventTap — Accessibility permission may not be granted. Open System Settings → Privacy & Security → Accessibility and enable Haze.")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        let runLoop = CFRunLoopGetCurrent()
        CFRunLoopAddSource(runLoop, source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tapRunLoop = runLoop

        // Run until CFRunLoopStop() is called from `stop()`.
        CFRunLoopRun()

        // Cleanup after the run-loop exits.
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(runLoop, source, .commonModes)
    }

    // MARK: - Event Handling (called from C callback, nonisolated)

    /// Process a single mouse-moved event.  Called on the background thread.
    nonisolated fileprivate func handleMouseMoved(_ event: CGEvent) {
        let location = event.location
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
        var previousVelocitySign: Int = 0  // -1, 0, +1

        for i in 1..<relevant.count {
            let dx = relevant[i].x - relevant[i - 1].x
            let dy = relevant[i].y - relevant[i - 1].y
            let dt = relevant[i].time - relevant[i - 1].time
            guard dt > 0 else { continue }

            // Measure 2D velocity and total travel (more forgiving for natural diagonal movement)
            let distance = sqrt(dx*dx + dy*dy)
            let velocity = distance / CGFloat(dt)  // px/s
            totalTravel += distance

            if velocity > peakVelocity {
                peakVelocity = velocity
            }

            // Track direction reversals purely on the X-axis for the "shake" left-right motion
            let xVelocity = dx / CGFloat(dt)
            // Use a slight deadzone (50 px/s) to ignore tiny horizontal jitters when mostly moving vertically
            let currentSign: Int = xVelocity > 50 ? 1 : (xVelocity < -50 ? -1 : 0)
            if currentSign != 0 && previousVelocitySign != 0 && currentSign != previousVelocitySign {
                reversals += 1
            }
            if currentSign != 0 {
                previousVelocitySign = currentSign
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

// MARK: - C Callback (free function required by CGEvent.tapCreate)

/// Free function used as the CGEventTap callback.  Bridges into
/// ``GestureEngine/handleMouseMoved(_:)`` via the `userInfo` pointer.
private func gestureEventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // If the tap is disabled by the system (e.g. due to timeout), just
    // pass the event through. For `.defaultTap` taps the system will
    // automatically re-enable on the next event delivery.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        return Unmanaged.passUnretained(event)
    }

    guard type == .mouseMoved, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let engine = Unmanaged<GestureEngine>.fromOpaque(userInfo).takeUnretainedValue()
    engine.handleMouseMoved(event)

    return Unmanaged.passUnretained(event)
}
