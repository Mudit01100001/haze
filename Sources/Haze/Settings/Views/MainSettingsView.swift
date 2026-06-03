import SwiftUI

struct MainSettingsView: View {
    @State private var selectedItem: SidebarItem? = .general

    enum SidebarItem: Hashable, CaseIterable {
        case general
        case effects
        case appearance
        case menuBar
        case about
    }

    var body: some View {
        ZStack {
            NavigationSplitView {
                List(selection: $selectedItem) {
                    Section("Settings") {
                        NavigationLink(value: SidebarItem.general) {
                            Label("General", systemImage: "gearshape")
                        }
                        NavigationLink(value: SidebarItem.effects) {
                            Label("Effects & Calibration", systemImage: "slider.horizontal.3")
                        }
                        NavigationLink(value: SidebarItem.appearance) {
                            Label("Appearance", systemImage: "macwindow")
                        }
                        NavigationLink(value: SidebarItem.menuBar) {
                            Label("Menu Bar", systemImage: "menubar.rectangle")
                        }
                    }
                    
                    Section("Information") {
                        NavigationLink(value: SidebarItem.about) {
                            Label("About Haze", systemImage: "info.circle")
                        }
                    }
                }
                .listStyle(.sidebar)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 250)
            } detail: {
                Group {
                    switch selectedItem {
                    case .general:
                        GeneralConfigView()
                    case .effects:
                        EffectsConfigView()
                    case .appearance:
                        AppearanceConfigView()
                    case .menuBar:
                        MenuBarCustomizationView()
                    case .about:
                        AboutSignatureView()
                    case .none:
                        Text("Select an item")
                            .foregroundColor(.secondary)
                    }
                }
                .navigationTitle(title(for: selectedItem))
            }
            .frame(minWidth: 750, minHeight: 500)
            
            // Hidden buttons for keyboard shortcuts
            Button(action: selectPreviousItem) { EmptyView() }
                .keyboardShortcut("[", modifiers: .command)
                .hidden()
                
            Button(action: selectNextItem) { EmptyView() }
                .keyboardShortcut("]", modifiers: .command)
                .hidden()
        }
    }
    
    private func selectPreviousItem() {
        let items = SidebarItem.allCases
        guard let current = selectedItem, let index = items.firstIndex(of: current) else { return }
        let prevIndex = (index - 1 + items.count) % items.count
        selectedItem = items[prevIndex]
    }
    
    private func selectNextItem() {
        let items = SidebarItem.allCases
        guard let current = selectedItem, let index = items.firstIndex(of: current) else { return }
        let nextIndex = (index + 1) % items.count
        selectedItem = items[nextIndex]
    }
    
    private func title(for item: SidebarItem?) -> String {
        switch item {
        case .general: return "General"
        case .effects: return "Effects & Calibration"
        case .appearance: return "Appearance"
        case .menuBar: return "Menu Bar Customization"
        case .about: return "About"
        case .none: return ""
        }
    }
}
import SwiftUI

struct AppearanceConfigView: View {
    var body: some View {
        Form {
            Section {
                HStack(spacing: 20) {
                    VStack {
                        Image(nsImage: NSApplication.shared.applicationIconImage ?? NSImage())
                            .resizable()
                            .frame(width: 64, height: 64)
                        Text("Default")
                            .font(.caption)
                    }
                    // Additional app icons could be toggled here in the future
                }
                .padding(.vertical, 8)
            } header: {
                Text("App Icon")
            } footer: {
                Text("Select the icon to display in the Dock and Applications folder.")
            }
            
            Section {
                Text("Menu Bar Icon customization is coming soon.")
                    .foregroundColor(.secondary)
            } header: {
                Text("Menu Bar Icon")
            } footer: {
                Text("Choose how Haze appears in your Mac's menu bar.")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
    }
}
