import AppKit
import SwiftUI

/// AppDelegate manages the menubar status item, settings popover,
/// and coordinates GestureEngine, WindowTracker, and OverlayController.
class AppDelegate: NSObject, NSApplicationDelegate {

    // MARK: - Properties

    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var gestureEngine: GestureEngine!
    private var windowTracker: WindowTracker!
    private var overlayController: OverlayController!
    private var eventMonitor: Any?

    /// The most recently known frontmost window ID.
    private var currentFrontmostWindowID: CGWindowID = 0

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        // --- Menubar icon ---
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(
                systemSymbolName: "aqi.medium",
                accessibilityDescription: "Haze"
            )
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
        }

        // --- Settings popover ---
        popover = NSPopover()
        popover.contentSize = NSSize(width: 300, height: 560)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(
            rootView: SettingsPopoverView()
        )

        // --- Window Tracker ---
        windowTracker = WindowTracker()
        windowTracker.onFrontmostWindowChanged = { [weak self] windowID in
            guard let self else { return }
            self.currentFrontmostWindowID = windowID
            if self.overlayController.isActive {
                self.overlayController.reorder(belowWindowNumber: windowID)
            }
        }

        // --- Overlay Controller ---
        overlayController = OverlayController()

        // --- Gesture Engine ---
        gestureEngine = GestureEngine()
        gestureEngine.onShakeDetected = { [weak self] in
            guard let self else { return }
            guard SettingsStore.shared.isEnabled else { return }

            let windowID = self.currentFrontmostWindowID
            guard windowID != 0 else { return }

            self.overlayController.toggle(belowWindowNumber: windowID)
        }

        // --- Test Blur Notification ---
        NotificationCenter.default.addObserver(forName: NSNotification.Name("HazeTestBlur"), object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let windowID = self.currentFrontmostWindowID
                guard windowID != 0 else { return }
                self.overlayController.toggle(belowWindowNumber: windowID)
            }
        }

        // --- Start everything ---
        windowTracker.start()
        gestureEngine.start()

        // --- Close popover on click outside ---
        eventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }

        // --- Check permissions ---
        checkPermissions()
    }

    func applicationWillTerminate(_ notification: Notification) {
        gestureEngine.stop()
        windowTracker.stop()
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Popover

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent!
        if event.type == .rightMouseUp {
            let menu = NSMenu()
            menu.addItem(NSMenuItem(title: "About Haze", action: #selector(showAbout), keyEquivalent: ""))
            menu.addItem(NSMenuItem(title: "Check for Updates", action: #selector(checkUpdates), keyEquivalent: ""))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
            menu.addItem(NSMenuItem.separator())
            menu.addItem(NSMenuItem(title: "Quit Haze", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
            
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // reset to avoid left click showing menu
        } else {
            togglePopover(sender)
        }
    }

    @objc private func openSettingsFromMenu() {
        SettingsWindowController.shared.open()
    }

    @objc private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func checkUpdates() {
        // Sparkle integration goes here.
        // For now, just show an alert.
        let alert = NSAlert()
        alert.messageText = "Up to Date"
        alert.informativeText = "Haze is currently on the latest version."
        alert.runModal()
    }

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Ensure popover's window becomes key so it receives events
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    // MARK: - Permissions

    private func checkPermissions() {
        // Check Accessibility
        let accessibilityGranted = AXIsProcessTrusted()
        if !accessibilityGranted {
            // Prompt the user — this shows the system dialog
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
            AXIsProcessTrustedWithOptions(options)
            print("[Haze] Accessibility permission not yet granted. Requesting...")
        }
    }
}
