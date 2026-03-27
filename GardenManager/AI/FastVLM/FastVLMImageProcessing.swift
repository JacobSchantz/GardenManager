// FastVLM is disabled for now while we integrate GGUF models via SwiftLlama
// This file needs UserInput dependency resolved before FastVLM can work

import CoreImage

enum FastVLMImageProcessing {

    static func apply(_ image: CIImage, processing: Any?) -> CIImage {
        return image
    }

    static func centerCrop(_ image: CIImage, size: CGSize) -> CIImage {
        return image
    }

    static func fitIn(_ size: CGSize, shortestEdge: Int) -> CGSize {
        return size
    }

    static func resampleBicubic(_ image: CIImage, to size: CGSize) -> CIImage {
        return image
    }
}