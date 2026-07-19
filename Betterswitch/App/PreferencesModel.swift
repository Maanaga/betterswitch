import AppKit
import Combine
import ServiceManagement

enum SwitcherLayout: String, CaseIterable, Codable, Identifiable {
    case classicList
    case previewThumbnails

    var id: Self { self }

    var displayName: String {
        switch self {
        case .classicList:
            return "Classic List"
        case .previewThumbnails:
            return "Preview Thumbnails"
        }
    }
}

enum AppIconStyle: String, CaseIterable, Codable, Identifiable {
    case standard
    case darkGlass

    var id: Self { self }

    var displayName: String {
        switch self {
        case .standard:
            return "AppIcon"
        case .darkGlass:
            return "AppIconDark"
        }
    }

    var assetName: String {
        switch self {
        case .standard:
            return "AppIcon"
        case .darkGlass:
            return "AppIconDark"
        }
    }

    var runtimeImageName: String {
        switch self {
        case .standard:
            return "AppIcon"
        case .darkGlass:
            return "AppIconDarkRuntime"
        }
    }

    var previewAssetName: String {
        switch self {
        case .standard:
            return "iconlight"
        case .darkGlass:
            return "icondark"
        }
    }
}

@MainActor
final class PreferencesModel: ObservableObject {
    private enum Keys {
        static let showMenuBarIcon = "showMenuBarIcon"
        static let switcherLayout = "switcherLayout"
        static let appIconStyle = "appIconStyle"
        static let switcherShortcut = "switcherShortcut"
        static let alternateSwitcherShortcut = "alternateSwitcherShortcut"
        static let optionsShortcut = "optionsShortcut"
    }

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var showMenuBarIcon: Bool
    @Published private(set) var switcherLayout: SwitcherLayout
    @Published private(set) var appIconStyle: AppIconStyle
    @Published private(set) var switcherShortcut: GlobalShortcut
    @Published private(set) var alternateSwitcherShortcut: GlobalShortcut
    @Published private(set) var optionsShortcut: GlobalShortcut
    @Published var errorMessage: String?
    @Published private(set) var shortcutErrorMessage: String?

    var menuBarVisibilityChanged: ((Bool) -> Void)?
    var appIconStyleChanged: ((AppIconStyle) -> Void)?
    var shortcutsChanged: (() -> String?)?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.showMenuBarIcon: true])
        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
        switcherLayout = Self.loadSwitcherLayout()
        appIconStyle = Self.loadAppIconStyle()
        switcherShortcut = Self.loadShortcut(forKey: Keys.switcherShortcut, fallback: .showSwitcher)
        alternateSwitcherShortcut = Self.loadShortcut(
            forKey: Keys.alternateSwitcherShortcut,
            fallback: .showSwitcherAlternate
        )
        optionsShortcut = Self.loadShortcut(forKey: Keys.optionsShortcut, fallback: .showOptions)
        refreshLaunchAtLoginStatus()
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            errorMessage = nil
        } catch {
            errorMessage = "Couldn’t update Launch at Login: \(error.localizedDescription)"
        }

        refreshLaunchAtLoginStatus()
    }

    func setMenuBarIconRemoved(_ removed: Bool) {
        let shouldShow = !removed
        guard shouldShow != showMenuBarIcon else { return }

        showMenuBarIcon = shouldShow
        UserDefaults.standard.set(shouldShow, forKey: Keys.showMenuBarIcon)
        menuBarVisibilityChanged?(shouldShow)
    }

    func setSwitcherLayout(_ layout: SwitcherLayout) {
        guard layout != switcherLayout else { return }

        switcherLayout = layout
        UserDefaults.standard.set(layout.rawValue, forKey: Keys.switcherLayout)
    }

    func setAppIconStyle(_ style: AppIconStyle) {
        guard style != appIconStyle else { return }

        appIconStyle = style
        UserDefaults.standard.set(style.rawValue, forKey: Keys.appIconStyle)
        appIconStyleChanged?(style)
    }

    func setSwitcherShortcut(_ shortcut: GlobalShortcut) {
        updateShortcut(shortcut, replacing: \.switcherShortcut, defaultsKey: Keys.switcherShortcut)
    }

    func setAlternateSwitcherShortcut(_ shortcut: GlobalShortcut) {
        updateShortcut(shortcut, replacing: \.alternateSwitcherShortcut, defaultsKey: Keys.alternateSwitcherShortcut)
    }

    func setOptionsShortcut(_ shortcut: GlobalShortcut) {
        updateShortcut(shortcut, replacing: \.optionsShortcut, defaultsKey: Keys.optionsShortcut)
    }

    func resetShortcuts() {
        switcherShortcut = .showSwitcher
        alternateSwitcherShortcut = .showSwitcherAlternate
        optionsShortcut = .showOptions
        saveShortcut(switcherShortcut, forKey: Keys.switcherShortcut)
        saveShortcut(alternateSwitcherShortcut, forKey: Keys.alternateSwitcherShortcut)
        saveShortcut(optionsShortcut, forKey: Keys.optionsShortcut)
        shortcutErrorMessage = shortcutsChanged?()
    }

    private func updateShortcut(
        _ shortcut: GlobalShortcut,
        replacing keyPath: ReferenceWritableKeyPath<PreferencesModel, GlobalShortcut>,
        defaultsKey: String
    ) {
        let otherShortcuts = [switcherShortcut, alternateSwitcherShortcut, optionsShortcut]
            .filter { $0 != self[keyPath: keyPath] }
        guard !otherShortcuts.contains(shortcut) else {
            shortcutErrorMessage = "That shortcut is already used by Betterswitch."
            return
        }

        let previousShortcut = self[keyPath: keyPath]
        self[keyPath: keyPath] = shortcut
        saveShortcut(shortcut, forKey: defaultsKey)

        if let registrationError = shortcutsChanged?() {
            self[keyPath: keyPath] = previousShortcut
            saveShortcut(previousShortcut, forKey: defaultsKey)
            _ = shortcutsChanged?()
            shortcutErrorMessage = registrationError
        } else {
            shortcutErrorMessage = nil
        }
    }

    private func saveShortcut(_ shortcut: GlobalShortcut, forKey key: String) {
        guard let data = try? JSONEncoder().encode(shortcut) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private static func loadShortcut(forKey key: String, fallback: GlobalShortcut) -> GlobalShortcut {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let shortcut = try? JSONDecoder().decode(GlobalShortcut.self, from: data)
        else {
            return fallback
        }
        return shortcut
    }

    private static func loadSwitcherLayout() -> SwitcherLayout {
        guard
            let rawValue = UserDefaults.standard.string(forKey: Keys.switcherLayout),
            let layout = SwitcherLayout(rawValue: rawValue)
        else {
            return .classicList
        }

        return layout
    }

    private static func loadAppIconStyle() -> AppIconStyle {
        guard
            let rawValue = UserDefaults.standard.string(forKey: Keys.appIconStyle),
            let style = AppIconStyle(rawValue: rawValue)
        else {
            return .standard
        }

        return style
    }

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
