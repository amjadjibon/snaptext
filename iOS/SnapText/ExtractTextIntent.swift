import AppIntents
import SnapTextKit
import UniformTypeIdentifiers

/// "Extract Text from Image" for Shortcuts: takes an image (a screenshot, a
/// photo, a share-sheet input) and returns its text, with no UI.
struct ExtractTextIntent: AppIntent {
    static let title: LocalizedStringResource = "Extract Text from Image"
    static let description = IntentDescription(
        "Recognizes the text in an image on your device. Nothing is uploaded."
    )

    @Parameter(title: "Image", supportedContentTypes: [.image])
    var image: IntentFile

    @Parameter(title: "Output", default: .text)
    var style: OutputStyle

    static var parameterSummary: some ParameterSummary {
        Summary("Extract text from \(\.$image) as \(\.$style)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        do {
            let data = image.data
            let name = image.filename
            let pages = try await Recognizer.recognize {
                [try ImageLoader().load(data: data, name: name)]
            }
            return .result(value: try Recognizer.render(pages, as: style))
        } catch {
            throw IntentFailure(message: Recognizer.message(for: error))
        }
    }
}

/// Shows the recognizer's own message in Shortcuts instead of a generic error.
struct IntentFailure: Error, CustomLocalizedStringResourceConvertible {
    let message: String

    var localizedStringResource: LocalizedStringResource {
        "\(message)"
    }
}

struct SnapTextShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ExtractTextIntent(),
            phrases: ["Extract text with \(.applicationName)"],
            shortTitle: "Extract Text",
            systemImageName: "text.viewfinder"
        )
    }
}
