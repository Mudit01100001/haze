import SwiftUI
import AppKit

/// Settings tile for the dim / overlay layer.
struct OverlayTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    /// The custom color picker binding – kept in sync with `dimColorHex`.
    @State private var customColor: Color = .black

    /// Predefined color presets (name + hex).
    private struct Preset: Identifiable {
        let id: String          // hex value or "accent"
        let label: String
        let color: Color

        var isAccent: Bool { id == "accent" }
    }

    private let presets: [Preset] = [
        Preset(id: "#000000", label: "Black",  color: .black),
        Preset(id: "#1A3B7C", label: "Navy",   color: Color(hex: "#1A3B7C")),
        Preset(id: "#8A4D00", label: "Amber",  color: Color(hex: "#8A4D00")),
        Preset(id: "#1E5E2F", label: "Forest", color: Color(hex: "#1E5E2F")),
        Preset(id: "#7D1B43", label: "Rose",   color: Color(hex: "#7D1B43")),
        Preset(id: "accent",  label: "Accent", color: .accentColor),
    ]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Text("OVERLAY")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Opacity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Opacity")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(settings.dimOpacity * 100))%")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.dimOpacity, in: 0...0.9)
            }

            Divider()

            // Color presets grid (2 rows × 3 cols)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(presets) { preset in
                    presetButton(preset)
                }
            }

            Divider()

            // Custom color picker
            HStack {
                Text("Custom")
                    .font(.callout)
                Spacer()
                ColorPicker("", selection: $customColor, supportsOpacity: false)
                    .labelsHidden()
            }
            Divider()

            // Fade In slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Fade in duration")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.fadeInDuration, specifier: "%.1f")s")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.fadeInDuration, in: 0.2...2.0)
            }

            // Fade Out slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Fade out duration")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.fadeOutDuration, specifier: "%.2f")s")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.fadeOutDuration, in: 0.1...1.0)
            }
        }
        .glassCard()
        .onAppear {
            customColor = Color(hex: settings.dimColorHex)
        }
        .onChange(of: customColor) { _, newColor in
            settings.dimColorHex = newColor.hexString
        }
    }

    // MARK: - Preset Button

    @ViewBuilder
    private func presetButton(_ preset: Preset) -> some View {
        let isSelected = isPresetSelected(preset)
        Button {
            if preset.isAccent {
                settings.dimColorHex = Color.accentColor.hexString
            } else {
                settings.dimColorHex = preset.id
            }
            customColor = Color(hex: settings.dimColorHex)
        } label: {
            VStack(spacing: 4) {
                ZStack {
                    Circle()
                        .fill(preset.color)
                        .frame(width: 28, height: 28)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 1)
                        )

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                }

                Text(preset.label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private func isPresetSelected(_ preset: Preset) -> Bool {
        if preset.isAccent {
            return settings.dimColorHex.lowercased() == Color.accentColor.hexString.lowercased()
        }
        return settings.dimColorHex.lowercased() == preset.id.lowercased()
    }
}

// MARK: - Color ↔ Hex Helpers

extension Color {
    /// Create a `Color` from a hex string like `"#0A0F1E"` or `"0A0F1E"`.
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)

        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8)  & 0xFF) / 255.0
        let b = Double( rgb        & 0xFF) / 255.0

        self.init(red: r, green: g, blue: b)
    }

    /// Returns the hex string representation (e.g. `"#0A0F1E"`).
    var hexString: String {
        guard let components = NSColor(self)
            .usingColorSpace(.sRGB)?
            .cgColor
            .components,
              components.count >= 3 else {
            return "#000000"
        }

        let r = Int(round(components[0] * 255))
        let g = Int(round(components[1] * 255))
        let b = Int(round(components[2] * 255))

        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
