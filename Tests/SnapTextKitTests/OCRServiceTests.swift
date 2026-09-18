import XCTest

@testable import SnapTextKit

final class OCRServiceTests: XCTestCase {
    func testRecognizesRenderedText() throws {
        let image = try TestImage.rendering("Hello world")
        let result = try OCRService().recognize(image: image)

        XCTAssertTrue(
            result.lines.contains { $0.text.contains("Hello") },
            "expected 'Hello' in \(result.lines.map(\.text))"
        )
        XCTAssertTrue(result.lines.allSatisfy { $0.confidence > 0 })
        XCTAssertTrue(
            result.lines.allSatisfy { $0.box.width > 0 && $0.box.height > 0 },
            "every line should carry the box Vision found it in"
        )
    }

    func testFastLevelAlsoRecognizesText() throws {
        let image = try TestImage.rendering("Total RM42.50")
        let result = try OCRService().recognize(image: image, level: .fast)

        XCTAssertTrue(
            result.text.contains("42"),
            "expected '42' in \(result.text)"
        )
    }

    func testLanguageHintIsAccepted() throws {
        let image = try TestImage.rendering("Hello world")
        let result = try OCRService().recognize(image: image, languages: ["en-US"])

        XCTAssertFalse(result.isEmpty)
    }

    func testUnsupportedLanguageIsAUsageError() throws {
        let image = try TestImage.rendering("Hello world")

        XCTAssertThrowsError(try OCRService().recognize(image: image, languages: ["xx-XX"])) { error in
            guard case SnapTextError.unsupportedLanguage(let code, _) = error else {
                return XCTFail("expected an unsupportedLanguage error, got \(error)")
            }
            XCTAssertEqual(code, "xx-XX")
            XCTAssertEqual((error as! SnapTextError).exitCode, 2)
        }
    }

    func testBlankImageYieldsNoLines() throws {
        let result = try OCRService().recognize(image: try TestImage.blank())

        XCTAssertTrue(result.isEmpty)
        XCTAssertEqual(result.text, "")
    }
}
