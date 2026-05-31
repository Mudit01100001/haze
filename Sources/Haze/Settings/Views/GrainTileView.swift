import SwiftUI

/// Settings tile for grain texture controls.
struct GrainTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Text("GRAIN")
                .font(.caption)
                .foregroundStyle(.secondary)



            // Intensity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Intensity")
                        .font(.callout)
                    Spacer()
                    Text("\(Int(settings.grainIntensity * 100))%")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.grainIntensity, in: 0...1, step: 0.01)
            }

            // Size slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Size")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.grainSize, specifier: "%.1f") px")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.grainSize, in: 0.5...4, step: 0.1)
            }

            // Animation toggle
            Toggle("Animated Noise", isOn: $settings.isGrainAnimated)
                .font(.callout)
                .padding(.top, 4)

            // Speed slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Speed")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.grainSpeed, specifier: "%.1f")×")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $settings.grainSpeed, in: 0.5...3, step: 0.1)
            }
            .opacity(settings.isGrainAnimated ? 1.0 : 0.5)
            .disabled(!settings.isGrainAnimated)
        }
        .glassCard()
    }
}
