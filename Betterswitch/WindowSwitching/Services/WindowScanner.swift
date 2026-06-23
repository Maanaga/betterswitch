import AppKit
import ApplicationServices
import UniformTypeIdentifiers

@MainActor
enum WindowScanner {
    static func visibleWindows() -> [WindowInfo] {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let rawWindows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return rawWindows.compactMap(makeWindowInfo)
    }

    private static func makeWindowInfo(from dictionary: [String: Any]) -> WindowInfo? {
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

        let title = dictionary[kCGWindowName as String] as? String ?? ""
        let app = NSRunningApplication(processIdentifier: processIdentifier)
        let bundleIdentifier = app?.bundleIdentifier
        let icon = app?.icon ?? NSWorkspace.shared.icon(for: .applicationBundle)
        icon.size = NSSize(width: 40, height: 40)

        return WindowInfo(
            id: UInt32(windowNumber),
            appName: ownerName,
            windowTitle: title,
            bundleIdentifier: bundleIdentifier,
            processIdentifier: processIdentifier,
            windowNumber: windowNumber,
            bounds: bounds,
            ownerIcon: icon
        )
    }
}
