import SwiftUI

/// Settings tile for blur-related controls.
struct BlurTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        DisclosureGroup(isExpanded: $settings.isBlurExpanded) {
        VStack(alignment: .leading, spacing: 10) {
            

            // Blur-free mode toggle
            Toggle("Blur-free mode", isOn: $settings.isBlurFreeMode)
                .font(.callout)

            // Blur strength slider (hidden when blur-free mode is on)
            if !settings.isBlurFreeMode {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blur strength")
                            .font(.callout)
                        Spacer()
                        Text("\(settings.blurRadius, specifier: "%.0f")")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ResetSlider(value: $settings.blurRadius, range: settings.minBlurBoundary...settings.maxBlurBoundary, defaultValue: 20.0)
                }
            }

            Divider()

            // Dynamic Radial Blur toggle
            Toggle("Dynamic Radial Blur", isOn: $settings.isDynamicRadialBlurEnabled)
                .font(.callout)

            if settings.isDynamicRadialBlurEnabled {
                Toggle("Most Blurred in Center", isOn: $settings.invertDynamicBlur)
                    .font(.callout)
                    .padding(.leading, 16)
                    
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Blur Falloff")
                            .font(.callout)
                        Spacer()
                        Text("\(settings.dynamicBlurFalloff, specifier: "%.1f")x")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ResetSlider(value: $settings.dynamicBlurFalloff, range: settings.minFalloffBoundary...settings.maxFalloffBoundary, defaultValue: 0.2)
                }
                .padding(.leading, 16)
            }

            Divider()

            // Grayscale toggle
            Toggle("Grayscale background", isOn: $settings.isGrayscale)
                .font(.callout)

            // Mono intensity slider (only when grayscale is on)
            if settings.isGrayscale {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Mono intensity")
                            .font(.callout)
                        Spacer()
                        Text("\(Int(settings.grayscaleIntensity * 100))%")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ResetSlider(value: $settings.grayscaleIntensity, range: 0...1, defaultValue: 0.0)
                }
            }
        }
        } label: {
            Text("BLUR").font(.caption).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}
