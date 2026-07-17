import AppKit
import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var controller: WindowSwitcherController
    @ObservedObject private var preferences: PreferencesModel
    @AppStorage("glassDarkness") private var glassDarkness = 0.40
    @State private var isAtScrollEnd = false

    init(controller: WindowSwitcherController) {
        _controller = ObservedObject(wrappedValue: controller)
        _preferences = ObservedObject(wrappedValue: controller.preferences)
    }

    var body: some View {
        VStack(spacing: 10) {
            if controller.windows.isEmpty {
                emptyState
            } else {
                switch preferences.switcherLayout {
                case .classicList:
                    classicSwitcher
                case .previewThumbnails:
                    previewSwitcher
                }
            }
        }
        .frame(minWidth: 520, minHeight: 360)
        .searchable(text: $controller.searchText, prompt: "Search apps and windows")
    }

    private var classicSwitcher: some View {
        VStack(spacing: 10) {
            searchField

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(controller.filteredWindows) { window in
                            WindowRow(
                                window: window,
                                isSelected: controller.selectedWindowID == window.id,
                                glassDarkness: glassDarkness
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
                .mask {
                    if isAtScrollEnd {
                        Color.black
                    } else {
                        LinearGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black, location: 0.90),
                                .init(color: .clear, location: 1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
                }
                .onScrollGeometryChange(for: Bool.self) { geometry in
                    geometry.visibleRect.maxY >= geometry.contentSize.height - 1
                } action: { _, isAtScrollEnd in
                    self.isAtScrollEnd = isAtScrollEnd
                }
                .onAppear {
                    scrollToSelection(with: proxy, animated: false)
                }
                .onChange(of: controller.selectedWindowID) {
                    scrollToSelection(with: proxy, animated: true)
                }
            }
        }
    }

    private var previewSwitcher: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            previewSearchField

            ScrollViewReader { proxy in
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 18) {
                        ForEach(controller.filteredWindows) { window in
                            PreviewWindowCard(
                                window: window,
                                thumbnail: controller.previewThumbnails[window.id],
                                isSelected: controller.selectedWindowID == window.id
                            )
                            .id(window.id)
                            .onTapGesture {
                                controller.select(window)
                            }
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.vertical, 30)
                }
                .scrollIndicators(.never)
                .frame(height: 288)
                .padding(.horizontal, 8)
                .onAppear {
                    scrollToSelection(with: proxy, animated: false)
                    controller.loadPreviewThumbnailsIfNeeded()
                }
                .onChange(of: controller.selectedWindowID) {
                    scrollToSelection(with: proxy, animated: true)
                }
                .onChange(of: preferences.switcherLayout) {
                    controller.loadPreviewThumbnailsIfNeeded()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxHeight: .infinity)
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
            Text("Open any app window and press Command + ` again.")
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
                onDismiss: controller.hide,
                navigationAxis: .vertical
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
        .liquidGlassFrame(cornerRadius: 30, isSelected: false, darkness: glassDarkness)
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    private var previewSearchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            KeyboardRoutingSearchField(
                text: $controller.searchText,
                placeholder: "Search apps and windows",
                onMoveSelection: controller.moveSelection,
                onActivateSelection: controller.activateSelectedWindow,
                onDismiss: controller.hide,
                navigationAxis: .horizontal
            )
            .frame(height: 24)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(width: 360)
        .liquidGlassFrame(cornerRadius: 22, isSelected: false, darkness: glassDarkness)
        .padding(.top, 8)
    }
}

private struct WindowRow: View {
    let window: WindowInfo
    let isSelected: Bool
    let glassDarkness: Double

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
        .liquidGlassFrame(cornerRadius: 20, isSelected: isSelected, darkness: glassDarkness)
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct PreviewWindowCard: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool

    var body: some View {
        preview
            .frame(width: 314, height: 204)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                if isSelected {
                    focusedTitle
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isSelected ? Color.black.opacity(0.78) : Color.white.opacity(0.62), lineWidth: isSelected ? 3 : 1)
            }
            .shadow(color: .black.opacity(isSelected ? 0.34 : 0.18), radius: isSelected ? 18 : 10, y: 8)
            .scaleEffect(isSelected ? 1.05 : 1)
            .animation(.snappy(duration: 0.16), value: isSelected)
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 314, height: 204)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.thinMaterial)

                Image(nsImage: window.ownerIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 42, height: 42)
                    .opacity(0.72)
            }
            .frame(width: 314, height: 204)
        }
    }

    private var focusedTitle: some View {
        HStack(spacing: 8) {
            Image(nsImage: window.ownerIcon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)

            Text(focusedTitleText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: 218, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
        }
        .padding(9)
        .shadow(color: .black.opacity(0.28), radius: 8, y: 3)
    }

    private var focusedTitleText: String {
        guard let title = window.windowTitle, !title.isEmpty else {
            return window.appName
        }

        return "\(window.appName) — \(title)"
    }
}

private struct KeyboardRoutingSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onMoveSelection: (Int) -> Void
    let onActivateSelection: () -> Void
    let onDismiss: () -> Void
    let navigationAxis: KeyboardNavigationAxis

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
        textField.navigationAxis = navigationAxis
        return textField
    }

    func updateNSView(_ nsView: RoutingTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }

        nsView.onMoveSelection = onMoveSelection
        nsView.onActivateSelection = onActivateSelection
        nsView.onDismiss = onDismiss
        nsView.navigationAxis = navigationAxis
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
        var navigationAxis: KeyboardNavigationAxis = .vertical
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
            case 123:
                if navigationAxis == .horizontal {
                    onMoveSelection?(-1)
                } else {
                    super.keyDown(with: event)
                }
            case 124:
                if navigationAxis == .horizontal {
                    onMoveSelection?(1)
                } else {
                    super.keyDown(with: event)
                }
            case 125:
                if navigationAxis == .vertical {
                    onMoveSelection?(1)
                } else {
                    super.keyDown(with: event)
                }
            case 126:
                if navigationAxis == .vertical {
                    onMoveSelection?(-1)
                } else {
                    super.keyDown(with: event)
                }
            default:
                super.keyDown(with: event)
            }
        }
    }
}

private enum KeyboardNavigationAxis {
    case vertical
    case horizontal
}

private extension View {
    func liquidGlassFrame(cornerRadius: CGFloat, isSelected: Bool, darkness: Double = 0) -> some View {
        modifier(LiquidGlassFrame(cornerRadius: cornerRadius, isSelected: isSelected, darkness: darkness))
    }
}

private struct LiquidGlassFrame: ViewModifier {
    let cornerRadius: CGFloat
    let isSelected: Bool
    let darkness: Double

    private var isDarkened: Bool { darkness > 0.001 }
    private var tintOpacity: Double { darkness * 0.75 }

    func body(content: Content) -> some View {
        if #available(macOS 26.0, *) {
            content
                .background {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(isDarkened ? Color.black.opacity(darkness) : Color.clear)
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.34) : Color.clear)
                        }
                }
                .glassEffect(
                    (isDarkened ? Glass.clear : Glass.regular)
                        .tint(
                            isSelected
                                ? Color.accentColor.opacity(0.38)
                                : (isDarkened ? Color.black.opacity(tintOpacity) : Color.white.opacity(0.08))
                        )
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
                                .fill(isDarkened ? Color.black.opacity(darkness) : Color.white.opacity(0.08))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .fill(isSelected ? Color.accentColor.opacity(0.52) : Color.clear)
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor.opacity(0.9) : Color.white.opacity(0.12), lineWidth: 1)
                        }
                }
        }
    }
}
