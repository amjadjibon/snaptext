import CoreGraphics
import Foundation
import Observation
import SnapTextKit

/// The screen's state: the pages last recognized, whether work is running, and
/// the last error to show.
@MainActor
@Observable
final class ScanModel {
    private(set) var pages: [Page] = []
    private(set) var isWorking = false
    var errorMessage: String?

    func recognize(images: [CGImage]) {
        run { images }
    }

    /// Encoded image bytes from Photos, Files, or a drop; decoded off the main thread.
    func recognize(data: [Data]) {
        run { try data.map { try ImageLoader().load(data: $0) } }
    }

    func pasteImage() {
        do {
            let image = try Clipboard().readImage()
            recognize(images: [image])
        } catch {
            errorMessage = Recognizer.message(for: error)
        }
    }

    func reset() {
        pages = []
    }

    private func run(_ loadImages: @escaping @Sendable () throws -> [CGImage]) {
        guard !isWorking else { return }
        isWorking = true
        Task {
            defer { isWorking = false }
            do {
                pages = try await Recognizer.recognize(loadImages)
            } catch {
                errorMessage = Recognizer.message(for: error)
            }
        }
    }
}
