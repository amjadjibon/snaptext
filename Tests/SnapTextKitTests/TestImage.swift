import AppKit
import CoreGraphics
import XCTest

/// Renders text into an image so OCR tests need no binary fixtures.
enum TestImage {
    static func rendering(_ text: String, fontSize: CGFloat = 64) throws -> CGImage {
        let size = NSSize(width: 900, height: 200)
        let image = NSImage(size: size)

        image.lockFocus()
        NSColor.white.setFill()
        NSRect(origin: .zero, size: size).fill()
        (text as NSString).draw(
            at: NSPoint(x: 24, y: 60),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: fontSize),
                .foregroundColor: NSColor.black
            ]
        )
        image.unlockFocus()

        return try XCTUnwrap(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    }

    static func blank() throws -> CGImage {
        try rendering("")
    }

    /// Writes a rendered image to a temporary PNG and returns its path.
    static func writtenPNG(_ text: String) throws -> String {
        let cgImage = try rendering(text)
        let representation = NSBitmapImageRep(cgImage: cgImage)
        let data = try XCTUnwrap(representation.representation(using: .png, properties: [:]))
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptext-test-\(UUID().uuidString).png")
        try data.write(to: url)
        return url.path
    }
}
