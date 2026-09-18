import XCTest

@testable import SnapTextKit

final class LayoutRendererTests: XCTestCase {
    /// Vision's coordinates: 0…1, origin bottom-left.
    private func line(_ text: String, x: Double, y: Double, width: Double) -> OCRLine {
        OCRLine(text: text, confidence: 1, box: TextBox(x: x, y: y, width: width, height: 0.03))
    }

    func testBlocksOnTheSameRowShareALine() {
        let rendered = LayoutRenderer.render([
            line("Name", x: 0.1, y: 0.8, width: 0.2),
            line("Value", x: 0.5, y: 0.8, width: 0.25)
        ])

        // 0.05 per character, so "Value" starts eight cells after the left margin.
        XCTAssertEqual(rendered, "Name    Value")
    }

    func testBlocksAreOrderedLeftToRightNotByRecognitionOrder() {
        let rendered = LayoutRenderer.render([
            line("Value", x: 0.5, y: 0.8, width: 0.25),
            line("Name", x: 0.1, y: 0.8, width: 0.2)
        ])

        XCTAssertEqual(rendered, "Name    Value")
    }

    func testAGapWiderThanTheUsualSpacingBecomesABlankLine() {
        let rendered = LayoutRenderer.render([
            line("Alpha", x: 0.1, y: 0.90, width: 0.25),
            line("Beta", x: 0.1, y: 0.86, width: 0.20),
            line("Gamma", x: 0.1, y: 0.82, width: 0.25),
            line("Delta", x: 0.1, y: 0.70, width: 0.25)
        ])

        XCTAssertEqual(rendered, "Alpha\nBeta\nGamma\n\nDelta")
    }

    func testLinesWithoutBoxesFallBackToOnePerLine() {
        let rendered = LayoutRenderer.render([
            OCRLine(text: "first", confidence: 1),
            OCRLine(text: "second", confidence: 1)
        ])

        XCTAssertEqual(rendered, "first\nsecond")
    }

    func testNoLinesRenderNothing() {
        XCTAssertEqual(LayoutRenderer.render([]), "")
    }
}
