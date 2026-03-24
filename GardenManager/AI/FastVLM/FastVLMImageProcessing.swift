import Accelerate
import CoreImage
import MLX
import MLXLMCommon
import MLXVLM

enum FastVLMImageProcessing {

    static func apply(_ image: CIImage, processing: UserInput.Processing?) -> CIImage {
        var image = image
        if let resize = processing?.resize {
            let scale = MediaProcessing.bestFitScale(image.extent.size, in: resize)
            image = image.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        }
        return image
    }

    static func centerCrop(_ image: CIImage, size: CGSize) -> CIImage {
        let extent = image.extent
        if extent.width <= size.width && extent.height <= size.height {
            return image
        }
        let targetWidth = min(extent.width, size.width)
        let targetHeight = min(extent.height, size.height)
        let crop = CGRect(
            x: (extent.maxX - targetWidth) / 2,
            y: (extent.maxY - targetHeight) / 2,
            width: targetWidth, height: targetHeight
        )
        return image
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
    }

    static func fitIn(_ size: CGSize, shortestEdge: Int) -> CGSize {
        let floatShortestEdge = CGFloat(shortestEdge)
        let (short, long) =
            size.width <= size.height ? (size.width, size.height) : (size.height, size.width)
        let newShort = floatShortestEdge
        let newLong = floatShortestEdge * long / short
        return size.width <= size.height
            ? CGSize(width: newShort, height: newLong) : CGSize(width: newLong, height: newShort)
    }

    static func resampleBicubic(_ image: CIImage, to size: CGSize) -> CIImage {
        let yScale = size.height / image.extent.height
        let xScale = size.width / image.extent.width
        let filter = CIFilter.bicubicScaleTransform()
        filter.inputImage = image
        filter.scale = Float(yScale)
        filter.aspectRatio = Float(xScale / yScale)
        let scaledImage = filter.outputImage!
        let exactRect = CGRect(x: 0, y: 0, width: size.width, height: size.height)
        return scaledImage.cropped(to: exactRect)
    }

    private static let context = CIContext()

    static func asPlanarMLXArray(_ image: CIImage, colorSpace: CGColorSpace? = nil) -> MLXArray {
        let size = image.extent.size
        let w = Int(size.width.rounded())
        let h = Int(size.height.rounded())

        let format = CIFormat.RGBAf
        let componentsPerPixel = 4
        let bytesPerComponent = MemoryLayout<Float32>.size
        let bytesPerPixel = componentsPerPixel * bytesPerComponent
        let bytesPerRow = w * bytesPerPixel

        var data = Data(count: w * h * bytesPerPixel)
        var planarData = Data(count: 3 * w * h * bytesPerComponent)
        data.withUnsafeMutableBytes { ptr in
            context.render(
                image, toBitmap: ptr.baseAddress!, rowBytes: bytesPerRow, bounds: image.extent,
                format: format, colorSpace: colorSpace)
            context.clearCaches()

            let vh = vImagePixelCount(h)
            let vw = vImagePixelCount(w)

            let rgbBytesPerRow = w * 3 * bytesPerComponent
            var rgbaSrc = vImage_Buffer(
                data: ptr.baseAddress!, height: vh, width: vw, rowBytes: bytesPerRow)
            var rgbDest = vImage_Buffer(
                data: ptr.baseAddress!, height: vh, width: vw, rowBytes: rgbBytesPerRow)
            vImageConvert_RGBAFFFFtoRGBFFF(&rgbaSrc, &rgbDest, vImage_Flags(kvImageNoFlags))

            planarData.withUnsafeMutableBytes { planarPtr in
                let planeBytesPerRow = w * bytesPerComponent
                var rDest = vImage_Buffer(
                    data: planarPtr.baseAddress!.advanced(by: 0 * planeBytesPerRow * h),
                    height: vh, width: vw, rowBytes: planeBytesPerRow)
                var gDest = vImage_Buffer(
                    data: planarPtr.baseAddress!.advanced(by: 1 * planeBytesPerRow * h),
                    height: vh, width: vw, rowBytes: planeBytesPerRow)
                var bDest = vImage_Buffer(
                    data: planarPtr.baseAddress!.advanced(by: 2 * planeBytesPerRow * h),
                    height: vh, width: vw, rowBytes: planeBytesPerRow)
                vImageConvert_RGBFFFtoPlanarF(
                    &rgbDest, &rDest, &gDest, &bDest, vImage_Flags(kvImageNoFlags))
            }
        }

        return MLXArray(planarData, [1, 3, h, w], type: Float32.self)
    }
}
