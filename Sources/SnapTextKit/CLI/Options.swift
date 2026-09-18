import Foundation

/// Where the image to recognize comes from.
public enum ImageSource: Equatable, Sendable {
    case file(String)
    case clipboard
    case fullScreen
    case region
}

/// A fully parsed command line.
public struct Options: Equatable, Sendable {
    public var source: ImageSource
    public var copy = false
    public var json = false
    public var languages: [String] = []
    public var recognitionLevel: RecognitionLevel = .accurate
    public var usesLanguageCorrection = true
    public var verbose = false

    public init(source: ImageSource) {
        self.source = source
    }
}

/// What the user asked for: run an OCR pass, or print help/version.
public enum Invocation: Equatable, Sendable {
    case run(Options)
    case help
    case version
}

public enum CommandLineParser {
    public static let usage = """
        snaptext \(SnapTextCLI.versionDescription) — local OCR for macOS, powered by Apple's Vision framework.

        USAGE:
          snaptext <image>            OCR an image file
          snaptext file <image>       OCR an image file
          snaptext clipboard          OCR the image on the clipboard
          snaptext screenshot         capture the whole screen, then OCR it
          snaptext region             select a screen region, then OCR it

        OPTIONS:
          --copy              copy the recognized text to the clipboard
          --json              print JSON (text, lines, confidence) instead of plain text
          --language <code>   recognition language hint, repeatable (e.g. en-US)
          --fast              favour speed over accuracy
          --accurate          favour accuracy over speed (default)
          --no-correction     disable Vision's language correction
          --verbose           report progress and error detail on stderr
          -h, --help          show this help
          --version           show the version

        EXAMPLES:
          snaptext receipt.png --copy
          snaptext receipt.png --json
          snaptext region --copy
          snaptext invoice.png | grep -i total
        """

    /// Parses arguments as passed by the shell, including the program name at index 0.
    public static func parse(_ arguments: [String]) throws -> Invocation {
        let arguments = Array(arguments.dropFirst())
        var source: ImageSource?
        var explicitFile = false
        var options = Options(source: .clipboard)  // placeholder, replaced below
        var positionals: [String] = []

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            index += 1

            switch argument {
            case "-h", "--help", "help":
                return .help
            case "--version", "version":
                return .version
            case "--copy", "-c":
                options.copy = true
            case "--json":
                options.json = true
            case "--fast":
                options.recognitionLevel = .fast
            case "--accurate":
                options.recognitionLevel = .accurate
            case "--no-correction":
                options.usesLanguageCorrection = false
            case "--verbose", "-v":
                options.verbose = true
            case "--language", "-l":
                guard index < arguments.count else {
                    throw SnapTextError.usage("--language requires a value, e.g. --language en-US")
                }
                options.languages.append(arguments[index])
                index += 1
            case "--":
                positionals.append(contentsOf: arguments[index...])
                index = arguments.count
            default:
                if argument.hasPrefix("-"), argument.count > 1 {
                    throw SnapTextError.usage("unknown option: \(argument)")
                }
                positionals.append(argument)
            }
        }

        var remaining = positionals[...]
        if let first = remaining.first {
            switch first {
            case "clipboard":
                source = .clipboard
                remaining = remaining.dropFirst()
            case "screenshot", "screen":
                source = .fullScreen
                remaining = remaining.dropFirst()
            case "region":
                source = .region
                remaining = remaining.dropFirst()
            case "file":
                explicitFile = true
                remaining = remaining.dropFirst()
            default:
                break
            }
        }

        if source == nil {
            guard let path = remaining.first else {
                throw SnapTextError.usage(explicitFile ? "file requires an image path" : "missing image path or command")
            }
            source = .file(path)
            remaining = remaining.dropFirst()
        }

        guard remaining.isEmpty else {
            throw SnapTextError.usage("unexpected argument: \(remaining.first!)")
        }

        options.source = source!
        return .run(options)
    }
}
