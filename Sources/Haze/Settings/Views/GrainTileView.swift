import SwiftUI

/// Settings tile for grain texture controls.
struct GrainTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        DisclosureGroup(isExpanded: $settings.isGrainExpanded) {
        VStack(alignment: .leading, spacing: 10) {
            



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
                ResetSlider(value: $settings.grainIntensity, range: settings.minGrainBoundary...settings.maxGrainBoundary, defaultValue: 0.5)
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
                ResetSlider(value: $settings.grainSize, range: 0.5...4, defaultValue: 1.0)
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
                ResetSlider(value: $settings.grainSpeed, range: 0.5...3, defaultValue: 1.0)
            }
            .opacity(settings.isGrainAnimated ? 1.0 : 0.5)
            .disabled(!settings.isGrainAnimated)
        }
        } label: {
            Text("FILM GRAIN").font(.caption).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}
