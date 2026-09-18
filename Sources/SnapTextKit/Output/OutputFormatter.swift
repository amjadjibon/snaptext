import Foundation

/// Renders an OCR result for stdout, either as plain text or as JSON.
public struct OutputFormatter: Sendable {
    public enum Format: Equatable, Sendable {
        case plainText
        case json
    }

    private struct JSONPayload: Encodable {
        let text: String
        let lines: [OCRLine]
    }

    public let format: Format

    public init(format: Format) {
        self.format = format
    }

    public func render(_ result: OCRResult) throws -> String {
        switch format {
        case .plainText:
            return result.text
        case .json:
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(JSONPayload(text: result.text, lines: result.lines))
            return String(decoding: data, as: UTF8.self)
        }
    }
}
