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

    func testTildePathsAreExpanded() {
        XCTAssertThrowsError(try ImageLoader().load(path: "~/definitely-not-here.png")) { error in
            guard case SnapTextError.imageNotFound(let path) = error else {
                return XCTFail("expected imageNotFound, got \(error)")
            }
            XCTAssertEqual(path, "~/definitely-not-here.png")
        }
    }
}
