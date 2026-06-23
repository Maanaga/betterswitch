import AppKit

struct WindowInfo: Identifiable, Hashable {
    let id: UInt32
    let appName: String
    let windowTitle: String
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let windowNumber: Int
    let bounds: CGRect
    let ownerIcon: NSImage

    var displayTitle: String {
        windowTitle.isEmpty ? "Untitled Window" : windowTitle
    }

    var detailText: String {
        let size = "\(Int(bounds.width)) x \(Int(bounds.height))"
        if let bundleIdentifier, !bundleIdentifier.isEmpty {
            return "\(bundleIdentifier) | PID \(processIdentifier) | \(size)"
        }
        return "PID \(processIdentifier) | \(size)"
    }
}
