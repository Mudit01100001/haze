import SwiftUI
import AppKit

/// Main entry point for Haze.
/// Uses NSApplicationDelegateAdaptor to wire up the AppKit AppDelegate
/// which manages the menubar icon, popover, and overlay lifecycle.
@main
struct HazeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // No visible windows — Haze is a menubar-only app (LSUIElement).
        // The Settings popover is managed by AppDelegate via NSPopover.
        Settings {
            EmptyView()
        }
    }
}
