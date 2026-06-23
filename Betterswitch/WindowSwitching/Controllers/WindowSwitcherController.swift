import AppKit
import ApplicationServices
import Combine
import SwiftUI

@MainActor
final class WindowSwitcherController: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectedWindowID: UInt32?
    @Published var accessibilityEnabled = AXIsProcessTrusted()

    private var panel: NSPanel?
    private var keyboardMonitor: Any?

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        refreshWindows()
        accessibilityEnabled = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        makePanelIfNeeded()
        guard let panel else {
            return
        }

        center(panel: panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        installKeyboardMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        removeKeyboardMonitor()
    }

    func refreshWindows() {
        windows = WindowScanner.visibleWindows()
        selectedWindowID = windows.first?.id
    }

    func select(_ window: WindowInfo) {
        selectedWindowID = window.id
        activate(window)
        hide()
    }

    func moveSelection(_ direction: Int) {
        guard !windows.isEmpty else {
            return
        }

        let currentIndex = windows.firstIndex { $0.id == selectedWindowID } ?? 0
        let nextIndex = (currentIndex + direction + windows.count) % windows.count
        selectedWindowID = windows[nextIndex].id
    }

    func activateSelectedWindow() {
        guard let selectedWindowID, let window = windows.first(where: { $0.id == selectedWindowID }) else {
            hide()
            return
        }
        select(window)
    }

    private func makePanelIfNeeded() {
        guard panel == nil else {
            return
        }

        let view = WindowSwitcherView(controller: self)
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 560),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.contentView = hostingView
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        self.panel = panel
    }

    private func center(panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(760, frame.width - 80), height: min(560, frame.height - 80))
        panel.setFrame(
            NSRect(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2,
                width: size.width,
                height: size.height
            ),
            display: true
        )
    }

    private func installKeyboardMonitor() {
        removeKeyboardMonitor()
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.keyCode {
            case 53:
                hide()
                return nil
            case 36:
                activateSelectedWindow()
                return nil
            case 125:
                moveSelection(1)
                return nil
            case 126:
                moveSelection(-1)
                return nil
            default:
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let keyboardMonitor {
            NSEvent.removeMonitor(keyboardMonitor)
            self.keyboardMonitor = nil
        }
    }

    private func activate(_ window: WindowInfo) {
        guard AXIsProcessTrusted() else {
            NSRunningApplication(processIdentifier: window.processIdentifier)?.activate(options: [.activateAllWindows])
            return
        }

        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let axWindows = value as? [AXUIElement] else {
            NSRunningApplication(processIdentifier: window.processIdentifier)?.activate(options: [.activateAllWindows])
            return
        }

        for axWindow in axWindows {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? ""

            var positionValue: CFTypeRef?
            var sizeValue: CFTypeRef?
            AXUIElementCopyAttributeValue(axWindow, kAXPositionAttribute as CFString, &positionValue)
            AXUIElementCopyAttributeValue(axWindow, kAXSizeAttribute as CFString, &sizeValue)

            if title == window.windowTitle || roughlyMatches(window, position: positionValue, size: sizeValue) {
                NSRunningApplication(processIdentifier: window.processIdentifier)?.activate()
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, axWindow)
                return
            }
        }

        NSRunningApplication(processIdentifier: window.processIdentifier)?.activate(options: [.activateAllWindows])
    }

    private func roughlyMatches(_ window: WindowInfo, position: CFTypeRef?, size: CFTypeRef?) -> Bool {
        guard
            let position,
            let size,
            CFGetTypeID(position) == AXValueGetTypeID(),
            CFGetTypeID(size) == AXValueGetTypeID()
        else {
            return false
        }

        var point = CGPoint.zero
        var windowSize = CGSize.zero
        AXValueGetValue(position as! AXValue, .cgPoint, &point)
        AXValueGetValue(size as! AXValue, .cgSize, &windowSize)

        return abs(point.x - window.bounds.minX) < 8
            && abs(point.y - window.bounds.minY) < 8
            && abs(windowSize.width - window.bounds.width) < 8
            && abs(windowSize.height - window.bounds.height) < 8
    }
}
