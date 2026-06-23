import AppKit
import SwiftUI

struct WindowSwitcherView: View {
    @ObservedObject var controller: WindowSwitcherController

    var body: some View {
        Group {
            if controller.windows.isEmpty {
                emptyState
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(controller.windows) { window in
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
