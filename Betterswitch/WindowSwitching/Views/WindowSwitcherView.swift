import AppKit
import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var controller: WindowSwitcherController

    var body: some View {
        VStack(spacing: 10) {
            if controller.windows.isEmpty {
                emptyState
            } else {
                searchField

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(controller.filteredWindows) { window in
                                WindowRow(
                                    window: window,
                                    isSelected: controller.selectedWindowID == window.id
                                )
                                .id(window.id)
                                .onTapGesture {
                                    controller.select(window)
                                }
                            }
                        }
                        .padding(8)
                    }
                    .scrollIndicators(.never)
                    .onAppear {
                        scrollToSelection(with: proxy, animated: false)
                    }
                    .onChange(of: controller.selectedWindowID) {
                        scrollToSelection(with: proxy, animated: true)
                    }
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .searchable(text: $controller.searchText, prompt: "Search apps and windows")
    }

    private func scrollToSelection(with proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedWindowID = controller.selectedWindowID else {
            return
        }

        let scroll = {
            proxy.scrollTo(selectedWindowID, anchor: .center)
        }

        if animated {
            withAnimation(.snappy(duration: 0.16)) {
                scroll()
            }
        } else {
            scroll()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "macwindow.badge.plus")
                .font(.system(size: 38, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No visible app windows")
                .font(.system(size: 18, weight: .semibold))
            Text("Open Chrome, Xcode, or another app window and press Command + ` again.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(28)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.secondary)

            KeyboardRoutingSearchField(
                text: $controller.searchText,
                placeholder: "Search apps and windows",
                onMoveSelection: controller.moveSelection,
                onActivateSelection: controller.activateSelectedWindow,
                onDismiss: controller.hide
            )
            .frame(height: 30)

            if !controller.searchText.isEmpty {
                Button {
                    controller.searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .liquidGlassFrame(cornerRadius: 30, isSelected: false)
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

private struct WindowRow: View {
    let window: WindowInfo
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: window.ownerIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 42, height: 42)
                .padding(8)
                .liquidGlassFrame(cornerRadius: 16, isSelected: false)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(window.appName)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if let secondaryTitle = window.secondaryTitle {
                        Text(secondaryTitle)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Text(window.detailText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 74)
        .liquidGlassFrame(cornerRadius: 20, isSelected: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct KeyboardRoutingSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onMoveSelection: (Int) -> Void
    let onActivateSelection: () -> Void
    let onDismiss: () -> Void

    func makeNSView(context: Context) -> RoutingTextField {
        let textField = RoutingTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = .systemFont(ofSize: 15, weight: .medium)
        textField.textColor = .labelColor
        textField.placeholderString = placeholder
        textField.onMoveSelection = onMoveSelection
        textField.onActivateSelection = onActivateSelection
        textField.onDismiss = onDismiss
        return textField
    }

    func updateNSView(_ nsView: RoutingTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        nsView.onMoveSelection = onMoveSelection
        nsView.onActivateSelection = onActivateSelection
        nsView.onDismiss = onDismiss
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let textField = notification.object as? NSTextField else {
                return
            }
            text = textField.stringValue
        }
    }

    final class RoutingTextField: NSTextField {
        var onMoveSelection: ((Int) -> Void)?
        var onActivateSelection: (() -> Void)?
        var onDismiss: (() -> Void)?
        private var didRequestInitialFocus = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()

            guard !didRequestInitialFocus else {
                return
            }

            didRequestInitialFocus = true
            DispatchQueue.main.async { [weak self] in
                guard let self else {
                    return
                }
                self.window?.makeFirstResponder(self)
            }
        }

        override func keyDown(with event: NSEvent) {
            switch event.keyCode {
            case 53:
                onDismiss?()
            case 36:
                onActivateSelection?()
            case 125:
                onMoveSelection?(1)
            case 126:
                onMoveSelection?(-1)
            default:
                super.keyDown(with: event)
            }
        }
    }
}

private extension View {
    func liquidGlassFrame(cornerRadius: CGFloat, isSelected: Bool) -> some View {
        modifier(LiquidGlassFrame(cornerRadius: cornerRadius, isSelected: isSelected))
    }
}

private struct LiquidGlassFrame: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isSelected ? Color.accentColor.opacity(0.40) : Color.clear)
                }
                .glassEffect(
                    .regular
                        .tint(isSelected ? Color.accentColor.opacity(0.42) : Color.white.opacity(0.08))
                        .interactive(isSelected),
                    in: .rect(cornerRadius: cornerRadius)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.14), lineWidth: 1)
                }
        } else {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.62) : Color.white.opacity(0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
    }
}
