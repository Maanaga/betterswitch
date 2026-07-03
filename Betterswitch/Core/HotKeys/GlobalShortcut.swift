import AppKit
import Carbon

struct GlobalShortcut: Codable, Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let key: String

    static let showSwitcher = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(cmdKey),
        key: "`"
    )
    static let showSwitcherAlternate = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_Grave),
        modifiers: UInt32(cmdKey | shiftKey),
        key: "`"
    )
    static let showOptions = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_B),
        modifiers: UInt32(cmdKey | optionKey),
        key: "B"
    )

    init(keyCode: UInt32, modifiers: UInt32, key: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.key = key
    }

    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbonModifiers: UInt32 = 0
        if flags.contains(.control) { carbonModifiers |= UInt32(controlKey) }
        if flags.contains(.option) { carbonModifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { carbonModifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { carbonModifiers |= UInt32(cmdKey) }

        guard carbonModifiers != 0, let key = Self.keyName(for: event) else { return nil }
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbonModifiers, key: key)
    }

    var displayString: String {
        var components: [String] = []
        if modifiers & UInt32(controlKey) != 0 { components.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { components.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { components.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { components.append("⌘") }
        components.append(key)
        return components.joined(separator: " ")
    }

    private static func keyName(for event: NSEvent) -> String? {
        switch Int(event.keyCode) {
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_Space: return "Space"
        case kVK_Delete: return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Home: return "↖"
        case kVK_End: return "↘"
        case kVK_PageUp: return "⇞"
        case kVK_PageDown: return "⇟"
        case kVK_LeftArrow: return "←"
        case kVK_RightArrow: return "→"
        case kVK_UpArrow: return "↑"
        case kVK_DownArrow: return "↓"
        case kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
             kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20:
            return functionKeyName(for: Int(event.keyCode))
        default:
            guard let characters = event.charactersIgnoringModifiers, !characters.isEmpty else { return nil }
            return characters.uppercased()
        }
    }

    private static func functionKeyName(for keyCode: Int) -> String? {
        let functionKeys = [
            kVK_F1, kVK_F2, kVK_F3, kVK_F4, kVK_F5, kVK_F6, kVK_F7, kVK_F8, kVK_F9, kVK_F10,
            kVK_F11, kVK_F12, kVK_F13, kVK_F14, kVK_F15, kVK_F16, kVK_F17, kVK_F18, kVK_F19, kVK_F20
        ]
        guard let index = functionKeys.firstIndex(of: keyCode) else { return nil }
        return "F\(index + 1)"
    }
}
