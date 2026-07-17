import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var switcherController: WindowSwitcherController?
    private var hotKeyController: HotKeyController?
    private var preferences: PreferencesModel?
    private var optionsWindowController: OptionsWindowController?
    private let updateController = UpdateController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        let preferences = PreferencesModel()
        self.preferences = preferences

        let switcherController = WindowSwitcherController(preferences: preferences)
        self.switcherController = switcherController

        let hotKeyController = HotKeyController(
            switcherShortcut: preferences.switcherShortcut,
            alternateSwitcherShortcut: preferences.alternateSwitcherShortcut,
            optionsShortcut: preferences.optionsShortcut,
            switcherAction: {
                switcherController.toggle()
            },
            optionsAction: { [weak self] in
                self?.showOptions()
            }
        )
        self.hotKeyController = hotKeyController

        preferences.menuBarVisibilityChanged = { [weak self] shouldShow in
            self?.updateMenuBarVisibility(shouldShow)
        }
        preferences.shortcutsChanged = { [weak self] in
            self?.refreshHotKeys()
        }
        optionsWindowController = OptionsWindowController(preferences: preferences)

        updateMenuBarVisibility(preferences.showMenuBarIcon)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            showOptions()
        }
        return true
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Betterswitch")
        statusItem.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show Switcher", action: #selector(showSwitcher), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        let optionsItem = NSMenuItem(title: "Settings…", action: #selector(showOptions), keyEquivalent: "")
        optionsItem.target = self
        menu.addItem(optionsItem)
        let checkForUpdatesItem = NSMenuItem(title: "Check for Updates…", action: nil, keyEquivalent: "")
        updateController.configureCheckForUpdatesMenuItem(checkForUpdatesItem)
        menu.addItem(checkForUpdatesItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Betterswitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        self.statusItem = statusItem
    }

    private func updateMenuBarVisibility(_ shouldShow: Bool) {
        if shouldShow {
            NSApp.setActivationPolicy(.accessory)
            if statusItem == nil {
                configureStatusItem()
            }
        } else {
            if let statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
            NSApp.setActivationPolicy(.regular)
        }
    }

    private func refreshHotKeys() -> String? {
        guard let preferences, let hotKeyController else { return nil }
        return hotKeyController.update(
            switcherShortcut: preferences.switcherShortcut,
            alternateSwitcherShortcut: preferences.alternateSwitcherShortcut,
            optionsShortcut: preferences.optionsShortcut
        )
    }

    @objc private func showSwitcher() {
        switcherController?.show()
    }

    @objc private func showOptions() {
        switcherController?.dismissImmediately()
        optionsWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
