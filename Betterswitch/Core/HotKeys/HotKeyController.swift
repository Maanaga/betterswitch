import Carbon
import Foundation

final class HotKeyController {
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandlerRef: EventHandlerRef?
    private let switcherAction: () -> Void
    private let optionsAction: () -> Void

    init(switcherAction: @escaping () -> Void, optionsAction: @escaping () -> Void) {
        self.switcherAction = switcherAction
        self.optionsAction = optionsAction
        register()
    }

    deinit {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func register() {
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

        registerHotKey(id: 1, keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(cmdKey))
        registerHotKey(id: 2, keyCode: UInt32(kVK_ANSI_Grave), modifiers: UInt32(cmdKey | shiftKey))
        registerHotKey(id: 3, keyCode: UInt32(kVK_ANSI_B), modifiers: UInt32(cmdKey | optionKey))
    }

    private func registerHotKey(id: UInt32, keyCode: UInt32, modifiers: UInt32) {
        let hotKeyID = EventHotKeyID(signature: OSType("BTSW".fourCharCode), id: id)
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr, let hotKeyRef {
            hotKeyRefs.append(hotKeyRef)
        }
    }
}

private extension String {
    var fourCharCode: FourCharCode {
        utf16.reduce(0) { ($0 << 8) + FourCharCode($1) }
    }
}
