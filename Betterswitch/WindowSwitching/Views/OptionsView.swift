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
    @AppStorage("glassDarkness") private var glassDarkness = 0.16
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

            Section("Appearance") {
                LabeledContent("App icon") {
                    HStack(spacing: 14) {
                        ForEach(AppIconStyle.allCases) { style in
                            Button {
                                preferences.setAppIconStyle(style)
                            } label: {
                                AppIconChoiceView(
                                    image: iconImage(for: style),
                                    isSelected: preferences.appIconStyle == style
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(style.displayName)
                        }
                    }
                }

                Picker("Switcher layout", selection: Binding(
                    get: { preferences.switcherLayout },
                    set: preferences.setSwitcherLayout
                )) {
                    ForEach(SwitcherLayout.allCases) { layout in
                        Text(layout.displayName)
                            .tag(layout)
                    }
                }
                .pickerStyle(.menu)

                LabeledContent("Glass darkness") {
                    HStack(spacing: 10) {
                        Slider(value: $glassDarkness, in: 0...0.50)
                            .frame(width: 180)
                        Text("\(Int((glassDarkness * 200).rounded()))%")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .frame(width: 38, alignment: .trailing)
                    }
                }

                if preferences.switcherLayout == .previewThumbnails {
                    Text("Window previews may require Screen Recording permission. If previews are unavailable, Betterswitch will continue showing app icons.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
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
                shortcutRow(
                    "Show switcher",
                    shortcut: Binding(
                        get: { preferences.switcherShortcut },
                        set: preferences.setSwitcherShortcut
                    )
                )
                shortcutRow(
                    "Show switcher (alternate)",
                    shortcut: Binding(
                        get: { preferences.alternateSwitcherShortcut },
                        set: preferences.setAlternateSwitcherShortcut
                    )
                )
            }

            Section("Application") {
                shortcutRow(
                    "Open options",
                    shortcut: Binding(
                        get: { preferences.optionsShortcut },
                        set: preferences.setOptionsShortcut
                    )
                )
            }

            Section {
                Button("Restore Default Shortcuts") {
                    preferences.resetShortcuts()
                }
            } footer: {
                Text("Click a shortcut, then press one or more modifiers and a non-modifier key. Press Escape to cancel.")
            }

            if let shortcutErrorMessage = preferences.shortcutErrorMessage {
                Section {
                    Text(shortcutErrorMessage)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Shortcuts")
        .padding(.top, 8)
    }

    private func shortcutRow(_ title: String, shortcut: Binding<GlobalShortcut>) -> some View {
        LabeledContent(title) {
            ShortcutRecorder(shortcut: shortcut)
                .frame(width: 150, height: 26)
        }
    }

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String

        guard let build, build != version else { return version }
        return "\(version) (\(build))"
    }

    private func iconImage(for style: AppIconStyle) -> NSImage {
        if let image = NSImage(named: style.previewAssetName) {
            return image
        }

        return NSApp.applicationIconImage
    }
}

private struct AppIconChoiceView: View {
    let image: NSImage
    let isSelected: Bool

    var body: some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 32, height: 32)
            .padding(6)
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary, lineWidth: 1)
                }
            }
    }
}
