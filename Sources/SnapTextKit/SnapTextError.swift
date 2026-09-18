import Foundation

/// Every failure the CLI can report, together with the exit code it maps to.
///
/// Exit codes are part of the tool's contract:
///
///     0  success
///     1  OCR/runtime failure
///     2  invalid CLI arguments
///     3  image could not be loaded
///     4  screenshot cancelled or failed
public enum SnapTextError: Error {
    case usage(String)
    case unsupportedLanguage(String, supported: [String])
    case imageNotFound(String)
    case unreadableImage(String)
    case clipboardHasNoImage
    case captureCancelled
    case captureFailed(String)
    case noTextDetected
    case recognitionFailed(Error)

    public var exitCode: Int32 {
        switch self {
        case .usage, .unsupportedLanguage:
            return 2
        case .imageNotFound, .unreadableImage, .clipboardHasNoImage:
            return 3
        case .captureCancelled, .captureFailed:
            return 4
        case .noTextDetected, .recognitionFailed:
            return 1
        }
    }

    /// Single-line message, printed to stderr as `snaptext: <message>`.
    public var message: String {
        switch self {
        case .usage(let detail):
            return detail
        case .unsupportedLanguage(let code, let supported):
            return "unsupported language: \(code) (supported: \(supported.joined(separator: ", ")))"
        case .imageNotFound(let path):
            return "image not found: \(path)"
        case .unreadableImage(let path):
            return "unable to read image: \(path)"
        case .clipboardHasNoImage:
            return "clipboard does not contain an image"
        case .captureCancelled:
            return "screenshot capture cancelled"
        case .captureFailed(let detail):
            return detail.isEmpty ? "screenshot capture failed" : "screenshot capture failed: \(detail)"
        case .noTextDetected:
            return "no text detected"
        case .recognitionFailed(let error):
            return "text recognition failed: \(error.localizedDescription)"
        }
    }

    /// Extra detail shown only with `--verbose`.
    public var verboseDetail: String? {
        switch self {
        case .recognitionFailed(let error):
            return String(describing: error)
        case .captureCancelled:
            return "screencapture produced no image; if this was not a cancellation, grant Screen Recording permission to your terminal in System Settings > Privacy & Security."
        default:
            return nil
        }
    }
}
