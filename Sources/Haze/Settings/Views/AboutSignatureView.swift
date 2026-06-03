import SwiftUI

struct AboutSignatureView: View {
    @Environment(\.openURL) var openURL

    var body: some View {
        ZStack {
            VStack(spacing: 24) {
                // Signature Card
                VStack(spacing: 16) {
                    Image(systemName: "applelogo")
                        .font(.system(size: 32))
                        .foregroundColor(.primary)
                        .padding(.top, 16)
                    
                    HStack(spacing: 4) {
                        Text("Passionately crafted by")
                            .foregroundColor(.secondary)
                        
                        Text("Mudit")
                            .foregroundColor(.primary)
                    }
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    
                    HStack(spacing: 20) {

                        Button("Ideas / Issues?") {
                            if let url = URL(string: "https://github.com/mudit") {
                                openURL(url)
                            }
                        }
                        .buttonStyle(PillButtonStyle())
                    }
                    .padding(.top, 8)
                    
                    Text("© 2026 Mudit")
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 16)
                }
                .padding(32)
                .background(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
                        )
                )
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)
            }
        }
    }
}

// Pill Button Style
struct PillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold, design: .rounded))
            .foregroundColor(.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(configuration.isPressed ? 0.3 : 0.1))
            )
            .overlay(
                Capsule()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.2), value: configuration.isPressed)
    }
}
