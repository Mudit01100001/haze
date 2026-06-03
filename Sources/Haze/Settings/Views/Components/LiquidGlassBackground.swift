import SwiftUI

/// A custom background that applies a deep vibrant visual effect
/// to simulate "Liquid Glass" on macOS.
struct LiquidGlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .sidebar // or .underWindowBackground depending on desired translucency
        
        // Ensure the view stretches
        view.autoresizingMask = [.width, .height]
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = .sidebar
        nsView.blendingMode = .behindWindow
    }
}
