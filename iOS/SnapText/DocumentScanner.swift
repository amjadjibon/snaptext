import CoreGraphics
import SwiftUI
import VisionKit

/// VisionKit's document camera: edge detection, perspective correction, and
/// multi-page capture. Calls `onFinish` with the pages (none if cancelled) or the failure.
struct DocumentScanner: UIViewControllerRepresentable {
    let onFinish: (Result<[CGImage], Error>) -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onFinish: (Result<[CGImage], Error>) -> Void

        init(onFinish: @escaping (Result<[CGImage], Error>) -> Void) {
            self.onFinish = onFinish
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFinishWith scan: VNDocumentCameraScan
        ) {
            // Scanned pages come back upright, so `cgImage` is safe to use as-is.
            onFinish(.success((0..<scan.pageCount).compactMap { scan.imageOfPage(at: $0).cgImage }))
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            onFinish(.success([]))
        }

        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController,
            didFailWithError error: Error
        ) {
            onFinish(.failure(error))
        }
    }
}
