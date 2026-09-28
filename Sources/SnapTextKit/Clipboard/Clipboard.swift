import CoreGraphics
import Foundation

#if canImport(AppKit)
import AppKit
#elseif canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
#endif

/// Reads images from, and writes text to, the system pasteboard.
public struct Clipboard: Sendable {
    public init() {}

    #if canImport(AppKit)
    public func readImage() throws -> CGImage {
        guard
            let image = NSImage(pasteboard: .general),
            let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        else {
            throw SnapTextError.clipboardHasNoImage
        }
        return cgImage
    }

    public func writeText(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
    #elseif canImport(UIKit)
    /// Reading the pasteboard shows iOS's "Allow Paste" prompt unless the app
    /// was granted access in Settings.
    @MainActor
    public func readImage() throws -> CGImage {
        // `UIImage.cgImage` drops the orientation, so decode the raw bytes instead.
        let pasteboard = UIPasteboard.general
        let imageType = pasteboard.types.first { UTType($0)?.conforms(to: .image) == true }
        if let data = imageType.flatMap(pasteboard.data(forPasteboardType:))
            ?? pasteboard.image?.pngData() {
            do {
                return try ImageLoader().load(data: data, name: "clipboard image")
            } catch {
                throw SnapTextError.clipboardHasNoImage
            }
        }
        throw SnapTextError.clipboardHasNoImage
    }

    @MainActor
    public func writeText(_ text: String) {
        UIPasteboard.general.string = text
    }
    #endif
}
