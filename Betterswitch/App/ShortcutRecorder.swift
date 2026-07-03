import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: GlobalShortcut

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut)
    }

    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onChange = { context.coordinator.shortcut.wrappedValue = $0 }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ button: RecorderButton, context: Context) {
        button.shortcut = shortcut
    }

    final class Coordinator {
        let shortcut: Binding<GlobalShortcut>

        init(shortcut: Binding<GlobalShortcut>) {
            self.shortcut = shortcut
        }
    }
}

final class RecorderButton: NSButton {
    var onChange: ((GlobalShortcut) -> Void)?
    var shortcut: GlobalShortcut = .showSwitcher {
        didSet {
            if !isRecording {
                title = shortcut.displayString
            }
        }
    }

    private var isRecording = false
    private var eventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        target = self
        action = #selector(beginRecording)
        setButtonType(.momentaryPushIn)
        font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .medium)
        focusRingType = .exterior
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
        isRecording = true
        title = "Type shortcut…"
        window?.makeFirstResponder(self)
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            self.record(event)
            return nil
        }
    }

    override func keyDown(with event: NSEvent) {
        record(event)
    }

    private func record(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape {
            finishRecording()
            return
        }

        guard let newShortcut = GlobalShortcut(event: event) else {
            NSSound.beep()
            return
        }

        onChange?(newShortcut)
        finishRecording()
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned, isRecording {
            finishRecording()
        }
        return resigned
    }

    private func finishRecording() {
        isRecording = false
        title = shortcut.displayString
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
        if window?.firstResponder === self {
            window?.makeFirstResponder(nil)
        }
    }
}
