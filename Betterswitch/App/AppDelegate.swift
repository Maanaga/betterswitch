import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var switcherController: WindowSwitcherController?
    private var hotKeyController: HotKeyController?
    private var preferences: PreferencesModel?
    private var optionsWindowController: OptionsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let switcherController = WindowSwitcherController()
        self.switcherController = switcherController

        let hotKeyController = HotKeyController(
            switcherAction: {
                switcherController.toggle()
            },
            optionsAction: { [weak self] in
                self?.showOptions()
            }
        )
        self.hotKeyController = hotKeyController

        let preferences = PreferencesModel()
        preferences.menuBarVisibilityChanged = { [weak self] shouldShow in
            self?.updateMenuBarVisibility(shouldShow)
        }
        self.preferences = preferences
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
        let optionsItem = NSMenuItem(title: "Options…", action: #selector(showOptions), keyEquivalent: "b")
        optionsItem.target = self
        optionsItem.keyEquivalentModifierMask = [.command, .option]
        menu.addItem(optionsItem)
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

    @objc private func showSwitcher() {
        switcherController?.show()
    }

    @objc private func showOptions() {
        optionsWindowController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
