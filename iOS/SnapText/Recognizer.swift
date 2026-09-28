import AppIntents
import CoreGraphics
import Foundation
import SnapTextKit

/// One recognized image: a photo, a pasted screenshot, or a scanned page.
struct Page: Identifiable, Sendable {
    let id = UUID()
    let image: CGImage
    let result: OCRResult
}

/// How recognized text is presented, in the app and in Shortcuts.
enum OutputStyle: String, CaseIterable, AppEnum {
    case text
    case layout
    case json

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Output"
    static let caseDisplayRepresentations: [OutputStyle: DisplayRepresentation] = [
        .text: "Plain Text",
        .layout: "Layout",
        .json: "JSON"
    ]

    var format: OutputFormatter.Format {
        switch self {
        case .text: return .plainText
        case .layout: return .layout
        case .json: return .json
        }
    }
}

/// The user's recognition preferences, stored in `UserDefaults` so the app and
/// the Shortcuts action read the same values.
struct RecognitionSettings: Sendable {
    enum Key {
        static let fast = "fastRecognition"
        static let languageCorrection = "languageCorrection"
        static let languages = "languages"
    }

    var level: RecognitionLevel
    var usesLanguageCorrection: Bool
    var languages: [String]

    static var current: RecognitionSettings {
        let defaults = UserDefaults.standard
        return RecognitionSettings(
            level: defaults.bool(forKey: Key.fast) ? .fast : .accurate,
            usesLanguageCorrection: defaults.object(forKey: Key.languageCorrection) as? Bool ?? true,
            languages: decodeLanguages(defaults.string(forKey: Key.languages) ?? "")
        )
    }

    /// Languages are stored as one comma-separated string, highest priority first.
    static func decodeLanguages(_ stored: String) -> [String] {
        stored.split(separator: ",").map(String.init)
    }

    static func encodeLanguages(_ languages: [String]) -> String {
        languages.joined(separator: ",")
    }
}

enum Recognizer {
    /// Loads and recognizes off the main thread; throws `noTextDetected` only
    /// when no page has any text.
    static func recognize(
        _ loadImages: @escaping @Sendable () throws -> [CGImage],
        settings: RecognitionSettings = .current
    ) async throws -> [Page] {
        try await Task.detached(priority: .userInitiated) {
            let pages = try loadImages().map { image in
                Page(
                    image: image,
                    result: try OCRService().recognize(
                        image: image,
                        level: settings.level,
                        usesLanguageCorrection: settings.usesLanguageCorrection,
                        languages: settings.languages
                    )
                )
            }
            guard pages.contains(where: { !$0.result.isEmpty }) else {
                throw SnapTextError.noTextDetected
            }
            return pages
        }.value
    }

    /// Pages are separated by a blank line; several pages of JSON become an array.
    static func render(_ pages: [Page], as style: OutputStyle) throws -> String {
        let formatter = OutputFormatter(format: style.format)
        let rendered = try pages.map { try formatter.render($0.result) }

        if style == .json, rendered.count > 1 {
            return "[\n" + rendered.joined(separator: ",\n") + "\n]"
        }
        return rendered.joined(separator: "\n\n")
    }

    /// A sentence-cased message for anything the recognizer or loader throws.
    static func message(for error: Error) -> String {
        let message = (error as? SnapTextError)?.message ?? error.localizedDescription
        return message.prefix(1).uppercased() + message.dropFirst()
    }
}
