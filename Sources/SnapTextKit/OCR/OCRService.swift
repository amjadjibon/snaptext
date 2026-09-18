import CoreGraphics
import Foundation
import Vision

public enum RecognitionLevel: String, Equatable, Sendable {
    case fast
    case accurate

    var visionLevel: VNRequestTextRecognitionLevel {
        switch self {
        case .fast: return .fast
        case .accurate: return .accurate
        }
    }
}

/// Runs Apple's Vision text recognizer. Entirely on-device: no network, no API key.
public struct OCRService: Sendable {
    public init() {}

    public func recognize(
        image: CGImage,
        level: RecognitionLevel = .accurate,
        usesLanguageCorrection: Bool = true,
        languages: [String] = []
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level.visionLevel
        request.usesLanguageCorrection = usesLanguageCorrection

        if !languages.isEmpty {
            let supported = (try? request.supportedRecognitionLanguages()) ?? []
            if let unsupported = languages.first(where: { !supported.contains($0) }) {
                throw SnapTextError.unsupportedLanguage(unsupported, supported: supported)
            }
            request.recognitionLanguages = languages
        }

        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw SnapTextError.recognitionFailed(error)
        }

        let lines = (request.results ?? []).compactMap { observation -> OCRLine? in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            let box = observation.boundingBox
            return OCRLine(
                text: candidate.string,
                confidence: Double(candidate.confidence),
                box: TextBox(
                    x: box.origin.x,
                    y: box.origin.y,
                    width: box.width,
                    height: box.height
                )
            )
        }

        return OCRResult(lines: lines)
    }
}
