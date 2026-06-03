import SwiftUI

/// Settings tile for lens and audio effects.
struct EffectsTileView: View {
    
    @ObservedObject private var settings = SettingsStore.shared
    
    var body: some View {
        DisclosureGroup(isExpanded: $settings.isCAExpanded) {
        VStack(alignment: .leading, spacing: 10) {
            
            
            // Boot Sound toggle
            Toggle("Premium Boot Sound", isOn: $settings.isBootSoundEnabled)
                .font(.callout)
            
            Divider()
            
            // Chromatic Aberration toggle
            Toggle("Chromatic Aberration", isOn: $settings.isChromaticAberrationEnabled)
                .font(.callout)
            
            if settings.isChromaticAberrationEnabled {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Intensity")
                            .font(.callout)
                        Spacer()
                        Text("\(settings.chromaticAberrationIntensity, specifier: "%.1f")")
                            .font(.callout)
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    ResetSlider(value: $settings.chromaticAberrationIntensity, range: settings.minCABoundary...settings.maxCABoundary, defaultValue: 10.0)
                }
                .padding(.leading, 16)
            }
        }
        } label: {
            Text("EFFECTS").font(.caption).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}
