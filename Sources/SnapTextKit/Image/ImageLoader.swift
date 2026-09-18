import AppKit
import CoreGraphics
import Foundation

/// Loads any image format `NSImage` understands (PNG, JPEG, TIFF, HEIC, ...).
public struct ImageLoader: Sendable {
    public init() {}

    public func load(path: String) throws -> CGImage {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw SnapTextError.imageNotFound(path)
        }

        guard let image = NSImage(contentsOfFile: expandedPath) else {
            throw SnapTextError.unreadableImage(path)
        }

        return try cgImage(from: image, path: path)
    }

    func cgImage(from image: NSImage, path: String) throws -> CGImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw SnapTextError.unreadableImage(path)
        }
        return cgImage
    }
}
