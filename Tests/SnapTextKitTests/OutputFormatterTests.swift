import XCTest

@testable import SnapTextKit

final class OutputFormatterTests: XCTestCase {
    private let result = OCRResult(lines: [
        OCRLine(text: "Invoice #1024", confidence: 0.98),
        OCRLine(text: "Total RM42.50", confidence: 0.5),
        OCRLine(text: "Paid", confidence: 1)
    ])

    func testPlainTextJoinsLinesWithNewlines() throws {
        XCTAssertEqual(
            try OutputFormatter(format: .plainText).render(result),
            "Invoice #1024\nTotal RM42.50\nPaid"
        )
    }

    func testPlainTextOfEmptyResultIsEmpty() throws {
        XCTAssertEqual(try OutputFormatter(format: .plainText).render(OCRResult(lines: [])), "")
    }

    func testJSONCarriesTextLinesAndConfidence() throws {
        let json = try OutputFormatter(format: .json).render(result)
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]

        XCTAssertEqual(decoded?["text"] as? String, "Invoice #1024\nTotal RM42.50\nPaid")

        let lines = try XCTUnwrap(decoded?["lines"] as? [[String: Any]])
        XCTAssertEqual(lines.count, 3)
        XCTAssertEqual(lines.first?["text"] as? String, "Invoice #1024")
        XCTAssertEqual(lines.first?["confidence"] as? Double, 0.98)
    }

    func testJSONOfEmptyResultHasEmptyLines() throws {
        let json = try OutputFormatter(format: .json).render(OCRResult(lines: []))
        let decoded = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any]

        XCTAssertEqual(decoded?["text"] as? String, "")
        XCTAssertEqual((decoded?["lines"] as? [[String: Any]])?.count, 0)
    }

    func testConfidenceIsRoundedForReadableJSON() {
        XCTAssertEqual(OCRLine(text: "x", confidence: Double(Float(0.98))).confidence, 0.98)
    }
}
