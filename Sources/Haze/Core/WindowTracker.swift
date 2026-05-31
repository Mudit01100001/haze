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
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                // Delay slightly because CGWindowListCopyWindowInfo takes a frame to update
                // its Z-order after an app switch notification.
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
                self?.handleAppActivation()
            }
        }

        // Fire immediately with current state.
        handleAppActivation()
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
        return Self.resolveFrontmostWindow()
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

    private func handleAppActivation() {
        guard let windowID = Self.resolveFrontmostWindow() else {
            Self.logger.debug("No suitable frontmost window found after activation.")
            return
        }

        // Only fire the callback when the window actually changed.
        guard windowID != lastReportedWindowID else { return }
        lastReportedWindowID = windowID

        Self.logger.info("Frontmost window changed: \(windowID)")
        onFrontmostWindowChanged?(windowID)
    }

    // MARK: - Window Resolution

    /// Queries the window server for all on-screen windows, filters out
    /// Haze-owned and desktop/screensaver-level windows, and returns the
    /// topmost remaining window ID.
    private static func resolveFrontmostWindow() -> CGWindowID? {
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
