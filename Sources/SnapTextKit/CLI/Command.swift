import CoreGraphics
import Foundation

/// The command-line front end: parse, fetch an image, recognize, emit.
public enum SnapTextCLI {
    public static let version = "0.3.0"

    /// Runs the CLI and returns the process exit code. Never throws.
    public static func run(arguments: [String]) -> Int32 {
        var verbose = false
        do {
            switch try CommandLineParser.parse(arguments) {
            case .help:
                print(CommandLineParser.usage)
            case .version:
                print("snaptext \(version)")
            case .run(let options):
                verbose = options.verbose
                try execute(options)
            }
            return 0
        } catch let error as SnapTextError {
            report(error, verbose: verbose)
            return error.exitCode
        } catch {
            printError("snaptext: \(error.localizedDescription)")
            return 1
        }
    }

    static func execute(_ options: Options) throws {
        let image = try loadImage(for: options)

        let result = try OCRService().recognize(
            image: image,
            level: options.recognitionLevel,
            usesLanguageCorrection: options.usesLanguageCorrection,
            languages: options.languages
        )

        guard !result.isEmpty else {
            throw SnapTextError.noTextDetected
        }

        let formatter = OutputFormatter(format: options.json ? .json : .plainText)
        print(try formatter.render(result))

        if options.copy {
            Clipboard().writeText(result.text)
        }

        if options.verbose {
            fflush(stdout)  // keep stdout and the stderr status lines in order on a terminal
            let plural = result.lines.count == 1 ? "line" : "lines"
            printError("✓ Recognized \(result.lines.count) \(plural)")
            if options.copy {
                printError("✓ Copied to clipboard")
            }
        }
    }

    private static func loadImage(for options: Options) throws -> CGImage {
        switch options.source {
        case .file(let path):
            return try ImageLoader().load(path: path)
        case .clipboard:
            return try Clipboard().readImage()
        case .fullScreen:
            if options.verbose { printError("Capturing the screen...") }
            return try ScreenCapture().capture(.fullScreen)
        case .region:
            if options.verbose { printError("Select an area of the screen...") }
            return try ScreenCapture().capture(.region)
        }
    }

    private static func report(_ error: SnapTextError, verbose: Bool) {
        printError("snaptext: \(error.message)")

        if verbose, let detail = error.verboseDetail {
            printError("snaptext: \(detail)")
        }

        if case .usage = error {
            printError("")
            printError(CommandLineParser.usage)
        }
    }

    private static func printError(_ message: String) {
        fputs(message + "\n", stderr)
    }
}
