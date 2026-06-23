import AppKit

struct WindowInfo: Identifiable, Hashable {
    let id: String
    let appName: String
    let windowTitle: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let bounds: CGRect?
    let ownerIcon: NSImage

    var secondaryTitle: String? {
        if let windowTitle, !windowTitle.isEmpty {
            return windowTitle
        }
        return "Untitled Window"
    }

    var detailText: String {
        bundleIdentifier ?? ""
    }

    var orderingKey: String {
        [
            bundleIdentifier ?? appName,
            windowTitle ?? "",
            bounds.map { "\(Int($0.minX)):\(Int($0.minY)):\(Int($0.width)):\(Int($0.height))" } ?? ""
        ].joined(separator: "|")
    }

    var hasWindow: Bool {
        true
    }
}
