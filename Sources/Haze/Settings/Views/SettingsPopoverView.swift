import SwiftUI

/// Root view embedded inside the menubar popover.
/// Presents all settings tiles in a scrollable column at 300 pt wide.
struct SettingsPopoverView: View {

    @ObservedObject private var settings = SettingsStore.shared

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header
            HStack {
                Text("Haze")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button("Test Blur") {
                    NotificationCenter.default.post(name: NSNotification.Name("HazeTestBlur"), object: nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .padding(.trailing, 4)

                Toggle("", isOn: $settings.isEnabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 10)

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Tile List
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 10) {
                    BlurTileView()
                    OverlayTileView()
                    GrainTileView()
                    GesturesTileView()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }

            Divider()
                .padding(.horizontal, 12)

            // MARK: - Footer
            HStack {
                Text("v1.0.0 · MIT")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button("Quit Haze") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundStyle(.secondary)
                .onHover { hovering in
                    if hovering {
                        NSCursor.pointingHand.push()
                    } else {
                        NSCursor.pop()
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .frame(width: 300)
        .frame(maxHeight: 520)
    }
}

// MARK: - Glass Card Modifier

/// Wraps content in an `.ultraThinMaterial` card with rounded corners.
struct GlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

extension View {
    /// Wrap the view in a translucent glass card.
    func glassCard() -> some View {
        modifier(GlassCard())
    }
}
