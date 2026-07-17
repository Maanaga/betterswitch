import AppKit
import CoreGraphics
import ScreenCaptureKit

@MainActor
final class WindowPreviewProvider {
    private let targetPixelSize = CGSize(width: 900, height: 560)

    func thumbnail(for window: WindowInfo) async -> NSImage? {
        guard let windowNumber = window.windowNumber else {
            return nil
        }

        guard
            let scWindow = await shareableWindow(matching: windowNumber),
            let cgImage = await captureImage(for: scWindow)
        else {
            return nil
        }

        return resizedImage(from: cgImage)
    }

    private func shareableWindow(matching windowNumber: Int) async -> SCWindow? {
        do {
            let content = try await SCShareableContent.current
            return content.windows.first { $0.windowID == CGWindowID(windowNumber) }
        } catch {
            return nil
        }
    }

    private func captureImage(for window: SCWindow) async -> CGImage? {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(targetPixelSize.width)
        configuration.height = Int(targetPixelSize.height)
        configuration.scalesToFit = true
        configuration.preservesAspectRatio = true
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        configuration.shouldBeOpaque = true
        configuration.backgroundColor = NSColor.windowBackgroundColor.cgColor

        do {
            return try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        } catch {
            return nil
        }
    }

    private func resizedImage(from cgImage: CGImage) -> NSImage {
        let sourceSize = CGSize(width: cgImage.width, height: cgImage.height)
        let scale = min(targetPixelSize.width / sourceSize.width, targetPixelSize.height / sourceSize.height)
        let drawSize = CGSize(width: sourceSize.width * scale, height: sourceSize.height * scale)
        let canvasRect = CGRect(origin: .zero, size: targetPixelSize)
        let drawRect = CGRect(
            x: (targetPixelSize.width - drawSize.width) / 2,
            y: (targetPixelSize.height - drawSize.height) / 2,
            width: drawSize.width,
            height: drawSize.height
        )

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard
            let context = CGContext(
                data: nil,
                width: Int(targetPixelSize.width),
                height: Int(targetPixelSize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else {
            return NSImage(cgImage: cgImage, size: sourceSize)
        }

        context.setFillColor(NSColor.windowBackgroundColor.cgColor)
        context.fill(canvasRect)
        context.interpolationQuality = .high
        context.draw(cgImage, in: drawRect)

        guard let thumbnail = context.makeImage() else {
            return NSImage(cgImage: cgImage, size: sourceSize)
        }

        return NSImage(cgImage: thumbnail, size: targetPixelSize)
    }
}
