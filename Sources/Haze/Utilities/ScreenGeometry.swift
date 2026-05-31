import AppKit

/// Lightweight utility for common screen‑geometry queries.
/// All methods reference `NSScreen.main` and are safe to call from the main thread.
enum ScreenGeometry {

    /// Returns the frame rectangle of the main screen in points.
    static func mainScreenFrame() -> NSRect {
        guard let screen = NSScreen.main else {
            return .zero
        }
        return screen.frame
    }

    /// Returns the backing scale factor (e.g. 2.0 on Retina) of the main screen.
    static func backingScaleFactor() -> CGFloat {
        guard let screen = NSScreen.main else {
            return 1.0
        }
        return screen.backingScaleFactor
    }

    /// Returns the main screen size in actual pixels (points × backingScaleFactor).
    static func screenPixelSize() -> (width: Int, height: Int) {
        let frame = mainScreenFrame()
        let scale = backingScaleFactor()
        return (
            width: Int(frame.width * scale),
            height: Int(frame.height * scale)
        )
    }
}
