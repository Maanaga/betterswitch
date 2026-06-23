import AppKit
import ApplicationServices
import UniformTypeIdentifiers

@MainActor
enum WindowScanner {
    static func runningItems() -> [WindowInfo] {
        let visibleWindowsByPID = visibleWindows().groupedByProcessIdentifier()

        return NSWorkspace.shared.runningApplications
            .filter(isSwitchableApp)
            .sorted { lhs, rhs in
                appName(lhs).localizedCaseInsensitiveCompare(appName(rhs)) == .orderedAscending
            }
            .flatMap { app -> [WindowInfo] in
                let windows = accessibilityWindows(for: app)

                if windows.isEmpty {
                    return visibleWindowsByPID[app.processIdentifier] ?? []
                }

                return windows
            }
    }

    private static func visibleWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawWindows.compactMap(makeVisibleWindowInfo)
    }

    private static func accessibilityWindows(for app: NSRunningApplication) -> [WindowInfo] {
        guard AXIsProcessTrusted() else {
            return []
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let axWindows = value as? [AXUIElement] else {
            return []
        }

        return axWindows.enumerated().compactMap { index, axWindow in
            makeAccessibilityWindowInfo(from: axWindow, index: index, app: app)
        }
    }

    private static func makeVisibleWindowInfo(from dictionary: [String: Any]) -> WindowInfo? {
        guard
            let ownerName = dictionary[kCGWindowOwnerName as String] as? String,
            let processIdentifier = dictionary[kCGWindowOwnerPID as String] as? pid_t,
            let windowNumber = dictionary[kCGWindowNumber as String] as? Int,
            let layer = dictionary[kCGWindowLayer as String] as? Int,
            layer == 0
        else {
            return nil
        }

        let boundsDictionary = dictionary[kCGWindowBounds as String] as? [String: Any]
        let bounds = CGRect(dictionaryRepresentation: boundsDictionary as CFDictionary? ?? [:] as CFDictionary) ?? .zero
        guard bounds.width > 80, bounds.height > 60 else {
            return nil
        }

        let title = dictionary[kCGWindowName as String] as? String
        let app = NSRunningApplication(processIdentifier: processIdentifier)

        return WindowInfo(
            id: "cg-window-\(windowNumber)",
            appName: app.map(appName) ?? ownerName,
            windowTitle: title,
            bundleIdentifier: app?.bundleIdentifier,
            processIdentifier: processIdentifier,
            bounds: bounds,
            ownerIcon: appIcon(for: app)
        )
    }

    private static func makeAccessibilityWindowInfo(
        from axWindow: AXUIElement,
        index: Int,
        app: NSRunningApplication
    ) -> WindowInfo? {
        let title = stringAttribute(kAXTitleAttribute, from: axWindow)
        let bounds = bounds(for: axWindow)

        if title?.isEmpty != false, bounds == nil {
            return nil
        }

        return WindowInfo(
            id: "ax-window-\(app.processIdentifier)-\(index)-\(title ?? "")",
            appName: appName(app),
            windowTitle: title,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            bounds: bounds,
            ownerIcon: appIcon(for: app)
        )
    }

    private static func isSwitchableApp(_ app: NSRunningApplication) -> Bool {
        app.activationPolicy == .regular
            && app.processIdentifier != NSRunningApplication.current.processIdentifier
    }

    private static func appName(_ app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
    }

    private static func appIcon(for app: NSRunningApplication?) -> NSImage {
        let icon = app?.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icon.size = NSSize(width: 40, height: 40)
        return icon
    }

    private static func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else {
            return nil
        }
        return value as? String
    }

    private static func bounds(for element: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard
            let positionValue,
            let sizeValue,
            CFGetTypeID(positionValue) == AXValueGetTypeID(),
            CFGetTypeID(sizeValue) == AXValueGetTypeID()
        else {
            return nil
        }

        var origin = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &origin)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)

        guard size.width > 0, size.height > 0 else {
            return nil
        }

        return CGRect(origin: origin, size: size)
    }
}

private extension Array where Element == WindowInfo {
    func groupedByProcessIdentifier() -> [pid_t: [WindowInfo]] {
        Dictionary(grouping: self, by: \.processIdentifier)
    }
}
