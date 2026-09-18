import Foundation

/// One recognized line of text and how confident Vision is about it.
public struct OCRLine: Codable, Equatable, Sendable {
    public let text: String
    public let confidence: Double

    public init(text: String, confidence: Double) {
        self.text = text
        // Vision reports a Float; round so JSON stays readable instead of 0.98000001907.
        self.confidence = (confidence * 10_000).rounded() / 10_000
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
