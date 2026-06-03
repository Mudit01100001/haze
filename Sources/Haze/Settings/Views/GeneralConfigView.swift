import SwiftUI

struct GeneralConfigView: View {
    @ObservedObject var settings = SettingsStore.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Launch at Login", isOn: .constant(false)) // Placeholder for login item
                
            } header: {
                Text("Launch Behavior")
            } footer: {
                Text("Start Haze automatically when you log into your Mac.")
            }
            .padding(.bottom, 16)
            
            Section {
                Toggle("Enable Bootup Sound", isOn: $settings.isBootSoundEnabled)
                
                if settings.isBootSoundEnabled {
                    HStack {
                        Image(systemName: "speaker.wave.1")
                            .foregroundColor(.secondary)
                        ResetSlider(value: $settings.bootSoundVolume, range: 0...3.0, defaultValue: 1.0)
                        Image(systemName: "speaker.wave.3")
                            .foregroundColor(.secondary)
                    }
                }
                
                Toggle("Enable Turn Off Sound", isOn: $settings.isTurnOffSoundEnabled)
                
                if settings.isTurnOffSoundEnabled {
                    HStack {
                        Image(systemName: "speaker.wave.1")
                            .foregroundColor(.secondary)
                        ResetSlider(value: $settings.turnOffSoundVolume, range: 0...3.0, defaultValue: 1.0)
                        Image(systemName: "speaker.wave.3")
                            .foregroundColor(.secondary)
                    }
                }
            } header: {
                Text("Audio Feedback")
            } footer: {
                Text("A premium synth chime plays when the overlay is activated and deactivated. You can set the volume up to 300% (3.0).")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden) // Ensures the Liquid Glass shines through
    }
}
