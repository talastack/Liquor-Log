import SwiftUI
import UIKit
import Vision
import LiquorEngine

/// Gets the text off a photograph of a label.
///
/// Apple's Vision framework — **not Vision Pro**, which is a headset. Vision is
/// a software framework present on every iPhone and iPad since iOS 11, with
/// text recognition since iOS 13. It runs entirely on the device: no network,
/// no account, no API key, no cost, and it works in a shop with no signal.
///
/// This file is the ONLY part of label reading that cannot be tested without a
/// device, which is why it does as little as possible. Everything it produces
/// goes straight to `LabelReader`, which is pure logic in the engine and fully
/// tested — and which will port to Android unchanged, since ML Kit's on-device
/// text recognition returns the same shape of thing.
enum LabelScanner {

    enum Failure: Error, LocalizedError {
        case unreadableImage
        case nothingFound

        var errorDescription: String? {
            switch self {
            case .unreadableImage: return "That image could not be read."
            case .nothingFound: return "No text found. Try filling the frame with the label."
            }
        }
    }

    /// Recognised lines, in whatever order Vision found them.
    ///
    /// Order is not reading order on a wrap-around label, which is why
    /// `LabelReader` is order-independent and has a test saying so.
    static func recognise(_ image: UIImage) async throws -> [String] {
        guard let cgImage = image.cgImage else { throw Failure.unreadableImage }

        let request = VNRecognizeTextRequest()

        // `accurate` over `fast`: a bourbon label is dense, curved and often
        // foil-stamped, and this runs once on a still image rather than per
        // frame. There is no reason to trade accuracy for speed here.
        request.recognitionLevel = .accurate

        // LANGUAGE CORRECTION OFF, and this matters more than it looks.
        // Correction assumes dictionary words. A label is proper nouns and
        // codes -- it would happily turn OESQ into "DESK", B523 into "B52",
        // and Weller into "Wellers". The whole value of the feature is the
        // codes, so the dictionary is the enemy.
        request.usesLanguageCorrection = false

        let handler = VNImageRequestHandler(
            cgImage: cgImage,
            // Carried through from the photo. A picture taken in portrait is
            // stored rotated with an orientation flag, and ignoring it hands
            // Vision a sideways label that recognises as nothing at all.
            orientation: orientation(of: image))

        try handler.perform([request])

        let lines = (request.results ?? []).compactMap {
            $0.topCandidates(1).first?.string
        }
        guard !lines.isEmpty else { throw Failure.nothingFound }
        return lines
    }

    private static func orientation(of image: UIImage) -> CGImagePropertyOrientation {
        switch image.imageOrientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

/// The system camera or photo library.
///
/// `UIImagePickerController` rather than a custom `AVCaptureSession`: it brings
/// its own permission prompt, its own retake flow and its own accessibility,
/// and a hand-rolled camera would be several hundred lines to arrive somewhere
/// worse.
struct ImagePicker: UIViewControllerRepresentable {
    let source: UIImagePickerController.SourceType
    let onPicked: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    /// The simulator has no camera, and asking for one there presents a black
    /// screen with no explanation.
    static var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = source
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate,
                             UINavigationControllerDelegate {
        private let parent: ImagePicker

        init(_ parent: ImagePicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // `.originalImage`, never `.editedImage`: cropping is off, and the
            // original carries the full resolution Vision needs for small
            // print like a batch code.
            if let image = info[.originalImage] as? UIImage {
                parent.onPicked(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}
