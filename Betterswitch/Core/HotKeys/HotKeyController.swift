import Carbon
import Foundation

final class HotKeyController {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private let switcherAction: () -> Void
    private let optionsAction: () -> Void

    init(
        switcherShortcut: GlobalShortcut,
        alternateSwitcherShortcut: GlobalShortcut,
        optionsShortcut: GlobalShortcut,
        switcherAction: @escaping () -> Void,
        optionsAction: @escaping () -> Void
    ) {
        self.switcherAction = switcherAction
        self.optionsAction = optionsAction
        installEventHandler()
        update(
            switcherShortcut: switcherShortcut,
            alternateSwitcherShortcut: alternateSwitcherShortcut,
            optionsShortcut: optionsShortcut
        )
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func update(
        switcherShortcut: GlobalShortcut,
        alternateSwitcherShortcut: GlobalShortcut,
        optionsShortcut: GlobalShortcut
    ) -> String? {
        unregisterHotKeys()

        var failures: [String] = []
        if !registerHotKey(id: 1, shortcut: switcherShortcut) {
            failures.append(switcherShortcut.displayString)
        }
        if !registerHotKey(id: 2, shortcut: alternateSwitcherShortcut) {
            failures.append(alternateSwitcherShortcut.displayString)
        }
        if !registerHotKey(id: 3, shortcut: optionsShortcut) {
            failures.append(optionsShortcut.displayString)
        }

        guard !failures.isEmpty else { return nil }
        return "Couldn’t register \(failures.joined(separator: ", ")). Another app or macOS may already use it."
    }

    private func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        let pointer = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else {
                    return noErr
                }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr, hotKeyID.signature == OSType("BTSW".fourCharCode) else {
                    return noErr
                }

                let controller = Unmanaged<HotKeyController>.fromOpaque(userData).takeUnretainedValue()
                switch hotKeyID.id {
                case 1, 2:
                    controller.switcherAction()
                case 3:
                    controller.optionsAction()
                default:
                    break
                }
                return noErr
            },
            1,
            &eventType,
            pointer,
            &eventHandlerRef
        )

    }

    private func unregisterHotKeys() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }

    private func registerHotKey(id: UInt32, shortcut: GlobalShortcut) -> Bool {
        let hotKeyID = EventHotKeyID(signature: OSType("BTSW".fourCharCode), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
            return true
        }
        return false
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf16.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
