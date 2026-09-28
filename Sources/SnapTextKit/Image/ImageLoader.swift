import CoreGraphics
import Foundation
import ImageIO

/// Loads any format ImageIO decodes (PNG, JPEG, TIFF, HEIC, ...), upright.
///
/// Photos straight off a camera are usually stored sideways with an EXIF
/// orientation tag; Vision reads rotated text poorly, so the tag is applied here.
public struct ImageLoader: Sendable {
    public init() {}

    public func load(path: String) throws -> CGImage {
        let expandedPath = NSString(string: path).expandingTildeInPath

        guard FileManager.default.fileExists(atPath: expandedPath) else {
            throw SnapTextError.imageNotFound(path)
        }

        let url = URL(fileURLWithPath: expandedPath)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            throw SnapTextError.unreadableImage(path)
        }
        return try uprightImage(from: source, name: path)
    }

    /// Decodes encoded image bytes, e.g. from a photo picker or a share sheet.
    /// `name` is only used in the error if the bytes are not an image.
    public func load(data: Data, name: String = "image") throws -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw SnapTextError.unreadableImage(name)
        }
        return try uprightImage(from: source, name: name)
    }

    private func uprightImage(from source: CGImageSource, name: String) throws -> CGImage {
        guard
            CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else {
            throw SnapTextError.unreadableImage(name)
        }

        // A "thumbnail" at full size is the ImageIO way to get the orientation applied.
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: max(width, height),
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw SnapTextError.unreadableImage(name)
        }
        return image
    }
}
