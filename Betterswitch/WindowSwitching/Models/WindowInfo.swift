import AppKit

struct WindowInfo: Identifiable, Hashable {
    enum Kind: Hashable {
        case app
        case window
    }

    let id: String
    let kind: Kind
    let appName: String
    let windowTitle: String?
    let bundleIdentifier: String?
    let processIdentifier: pid_t
    let bounds: CGRect?
    let ownerIcon: NSImage

    var secondaryTitle: String? {
        switch kind {
        case .app:
            return nil
        case .window:
            if let windowTitle, !windowTitle.isEmpty {
                return windowTitle
            }
            return "Untitled Window"
        }
    }

    var detailText: String {
        let details: [String] = [
            bundleIdentifier,
            "PID \(processIdentifier)",
            bounds.map { "\(Int($0.width)) x \(Int($0.height))" }
        ].compactMap { $0 }

        return details.joined(separator: " | ")
    }

    var hasWindow: Bool {
        kind == .window
    }
}
