import CoreVideo
import Foundation

final class FrameReducer {
    let targetWidth: Int
    let targetHeight: Int

    init(targetWidth: Int = 160, targetHeight: Int = 90) {
        self.targetWidth = targetWidth
        self.targetHeight = targetHeight
    }

    func reduce(pixelBuffer: CVPixelBuffer) -> ReducedFrame? {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let sourceWidth = CVPixelBufferGetWidth(pixelBuffer)
        let sourceHeight = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return nil
        }

        var output = [UInt8](repeating: 0, count: targetWidth * targetHeight)
        for y in 0..<targetHeight {
            let sourceY = y * sourceHeight / targetHeight
            let row = baseAddress.advanced(by: sourceY * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<targetWidth {
                let sourceX = x * sourceWidth / targetWidth
                let index = sourceX * 4
                let blue = UInt32(row[index])
                let green = UInt32(row[index + 1])
                let red = UInt32(row[index + 2])
                let luma = (77 * red + 150 * green + 29 * blue) >> 8
                output[y * targetWidth + x] = UInt8(clamping: Int(luma))
            }
        }

        return ReducedFrame(width: targetWidth, height: targetHeight, luma: output)
    }
}
