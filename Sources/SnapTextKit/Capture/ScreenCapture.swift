import CoreGraphics
import Foundation

/// Captures the screen by driving macOS' built-in `screencapture` utility,
/// which already provides the region-selection UI.
public struct ScreenCapture: Sendable {
    public enum Mode: Equatable, Sendable {
        case fullScreen
        case region
    }

    private static let executable = URL(fileURLWithPath: "/usr/sbin/screencapture")

    public init() {}

    /// Captures to a temporary PNG, loads it, and removes the file before returning.
    public func capture(_ mode: Mode) throws -> CGImage {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("snaptext-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: url) }

        var arguments = ["-x"]  // no camera shutter sound
        if mode == .region {
            arguments.append("-i")
        }
        arguments.append(url.path)

        let process = Process()
        process.executableURL = Self.executable
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            throw SnapTextError.captureFailed(error.localizedDescription)
        }

        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        let captured = FileManager.default.fileExists(atPath: url.path)

        guard process.terminationStatus == 0, captured else {
            // `screencapture -i` leaves no file behind when the user presses Escape.
            if mode == .region, !captured {
                throw SnapTextError.captureCancelled
            }
            let detail = String(decoding: errorData, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw SnapTextError.captureFailed(detail)
        }

        return try ImageLoader().load(path: url.path)
    }
}
