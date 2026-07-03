import AppKit
import SwiftUI

@MainActor
final class OptionsWindowController: NSWindowController, NSWindowDelegate {
    init(preferences: PreferencesModel) {
        let contentView = OptionsView(preferences: preferences)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 890, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Betterswitch Options"
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified
        window.contentMinSize = NSSize(width: 890, height: 560)
        window.isReleasedWhenClosed = false
        window.center()
        window.contentViewController = NSHostingController(rootView: contentView)

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else { return }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
