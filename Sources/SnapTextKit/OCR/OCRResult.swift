import Foundation

/// Where a line sits in the image, in Vision's normalized coordinates: 0…1 with
/// the origin at the bottom-left.
public struct TextBox: Codable, Equatable, Sendable {
    public static let zero = TextBox(x: 0, y: 0, width: 0, height: 0)

    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    var midY: Double { y + height / 2 }
}

/// One recognized line of text, how confident Vision is about it, and where it
/// was printed.
public struct OCRLine: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Double
    public let box: TextBox

    public init(text: String, confidence: Double, box: TextBox = .zero) {
        self.text = text
        // Vision reports a Float; round so JSON stays readable instead of 0.98000001907.
        self.confidence = (confidence * 10_000).rounded() / 10_000
        self.box = box
    }
}

public struct OCRResult: Codable, Equatable, Sendable {
    public let lines: [OCRLine]

    public init(lines: [OCRLine]) {
        self.lines = lines
    }

    public var text: String {
        lines.map(\.text).joined(separator: "\n")
    }

    public var isEmpty: Bool {
        lines.isEmpty
    }
}
