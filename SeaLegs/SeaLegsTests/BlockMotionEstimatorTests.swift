import CoreVideo
import XCTest
@testable import SeaLegs

final class BlockMotionEstimatorTests: XCTestCase {
    func testIdenticalFramesReportNearZeroMotion() {
        let frame = makeFrame { _, _ in 128 }
        let metrics = BlockMotionEstimator().estimate(previous: frame, current: frame, timestamp: 1)

        XCTAssertLessThan(metrics.meanPeripheralMotion, 0.01)
        XCTAssertGreaterThan(metrics.repeatedFrameProbability, 0.9)
    }

    func testRightShiftIncreasesHorizontalMotion() {
        let previous = texturedFrame()
        let current = shifted(previous, dx: 2, dy: 0)
        let metrics = BlockMotionEstimator().estimate(previous: previous, current: current, timestamp: 1)

        XCTAssertGreaterThan(metrics.horizontalMotion, 0.05)
        XCTAssertGreaterThan(metrics.meanPeripheralMotion, 0.05)
    }

    func testCenterOnlyMotionKeepsPeripheralMotionLower() {
        let previous = texturedFrame()
        let shiftedFrame = shifted(previous, dx: 2, dy: 0)
        let centerOnly = makeFrame { x, y in
            x > 65 && x < 95 && y > 35 && y < 55 ? shiftedFrame.luma[y * previous.width + x] : previous.luma[y * previous.width + x]
        }
        let peripheralOnly = makeFrame { x, y in
            if x < 32 || x > 128 || y < 18 || y > 72 {
                return shifted(previous, dx: 2, dy: 0).luma[y * previous.width + x]
            }
            return previous.luma[y * previous.width + x]
        }
        let centerMetrics = BlockMotionEstimator().estimate(previous: previous, current: centerOnly, timestamp: 1)
        let peripheralMetrics = BlockMotionEstimator().estimate(previous: previous, current: peripheralOnly, timestamp: 1)

        XCTAssertLessThan(centerMetrics.meanPeripheralMotion, peripheralMetrics.meanPeripheralMotion)
    }

    func testPeripheralMotionRaisesPeripheralMetric() {
        let previous = texturedFrame()
        let shiftedFrame = shifted(previous, dx: 2, dy: 0)
        let current = makeFrame { x, y in
            if x < 32 || x > 128 || y < 18 || y > 72 {
                return shiftedFrame.luma[y * previous.width + x]
            }
            return previous.luma[y * previous.width + x]
        }
        let metrics = BlockMotionEstimator().estimate(previous: previous, current: current, timestamp: 1)

        XCTAssertGreaterThan(metrics.meanPeripheralMotion, 0.05)
    }

    func testLowTextureFrameReportsHighLowTextureRatio() {
        let previous = makeFrame { _, _ in 42 }
        let current = makeFrame { _, _ in 42 }
        let metrics = BlockMotionEstimator().estimate(previous: previous, current: current, timestamp: 1)

        XCTAssertGreaterThan(metrics.lowTextureRatio, 0.9)
    }

    func testOutwardZoomRaisesRadialExpansion() {
        let previous = texturedFrame()
        let outward = scaled(previous, scale: 1.03)
        let inward = scaled(previous, scale: 0.97)
        let outwardMetrics = BlockMotionEstimator().estimate(previous: previous, current: outward, timestamp: 1)
        let inwardMetrics = BlockMotionEstimator().estimate(previous: previous, current: inward, timestamp: 1)

        XCTAssertGreaterThan(outwardMetrics.radialExpansion, 0.02)
        XCTAssertGreaterThan(outwardMetrics.radialExpansion, inwardMetrics.radialExpansion)
    }

    private func makeFrame(_ value: (Int, Int) -> UInt8) -> ReducedFrame {
        let width = 160
        let height = 90
        var luma: [UInt8] = []
        luma.reserveCapacity(width * height)
        for y in 0..<height {
            for x in 0..<width {
                luma.append(value(x, y))
            }
        }
        return ReducedFrame(width: width, height: height, luma: luma)
    }

    private func texturedFrame() -> ReducedFrame {
        makeFrame { x, y in
            let value = (x * 37 + y * 53 + (x * y) % 97 + (x / 3) * 19 + (y / 5) * 23) % 256
            return UInt8(value)
        }
    }

    private func shifted(_ frame: ReducedFrame, dx: Int, dy: Int) -> ReducedFrame {
        var luma = frame.luma
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let sx = min(max(x - dx, 0), frame.width - 1)
                let sy = min(max(y - dy, 0), frame.height - 1)
                luma[y * frame.width + x] = frame.luma[sy * frame.width + sx]
            }
        }
        return ReducedFrame(width: frame.width, height: frame.height, luma: luma)
    }

    private func scaled(_ frame: ReducedFrame, scale: Float) -> ReducedFrame {
        let centerX = Float(frame.width - 1) / 2
        let centerY = Float(frame.height - 1) / 2
        var luma = frame.luma
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let sourceX = centerX + (Float(x) - centerX) / scale
                let sourceY = centerY + (Float(y) - centerY) / scale
                let sx = min(max(Int(sourceX.rounded()), 0), frame.width - 1)
                let sy = min(max(Int(sourceY.rounded()), 0), frame.height - 1)
                luma[y * frame.width + x] = frame.luma[sy * frame.width + sx]
            }
        }
        return ReducedFrame(width: frame.width, height: frame.height, luma: luma)
    }
}

final class FrameReducerTests: XCTestCase {
    func testBGRAFrameReducesToTargetLumaSize() throws {
        let pixelBuffer = try makePixelBuffer(width: 4, height: 4) { x, y in
            (blue: UInt8(x * 20), green: UInt8(y * 30), red: UInt8(100 + x + y), alpha: 255)
        }
        let reducer = FrameReducer(targetWidth: 2, targetHeight: 2)

        let frame = try XCTUnwrap(reducer.reduce(pixelBuffer: pixelBuffer))

        XCTAssertEqual(frame.width, 2)
        XCTAssertEqual(frame.height, 2)
        XCTAssertEqual(frame.luma.count, 4)
        XCTAssertEqual(frame.luma[0], expectedLuma(blue: 0, green: 0, red: 100))
        XCTAssertEqual(frame.luma[3], expectedLuma(blue: 40, green: 60, red: 104))
    }

    private func makePixelBuffer(
        width: Int,
        height: Int,
        pixel: (Int, Int) -> (blue: UInt8, green: UInt8, red: UInt8, alpha: UInt8)
    ) throws -> CVPixelBuffer {
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            nil,
            &pixelBuffer
        )
        XCTAssertEqual(status, kCVReturnSuccess)
        let buffer = try XCTUnwrap(pixelBuffer)
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let baseAddress = try XCTUnwrap(CVPixelBufferGetBaseAddress(buffer))
        for y in 0..<height {
            let row = baseAddress.advanced(by: y * bytesPerRow).assumingMemoryBound(to: UInt8.self)
            for x in 0..<width {
                let value = pixel(x, y)
                row[x * 4] = value.blue
                row[x * 4 + 1] = value.green
                row[x * 4 + 2] = value.red
                row[x * 4 + 3] = value.alpha
            }
        }
        return buffer
    }

    private func expectedLuma(blue: UInt8, green: UInt8, red: UInt8) -> UInt8 {
        let luma = (77 * UInt32(red) + 150 * UInt32(green) + 29 * UInt32(blue)) >> 8
        return UInt8(clamping: Int(luma))
    }
}
