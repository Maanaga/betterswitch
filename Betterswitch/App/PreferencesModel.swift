import AppKit
import Combine
import ServiceManagement

@MainActor
final class PreferencesModel: ObservableObject {
    private enum Keys {
        static let showMenuBarIcon = "showMenuBarIcon"
    }

    @Published private(set) var launchAtLoginEnabled = false
    @Published private(set) var showMenuBarIcon: Bool
    @Published var errorMessage: String?

    var menuBarVisibilityChanged: ((Bool) -> Void)?

    init() {
        let defaults = UserDefaults.standard
        defaults.register(defaults: [Keys.showMenuBarIcon: true])
        showMenuBarIcon = defaults.bool(forKey: Keys.showMenuBarIcon)
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

    private func refreshLaunchAtLoginStatus() {
        launchAtLoginEnabled = SMAppService.mainApp.status == .enabled
    }
}
