import AppKit
import Sparkle


@MainActor
final class UpdateController {
    static let shared = UpdateController()

    private let standardUpdaterController: SPUStandardUpdaterController
    let isConfigured: Bool

    private init() {
        let publicKey = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
        let updaterIsConfigured = publicKey?.isEmpty == false
        isConfigured = updaterIsConfigured
        standardUpdaterController = SPUStandardUpdaterController(
            startingUpdater: updaterIsConfigured,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func configureCheckForUpdatesMenuItem(_ menuItem: NSMenuItem) {
        guard isConfigured else {
            menuItem.isEnabled = false
            return
        }
        menuItem.target = standardUpdaterController
        menuItem.action = #selector(SPUStandardUpdaterController.checkForUpdates(_:))
    }

    func checkForUpdates() {
        guard isConfigured else { return }
        standardUpdaterController.checkForUpdates(nil)
    }
}
