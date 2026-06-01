import SwiftUI

/// Settings tile for lens and audio effects.
struct EffectsTileView: View {
    
    @ObservedObject private var settings = SettingsStore.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("EFFECTS")
                .font(.caption)
                .foregroundStyle(.secondary)
            
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
                    Slider(value: $settings.chromaticAberrationIntensity, in: 0...20)
                }
                .padding(.leading, 16)
            }
        }
        .glassCard()
    }
}
