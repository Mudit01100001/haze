import AppKit
import SwiftUI

class SettingsWindowController: NSWindowController, NSWindowDelegate {
    
    static let shared = SettingsWindowController()
    
    private init() {
        let hostingController = NSHostingController(rootView: MainSettingsView())
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.center()
        window.setFrameAutosaveName("HazeSettingsWindow")
        window.title = "Haze Settings"
        window.isReleasedWhenClosed = false
        window.contentViewController = hostingController
        
        // Ensure minimum size
        window.minSize = NSSize(width: 750, height: 500)
        
        super.init(window: window)
        window.delegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func open() {
        // Change activation policy to show the app in the Dock
        NSApp.setActivationPolicy(.regular)
        
        // Show window and bring to front
        self.showWindow(nil)
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func windowWillClose(_ notification: Notification) {
        // Revert to menu-bar only (LSUIElement behavior) when settings are closed
        NSApp.setActivationPolicy(.accessory)
    }
}
