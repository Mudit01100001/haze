import AppKit
import QuartzCore

/// A `CALayer` that fills its bounds with a solid color at a configurable
/// opacity, providing the "dim" effect behind the active window.
///
/// Reads `dimOpacity` and `dimColorHex` from ``SettingsStore/shared`` and
/// applies them whenever ``update()`` is called.
final class DimLayer: CALayer {

    // MARK: - Initialisation

    override init() {
        super.init()
        commonInit()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        // Copy‑on‑presentation init — keep layer tree intact.
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // Disable implicit animations on the properties we mutate frequently.
        actions = [
            "backgroundColor": NSNull(),
            "opacity": NSNull(),
            "bounds": NSNull(),
            "position": NSNull(),
            "contents": NSNull(),
            "hidden": NSNull(),
            "onOrderIn": NSNull(),
            "onOrderOut": NSNull(),
            "sublayers": NSNull()
        ]

        // Apply the current settings immediately.
        update()
    }

    // MARK: - Public API

    /// Re‑reads `dimOpacity` and `dimColorHex` from ``SettingsStore`` and
    /// applies them to the layer.
    func update() {
        let store = SettingsStore.shared
        let color = Self.color(fromHex: store.dimColorHex)
        backgroundColor = color.cgColor
        opacity = Float(store.dimOpacity)
    }

    // MARK: - Hex → NSColor

    /// Converts a hex colour string (e.g. `"#FF8800"` or `"FF8800"`) into an
    /// `NSColor`. Falls back to black on parse failure.
    static func color(fromHex hex: String) -> NSColor {
        var hexSanitised = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hexSanitised.hasPrefix("#") {
            hexSanitised.removeFirst()
        }

        guard hexSanitised.count == 6,
              let intValue = UInt64(hexSanitised, radix: 16) else {
            return .black
        }

        let r = CGFloat((intValue >> 16) & 0xFF) / 255.0
        let g = CGFloat((intValue >> 8)  & 0xFF) / 255.0
        let b = CGFloat( intValue        & 0xFF) / 255.0

        return NSColor(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
