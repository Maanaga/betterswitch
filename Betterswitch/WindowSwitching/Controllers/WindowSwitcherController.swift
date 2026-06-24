import AppKit
import ApplicationServices
import Combine
import QuartzCore
import SwiftUI

@MainActor
final class WindowSwitcherController: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var selectedWindowID: String?
    @Published var accessibilityEnabled = AXIsProcessTrusted()
    @Published var searchText = "" {
        didSet {
            selectedWindowID = filteredWindows.first?.id
        }
    }

    private let recentSelectionKeysDefaultsKey = "recentSelectionKeys"
    private let maxRecentSelectionCount = 40
    private var panel: NSPanel?
    private var keyboardMonitor: Any?
    private var isAnimatingHide = false

    func toggle() {
        if panel?.isVisible == true {
            hide()
        } else {
            show()
        }
    }

    func show() {
        searchText = ""
        refreshWindows()
        accessibilityEnabled = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary)
        makePanelIfNeeded()
        guard let panel else {
            return
        }

        center(panel: panel)
        NSApp.activate(ignoringOtherApps: true)
        animateIn(panel)
        installKeyboardMonitor()
    }

    func hide() {
        guard let panel, panel.isVisible, !isAnimatingHide else {
            removeKeyboardMonitor()
            return
        }

        animateOut(panel)
        removeKeyboardMonitor()
    }

    func refreshWindows() {
        windows = orderedWindows(WindowScanner.runningItems())
        selectedWindowID = filteredWindows.first?.id
    }

    func select(_ window: WindowInfo) {
        selectedWindowID = window.id
        rememberSelection(window)
        activate(window)
        hide()
    }

    func moveSelection(_ direction: Int) {
        let visibleWindows = filteredWindows
        guard !visibleWindows.isEmpty else {
            return
        }

        let currentIndex = visibleWindows.firstIndex { $0.id == selectedWindowID } ?? 0
        let nextIndex = (currentIndex + direction + visibleWindows.count) % visibleWindows.count
        selectedWindowID = visibleWindows[nextIndex].id
    }

    func activateSelectedWindow() {
        guard let selectedWindowID, let window = filteredWindows.first(where: { $0.id == selectedWindowID }) else {
            hide()
            return
        }
        select(window)
    }

    var filteredWindows: [WindowInfo] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return windows
        }

        return windows.filter { $0.matchesSearch(query) }
    }

    private func makePanelIfNeeded() {
        guard panel == nil else {
            return
        }

        let view = WindowSwitcherView(controller: self)
        let hostingView = NSHostingView(rootView: view)
        hostingView.wantsLayer = true
        hostingView.layer?.backgroundColor = NSColor.clear.cgColor
        let panel = SwitcherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
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

    private func animateIn(_ panel: NSPanel) {
        let finalFrame = panel.frame
        let startFrame = scaledFrame(from: finalFrame, scale: 0.94)

        panel.alphaValue = 0
        panel.setFrame(startFrame, display: true)
        panel.makeKeyAndOrderFront(nil)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
            panel.animator().setFrame(finalFrame, display: true)
        }
    }

    private func animateOut(_ panel: NSPanel) {
        isAnimatingHide = true
        let startFrame = panel.frame
        let endFrame = scaledFrame(from: startFrame, scale: 0.96)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
            panel.animator().setFrame(endFrame, display: true)
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self else {
                    return
                }

                self.panel?.orderOut(nil)
                self.panel?.alphaValue = 1
                self.panel?.setFrame(startFrame, display: false)
                self.isAnimatingHide = false
            }
        }
    }

    private func scaledFrame(from frame: NSRect, scale: CGFloat) -> NSRect {
        let width = frame.width * scale
        let height = frame.height * scale

        return NSRect(
            x: frame.midX - width / 2,
            y: frame.midY - height / 2,
            width: width,
            height: height
        )
    }

    private func center(panel: NSPanel) {
        let screen = NSScreen.main ?? NSScreen.screens.first
        let frame = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let size = NSSize(width: min(700, frame.width - 80), height: min(560, frame.height - 80))
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

    private func orderedWindows(_ windows: [WindowInfo]) -> [WindowInfo] {
        let recentKeys = UserDefaults.standard.stringArray(forKey: recentSelectionKeysDefaultsKey) ?? []
        let recentRanks = Dictionary(uniqueKeysWithValues: recentKeys.enumerated().map { ($0.element, $0.offset) })
        let frontmostProcessIdentifier = NSWorkspace.shared.frontmostApplication?.processIdentifier

        return windows.enumerated().sorted { lhs, rhs in
            let lhsRecentRank = recentRanks[lhs.element.orderingKey] ?? Int.max
            let rhsRecentRank = recentRanks[rhs.element.orderingKey] ?? Int.max

            if lhsRecentRank != rhsRecentRank {
                return lhsRecentRank < rhsRecentRank
            }

            let lhsIsFrontmost = lhs.element.processIdentifier == frontmostProcessIdentifier
            let rhsIsFrontmost = rhs.element.processIdentifier == frontmostProcessIdentifier
            if lhsIsFrontmost != rhsIsFrontmost {
                return lhsIsFrontmost
            }

            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private func rememberSelection(_ window: WindowInfo) {
        var recentKeys = UserDefaults.standard.stringArray(forKey: recentSelectionKeysDefaultsKey) ?? []
        recentKeys.removeAll { $0 == window.orderingKey }
        recentKeys.insert(window.orderingKey, at: 0)

        if recentKeys.count > maxRecentSelectionCount {
            recentKeys.removeLast(recentKeys.count - maxRecentSelectionCount)
        }

        UserDefaults.standard.set(recentKeys, forKey: recentSelectionKeysDefaultsKey)
    }

    private func activate(_ window: WindowInfo) {
        guard window.hasWindow else {
            activateApp(processIdentifier: window.processIdentifier)
            return
        }

        guard AXIsProcessTrusted() else {
            activateApp(processIdentifier: window.processIdentifier)
            return
        }

        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let axWindows = value as? [AXUIElement] else {
            activateApp(processIdentifier: window.processIdentifier)
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

            if title == window.windowTitle || roughlyMatches(window, title: title, position: positionValue, size: sizeValue) {
                activateApp(processIdentifier: window.processIdentifier, allWindows: false)
                AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                AXUIElementSetAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, axWindow)
                return
            }
        }

        activateApp(processIdentifier: window.processIdentifier)
    }

    private func activateApp(processIdentifier: pid_t, allWindows: Bool = true) {
        guard let app = NSRunningApplication(processIdentifier: processIdentifier) else {
            return
        }

        if app.isHidden {
            app.unhide()
        }

        app.activate(options: allWindows ? [.activateAllWindows] : [])
    }

    private func roughlyMatches(_ window: WindowInfo, title: String, position: CFTypeRef?, size: CFTypeRef?) -> Bool {
        guard
            window.windowTitle == nil || window.windowTitle == title,
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

        guard let bounds = window.bounds else {
            return false
        }

        return abs(point.x - bounds.minX) < 8
            && abs(point.y - bounds.minY) < 8
            && abs(windowSize.width - bounds.width) < 8
            && abs(windowSize.height - bounds.height) < 8
    }
}

private final class SwitcherPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        true
    }
}
