import SwiftUI

private enum OptionsSection: String, CaseIterable, Identifiable {
    case settings = "Settings"
    case shortcuts = "Shortcuts"

    var id: Self { self }

    var symbolName: String {
        switch self {
        case .settings: "gearshape"
        case .shortcuts: "keyboard"
        }
    }
}

struct OptionsView: View {
    @ObservedObject var preferences: PreferencesModel
    @State private var selection: OptionsSection? = .settings

    var body: some View {
        NavigationSplitView {
            List(OptionsSection.allCases, selection: $selection) { section in
                Label(section.rawValue, systemImage: section.symbolName)
                    .tag(section)
            }
            .navigationSplitViewColumnWidth(min: 170, ideal: 190)
        } detail: {
            switch selection ?? .settings {
            case .settings:
                settingsView
            case .shortcuts:
                shortcutsView
            }
        }
        .frame(minWidth: 890, minHeight: 560)
    }

    private var settingsView: some View {
        Form {
            Section("General") {
                Toggle("Launch at device start", isOn: Binding(
                    get: { preferences.launchAtLoginEnabled },
                    set: preferences.setLaunchAtLoginEnabled
                ))

                Toggle("Remove icon from menu bar", isOn: Binding(
                    get: { !preferences.showMenuBarIcon },
                    set: preferences.setMenuBarIconRemoved
                ))
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }

            if let errorMessage = preferences.errorMessage {
                Section {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .padding(.top, 8)
    }

    private var shortcutsView: some View {
        Form {
            Section("Window Switcher") {
                shortcutRow("Show switcher", keys: "⌘ `")
                shortcutRow("Show switcher (alternate)", keys: "⇧ ⌘ `")
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
        .padding(.top, 8)
    }

    private func shortcutRow(_ title: String, keys: String) -> some View {
        LabeledContent(title) {
            Text(keys)
                .font(.system(.body, design: .rounded, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String

        guard let build, build != version else { return version }
        return "\(version) (\(build))"
    }
}
