import SwiftUI

/// Settings tile for shake-gesture detection and animation timing.
struct GesturesTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        DisclosureGroup(isExpanded: $settings.isGesturesExpanded) {
        VStack(alignment: .leading, spacing: 10) {
            

            // Sensitivity slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Sensitivity")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.shakeSensitivity, specifier: "%.1f")×")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ResetSlider(value: $settings.shakeSensitivity, range: settings.minSensitivityBoundary...settings.maxSensitivityBoundary, defaultValue: 1.0)
            }

            // Reversals stepper
            HStack {
                Text("Reversals")
                    .font(.callout)
                Spacer()
                Stepper(
                    value: $settings.shakeReversals,
                    in: 2...10
                ) {
                    Text("\(settings.shakeReversals)")
                        .font(.callout)
                        .monospacedDigit()
                        .frame(minWidth: 20, alignment: .trailing)
                }
            }

            // Cooldown slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Cooldown")
                        .font(.callout)
                    Spacer()
                    Text("\(settings.shakeCooldown, specifier: "%.1f") s")
                        .font(.callout)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                ResetSlider(value: $settings.shakeCooldown, range: settings.minCooldownBoundary...settings.maxCooldownBoundary, defaultValue: 1.0)
            }
        }
        } label: {
            Text("GESTURES").font(.caption).foregroundStyle(.secondary)
        }
        .glassCard()
    }
}
