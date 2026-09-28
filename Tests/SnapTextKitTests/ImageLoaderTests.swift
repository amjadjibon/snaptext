import ImageIO
import XCTest

@testable import SnapTextKit

final class ImageLoaderTests: XCTestCase {
    func testLoadsAPNGFromDisk() throws {
        let path = try TestImage.writtenPNG("Hello world")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let image = try ImageLoader().load(path: path)
        XCTAssertGreaterThan(image.width, 0)
    }

    func testMissingFileIsReportedWithExitCodeThree() {
        XCTAssertThrowsError(try ImageLoader().load(path: "/tmp/definitely-not-here.png")) { error in
            guard case SnapTextError.imageNotFound = error else {
                return XCTFail("expected imageNotFound, got \(error)")
            }
            XCTAssertEqual((error as! SnapTextError).exitCode, 3)
        }
    }

    func testNonImageFileIsReportedAsUnreadable() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptext-test-\(UUID().uuidString).png")
        try Data("not an image".utf8).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try ImageLoader().load(path: url.path)) { error in
            guard case SnapTextError.unreadableImage = error else {
                return XCTFail("expected unreadableImage, got \(error)")
            }
            XCTAssertEqual((error as! SnapTextError).exitCode, 3)
        }
    }

    func testLoadsEncodedBytes() throws {
        let path = try TestImage.writtenPNG("Hello world")
        defer { try? FileManager.default.removeItem(atPath: path) }

        let image = try ImageLoader().load(data: Data(contentsOf: URL(fileURLWithPath: path)))
        XCTAssertEqual(image.width, try TestImage.rendering("Hello world").width)
    }

    func testNonImageBytesAreReportedAsUnreadable() {
        XCTAssertThrowsError(try ImageLoader().load(data: Data("nope".utf8), name: "photo")) { error in
            guard case SnapTextError.unreadableImage(let name) = error else {
                return XCTFail("expected unreadableImage, got \(error)")
            }
            XCTAssertEqual(name, "photo")
        }
    }

    /// A camera photo stored sideways (EXIF orientation 6) must come back upright,
    /// or the recognizer sees rotated text.
    func testAppliesTheEXIFOrientation() throws {
        let upright = try TestImage.rendering("Sideways")
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(data, "public.jpeg" as CFString, 1, nil)
        )
        CGImageDestinationAddImage(
            destination,
            upright,
            [kCGImagePropertyOrientation: CGImagePropertyOrientation.right.rawValue] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))

        let image = try ImageLoader().load(data: data as Data)
        XCTAssertEqual(image.width, upright.height)
        XCTAssertEqual(image.height, upright.width)
    }

    func testTildePathsAreExpanded() {
        XCTAssertThrowsError(try ImageLoader().load(path: "~/definitely-not-here.png")) { error in
            guard case SnapTextError.imageNotFound(let path) = error else {
                return XCTFail("expected imageNotFound, got \(error)")
            }
            XCTAssertEqual(path, "~/definitely-not-here.png")
        }
    }
}
