import AppKit
import CoreGraphics
import os.log

/// Observes workspace application-activation notifications and resolves the
/// current frontmost window (excluding windows owned by Haze itself and any
/// desktop or screensaver-level windows).
///
/// Usage:
/// ```swift
/// let tracker = WindowTracker()
/// tracker.onFrontmostWindowChanged = { windowID in
///     print("Frontmost window: \(windowID)")
/// }
/// tracker.start()
/// ```
@MainActor
final class WindowTracker {

    // MARK: - Public API

    /// Called on the main actor whenever the frontmost window changes.
    var onFrontmostWindowChanged: ((CGWindowID) -> Void)?

    /// Begin observing workspace activation notifications.
    /// Immediately fires the callback with the current frontmost window (if any).
    func start() {
        guard !isObserving else { return }
        isObserving = true

        let center = NSWorkspace.shared.notificationCenter
        observer = center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            let targetPID = app.processIdentifier
            
            Task { @MainActor [weak self] in
                await self?.pollForAppActivation(targetPID: targetPID)
            }
        }

        // Fire immediately with current state.
        if let frontmostApp = NSWorkspace.shared.frontmostApplication {
            Task { @MainActor [weak self] in
                await self?.pollForAppActivation(targetPID: frontmostApp.processIdentifier)
            }
        }
    }

    /// Stop observing.
    func stop() {
        guard isObserving else { return }
        isObserving = false

        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
        observer = nil
        lastReportedWindowID = nil
    }

    /// Query the current frontmost window on demand.
    /// Returns `nil` if no suitable window can be found.
    func currentFrontmostWindowID() -> CGWindowID? {
        return Self.resolveFrontmostWindow(targetPID: nil)
    }

    // MARK: - Private State

    nonisolated private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.haze.app",
        category: "WindowTracker"
    )

    private var isObserving = false
    private var observer: NSObjectProtocol?

    /// The most recently reported window ID — used to avoid duplicate callbacks.
    private var lastReportedWindowID: CGWindowID?

    /// Our own PID, cached once.
    private static let ownPID = ProcessInfo.processInfo.processIdentifier

    // MARK: - Activation Handling

    /// Polls until the window server updates its internal state and puts the target PID's window at the top.
    private func pollForAppActivation(targetPID: pid_t) async {
        let maxAttempts = 20 // Max 200ms
        let interval: UInt64 = 10_000_000 // 10ms
        
        for attempt in 0..<maxAttempts {
            if let windowID = Self.resolveFrontmostWindow(targetPID: targetPID) {
                // We found a window matching the target PID at the top!
                
                guard windowID != lastReportedWindowID else { return }
                lastReportedWindowID = windowID

                Self.logger.info("Frontmost window changed (PID: \(targetPID)) to \(windowID) after \(attempt) attempts.")
                onFrontmostWindowChanged?(windowID)
                return
            }
            
            try? await Task.sleep(nanoseconds: interval)
        }
        
        // Fallback: If we exhausted all attempts, just take whatever is on top.
        if let windowID = Self.resolveFrontmostWindow(targetPID: nil) {
            guard windowID != lastReportedWindowID else { return }
            lastReportedWindowID = windowID
            Self.logger.warning("Fallback: Window changed to \(windowID) (Expected PID \(targetPID) but exhausted attempts).")
            onFrontmostWindowChanged?(windowID)
        }
    }

    // MARK: - Window Resolution

    /// Queries the window server for all on-screen windows, filters out
    /// Haze-owned and desktop/screensaver-level windows, and returns the
    /// topmost remaining window ID. If a targetPID is provided, it only returns a window if it belongs to that PID.
    private static func resolveFrontmostWindow(targetPID: pid_t?) -> CGWindowID? {
        // Request on-screen windows in front-to-back order.
        guard let infoList = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return nil
        }

        for info in infoList {
            // Owner PID — skip our own windows.
            guard let ownerPID = info[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID != ownPID else {
                continue
            }

            // Window number.
            guard let windowNumber = info[kCGWindowNumber as String] as? CGWindowID else {
                continue
            }

            // Window layer — only accept normal-level windows (layer 0).
            // Desktop, screensaver, and system overlay windows have
            // non-zero layers.
            if let layer = info[kCGWindowLayer as String] as? Int, layer != 0 {
                continue
            }

            // Require a non-trivial size to avoid menu-bar or status-item
            // windows that happen to sit at layer 0.
            if let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
               let boundsRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) {
                if boundsRect.width < 50 || boundsRect.height < 50 {
                    continue
                }
            }

            // If we are looking for a specific PID, ensure this topmost valid window belongs to it.
            if let targetPID = targetPID {
                if ownerPID == targetPID {
                    return windowNumber
                } else {
                    // The topmost valid window does NOT belong to the target PID yet.
                    // This means the WindowServer hasn't updated the order. Return nil so we keep polling.
                    return nil
                }
            }

            return windowNumber
        }

        return nil
    }

    /// Fetches the frame of a specific window by its ID.
    nonisolated static func getWindowFrame(windowID: CGWindowID) -> CGRect? {
        guard let infoList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let info = infoList.first(where: { ($0[kCGWindowNumber as String] as? CGWindowID) == windowID }),
              let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
              let boundsRect = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
        else { return nil }
        
        return boundsRect
    }
    
    /// Fetches the layer (level) of a specific window by its ID.
    nonisolated static func getWindowLevel(windowID: CGWindowID) -> Int? {
        guard let infoList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]],
              let info = infoList.first(where: { ($0[kCGWindowNumber as String] as? CGWindowID) == windowID }),
              let layer = info[kCGWindowLayer as String] as? Int
        else { return nil }
        
        return layer
    }
}
