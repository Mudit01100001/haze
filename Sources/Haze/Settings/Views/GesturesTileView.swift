import SwiftUI

/// Settings tile for shake-gesture detection and animation timing.
struct GesturesTileView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Section header
            Text("GESTURES")
                .font(.caption)
                .foregroundStyle(.secondary)

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
                Slider(value: $settings.shakeSensitivity, in: 0.5...2.0)
            }

            // Reversals stepper
            HStack {
                Text("Reversals")
                    .font(.callout)
                Spacer()
                Stepper(
                    value: $settings.shakeReversals,
                    in: 2...5,
                    step: 1
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
                Slider(value: $settings.shakeCooldown, in: 0.3...2.5)
            }
        }
        .glassCard()
    }
}
