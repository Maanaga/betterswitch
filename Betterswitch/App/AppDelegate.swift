import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var switcherController: WindowSwitcherController?
    private var hotKeyController: HotKeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let switcherController = WindowSwitcherController()
        self.switcherController = switcherController

        let hotKeyController = HotKeyController {
            switcherController.toggle()
        }
        self.hotKeyController = hotKeyController

        configureStatusItem()
    }

    private func configureStatusItem() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.stack", accessibilityDescription: "Betterswitch")
        statusItem.button?.imagePosition = .imageLeading

        let menu = NSMenu()
        let showItem = NSMenuItem(title: "Show Switcher", action: #selector(showSwitcher), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit Betterswitch", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        statusItem.menu = menu

        self.statusItem = statusItem
    }

    @objc private func showSwitcher() {
        switcherController?.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
