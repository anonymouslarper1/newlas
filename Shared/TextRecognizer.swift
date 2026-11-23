import CoreGraphics
import CoreVideo
import ImageIO
import Vision

/// On-device OCR. Nothing leaves the phone.
enum TextRecognizer {
    private static func makeRequest(accurate: Bool) -> VNRecognizeTextRequest {
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = accurate ? .accurate : .fast
        req.usesLanguageCorrection = false
        return req
    }

    private static func lines(from req: VNRecognizeTextRequest) -> [String] {
        // Top-to-bottom reading order (Vision's origin is bottom-left).
        (req.results ?? [])
            .sorted { $0.boundingBox.minY > $1.boundingBox.minY }
            .compactMap { $0.topCandidates(1).first?.string }
    }

    static func lines(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation, accurate: Bool) -> [String] {
        let req = makeRequest(accurate: accurate)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        do { try handler.perform([req]) } catch { return [] }
        return lines(from: req)
    }

    static func lines(cgImage: CGImage, accurate: Bool = true) -> [String] {
        let req = makeRequest(accurate: accurate)
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do { try handler.perform([req]) } catch { return [] }
        return lines(from: req)
    }
}
