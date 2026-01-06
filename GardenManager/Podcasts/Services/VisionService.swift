import Vision
import UIKit

actor VisionService {
    func extractText(from image: UIImage) async throws -> [String] {
        return try await withCheckedThrowingContinuation { continuation in
            guard let cgImage = image.cgImage else {
                continuation.resume(throwing: VisionError.invalidImage)
                return
            }
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                continuation.resume(returning: recognizedStrings)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    enum VisionError: Error {
        case invalidImage
        case recognitionFailed
        
        var localizedDescription: String {
            switch self {
            case .invalidImage:
                return "Invalid image format"
            case .recognitionFailed:
                return "Text recognition failed"
            }
        }
    }
}
