import SnapTextKit
import UIKit
import XCTest

@testable import SnapTextApp

final class RecognizerTests: XCTestCase {
    /// End to end on iOS: encoded bytes → ImageLoader → Vision → formatter.
    func testRecognizesAPNGAndRebuildsTheLayout() async throws {
        let png = Self.renderPNG(rows: [
            ("ACME Supply Co.", "Invoice #A-2291"),
            ("Freight", "$28.50"),
            ("Amount due", "$368.50")
        ])
        let settings = RecognitionSettings(level: .accurate, usesLanguageCorrection: true, languages: [])

        let pages = try await Recognizer.recognize(
            { [try ImageLoader().load(data: png)] },
            settings: settings
        )

        let text = try Recognizer.render(pages, as: .text)
        XCTAssertTrue(text.contains("Amount due"), text)

        // Both columns land on the same row in layout mode.
        let layout = try Recognizer.render(pages, as: .layout)
        let totalRow = try XCTUnwrap(layout.split(separator: "\n").first { $0.contains("Amount due") })
        XCTAssertTrue(totalRow.contains("368.50"), layout)
    }

    func testBlankImageReportsNoTextDetected() async throws {
        let png = Self.renderPNG(rows: [])
        let settings = RecognitionSettings(level: .fast, usesLanguageCorrection: true, languages: [])

        do {
            _ = try await Recognizer.recognize({ [try ImageLoader().load(data: png)] }, settings: settings)
            XCTFail("expected noTextDetected")
        } catch {
            XCTAssertEqual(Recognizer.message(for: error), "No text detected")
        }
    }

    func testSeveralPagesOfJSONFormOneArray() throws {
        let image = try ImageLoader().load(data: Self.renderPNG(rows: []))
        let page = Page(image: image, result: OCRResult(lines: [OCRLine(text: "Hi", confidence: 1)]))

        let json = try Recognizer.render([page, page], as: .json)
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8))
        XCTAssertEqual((decoded as? [Any])?.count, 2)

        XCTAssertEqual(try Recognizer.render([page, page], as: .text), "Hi\n\nHi")
    }

    func testLanguagesRoundTripInPriorityOrder() {
        let languages = ["bn-BD", "en-US"]
        let stored = RecognitionSettings.encodeLanguages(languages)
        XCTAssertEqual(RecognitionSettings.decodeLanguages(stored), languages)
        XCTAssertEqual(RecognitionSettings.decodeLanguages(""), [])
    }

    /// A two-column page, rendered so the tests need no binary fixtures.
    private static func renderPNG(rows: [(String, String)]) -> Data {
        let size = CGSize(width: 1000, height: 120 + 90 * rows.count)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).pngData { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.monospacedSystemFont(ofSize: 34, weight: .regular),
                .foregroundColor: UIColor.black
            ]
            for (index, row) in rows.enumerated() {
                let y = CGFloat(60 + index * 90)
                (row.0 as NSString).draw(at: CGPoint(x: 40, y: y), withAttributes: attributes)
                (row.1 as NSString).draw(at: CGPoint(x: 620, y: y), withAttributes: attributes)
            }
        }
    }
}
