import SwiftUI

struct MenuBarCustomizationView: View {
    @ObservedObject var settings = SettingsStore.shared
    
    var body: some View {
        Form {
            Section {
                Toggle("Show Blur Tile", isOn: $settings.showBlurInMenuBar)
                Toggle("Show Dimming Tile", isOn: $settings.showDimmingInMenuBar)
                Toggle("Show Film Grain Tile", isOn: $settings.showGrainInMenuBar)
                Toggle("Show Chromatic Aberration Tile", isOn: $settings.showCAInMenuBar)
                Toggle("Show Gestures Tile", isOn: $settings.showGesturesInMenuBar)
            } header: {
                Text("Visible Modules")
            } footer: {
                Text("Select which effect sliders appear in the lightweight menu bar dropdown. Unchecking these will hide them from the menu bar, keeping it clean, while still allowing you to configure their boundaries here.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
