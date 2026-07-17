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
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(.ultraThinMaterial)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.black.opacity(glassDarkness * 0.72))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                }

            previewHiddenSearchField
                .frame(width: 1, height: 1)
                .opacity(0.01)

            if controller.filteredWindows.isEmpty {
                Text("No matching windows")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                PreviewWindowGrid(
                    windows: controller.filteredWindows,
                    thumbnail: controller.previewThumbnail,
                    selectedWindowID: controller.selectedWindowID,
                    onSelect: controller.select
                )
                .padding(26)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            if !controller.searchText.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 12, weight: .semibold))
                    Text(controller.searchText)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.regularMaterial, in: Capsule())
                .overlay {
                    Capsule()
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                }
                .padding(.top, 14)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            controller.loadPreviewThumbnailsIfNeeded()
        }
        .onChange(of: preferences.switcherLayout) {
            controller.loadPreviewThumbnailsIfNeeded()
        }
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
                onMoveRowSelection: { _ in },
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

    private var previewHiddenSearchField: some View {
        KeyboardRoutingSearchField(
            text: $controller.searchText,
            placeholder: "",
            onMoveSelection: controller.moveSelection,
            onMoveRowSelection: controller.movePreviewSelectionByRow,
            onActivateSelection: controller.activateSelectedWindow,
            onDismiss: controller.hide,
            navigationAxis: .horizontal
        )
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

private struct PreviewWindowGrid: View {
    let windows: [WindowInfo]
    let thumbnail: (WindowInfo) -> NSImage?
    let selectedWindowID: String?
    let onSelect: (WindowInfo) -> Void

    private let maxColumns = 6
    private let preferredColumns = 4
    private let horizontalSpacing: CGFloat = 30
    private let verticalSpacing: CGFloat = 34
    private let minimumCardWidth: CGFloat = 220
    private let thumbnailAspectRatio: CGFloat = 1.62

    var body: some View {
        GeometryReader { geometry in
            let widthBasedColumns = max(1, Int((geometry.size.width + horizontalSpacing) / (minimumCardWidth + horizontalSpacing)))
            let countBasedColumns = windows.count > preferredColumns * 3
                ? min(maxColumns, Int(ceil(Double(windows.count) / 3.0)))
                : preferredColumns
            let columnCount = min(max(windows.count, 1), maxColumns, min(countBasedColumns, widthBasedColumns))
            let rowCount = Int(ceil(Double(windows.count) / Double(columnCount)))
            let availableWidth = max(geometry.size.width, 1)
            let availableHeight = max(geometry.size.height, 1)
            let cardWidth = (availableWidth - CGFloat(columnCount - 1) * horizontalSpacing) / CGFloat(columnCount)
            let cardHeight = (availableHeight - CGFloat(max(rowCount - 1, 0)) * verticalSpacing) / CGFloat(max(rowCount, 1))
            let maxThumbnailHeight = max(56, cardHeight - 42)
            let thumbnailWidth = min(cardWidth, maxThumbnailHeight * thumbnailAspectRatio)
            let thumbnailHeight = thumbnailWidth / thumbnailAspectRatio

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: horizontalSpacing), count: columnCount),
                alignment: .center,
                spacing: verticalSpacing
            ) {
                ForEach(windows) { window in
                    PreviewWindowCard(
                        window: window,
                        thumbnail: thumbnail(window),
                        isSelected: selectedWindowID == window.id,
                        thumbnailWidth: thumbnailWidth,
                        thumbnailHeight: thumbnailHeight
                    )
                    .frame(width: cardWidth, height: cardHeight)
                    .onTapGesture {
                        onSelect(window)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

private struct PreviewWindowCard: View {
    let window: WindowInfo
    let thumbnail: NSImage?
    let isSelected: Bool
    let thumbnailWidth: CGFloat
    let thumbnailHeight: CGFloat

    var body: some View {
        VStack(spacing: 8) {
            preview
                .frame(width: thumbnailWidth, height: thumbnailHeight)
                .background(Color.black.opacity(0.16), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .strokeBorder(
                            isSelected ? Color.white.opacity(0.95) : Color.white.opacity(0.22),
                            lineWidth: isSelected ? 2 : 1
                        )
                }
                .shadow(color: .black.opacity(isSelected ? 0.26 : 0.12), radius: isSelected ? 12 : 7, y: 5)

            HStack(spacing: 7) {
                Image(nsImage: window.ownerIcon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 17, height: 17)

                Text(focusedTitleText)
                    .font(.system(size: isSelected ? 13 : 12, weight: isSelected ? .semibold : .medium))
                    .foregroundStyle(Color.white.opacity(isSelected ? 0.98 : 0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(isSelected ? Color.white.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .animation(.snappy(duration: 0.16), value: isSelected)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var preview: some View {
        if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fill)
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
        }
    }

    private var focusedTitleText: String {
        guard let title = window.windowTitle, !title.isEmpty, title != window.appName else {
            return window.appName
        }

        return title
    }
}

private struct KeyboardRoutingSearchField: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let onMoveSelection: (Int) -> Void
    let onMoveRowSelection: (Int) -> Void
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
        textField.onMoveRowSelection = onMoveRowSelection
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
        nsView.onMoveRowSelection = onMoveRowSelection
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
        var onMoveRowSelection: ((Int) -> Void)?
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
                    onMoveRowSelection?(1)
                }
            case 126:
                if navigationAxis == .vertical {
                    onMoveSelection?(-1)
                } else {
                    onMoveRowSelection?(-1)
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
