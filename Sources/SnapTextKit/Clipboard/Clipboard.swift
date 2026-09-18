import AppKit
import CoreGraphics
import Foundation

/// Reads images from, and writes text to, the macOS pasteboard.
public struct Clipboard: Sendable {
    public init() {}

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
}
