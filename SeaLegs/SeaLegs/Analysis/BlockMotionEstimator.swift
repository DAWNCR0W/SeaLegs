import Foundation

struct MotionVector {
    let dx: Float
    let dy: Float
    let weight: Float
    let cx: Float
    let cy: Float
}

final class BlockMotionEstimator {
    private let blockSize: Int
    private let stride: Int
    private let searchRadius: Int
    private let varianceThreshold: Float

    init(blockSize: Int = 8, stride: Int = 8, searchRadius: Int = 3, varianceThreshold: Float = 12) {
        self.blockSize = blockSize
        self.stride = stride
        self.searchRadius = searchRadius
        self.varianceThreshold = varianceThreshold
    }

    func estimate(previous: ReducedFrame, current: ReducedFrame, timestamp: TimeInterval) -> VisualMotionMetrics {
        guard previous.width == current.width, previous.height == current.height, previous.luma.count == current.luma.count else {
            return .zero
        }

        let width = current.width
        let height = current.height
        var vectors: [MotionVector] = []
        var lowTexture = 0
        var totalBlocks = 0
        var totalBlockWeight: Float = 0

        var by = blockSize
        while by < height - blockSize {
            var bx = blockSize
            while bx < width - blockSize {
                totalBlocks += 1
                let weight = peripheralWeight(
                    blockCenterX: Float(bx),
                    blockCenterY: Float(by),
                    width: Float(width),
                    height: Float(height)
                )
                totalBlockWeight += weight

                let variance = blockVariance(current.luma, width: width, x: bx, y: by, block: blockSize)
                if variance < varianceThreshold {
                    lowTexture += 1
                    bx += stride
                    continue
                }

                var bestSSD = Int.max
                var bestDX = 0
                var bestDY = 0

                for dy in -searchRadius...searchRadius {
                    for dx in -searchRadius...searchRadius {
                        let previousX = bx + dx
                        let previousY = by + dy
                        guard isBlockInsideFrame(
                            x: previousX,
                            y: previousY,
                            block: blockSize,
                            width: width,
                            height: height
                        ) else {
                            continue
                        }

                        let ssd = blockSSD(
                            previous.luma,
                            current.luma,
                            width: width,
                            previousX: previousX,
                            previousY: previousY,
                            currentX: bx,
                            currentY: by,
                            block: blockSize
                        )
                        if ssd < bestSSD {
                            bestSSD = ssd
                            bestDX = dx
                            bestDY = dy
                        }
                    }
                }

                if bestSSD < Int.max {
                    vectors.append(MotionVector(dx: Float(-bestDX), dy: Float(-bestDY), weight: weight, cx: Float(bx), cy: Float(by)))
                }
                bx += stride
            }
            by += stride
        }

        return aggregate(
            vectors: vectors,
            lowTexture: lowTexture,
            totalBlocks: totalBlocks,
            totalBlockWeight: totalBlockWeight,
            width: width,
            height: height,
            timestamp: timestamp,
            repeatedFrameProbability: meanAbsoluteDifference(previous.luma, current.luma) < 1.5 ? 1 : 0
        )
    }

    func peripheralWeight(blockCenterX: Float, blockCenterY: Float, width: Float, height: Float) -> Float {
        let nx = (blockCenterX / width - 0.5) * 2
        let ny = (blockCenterY / height - 0.5) * 2
        let radius = sqrt(nx * nx + ny * ny)
        let base = max(0.15, min(1, radius))
        if abs(nx) < 0.25 && abs(ny) < 0.25 {
            return base * 0.35
        }
        return base
    }

    private func aggregate(
        vectors: [MotionVector],
        lowTexture: Int,
        totalBlocks: Int,
        totalBlockWeight: Float,
        width: Int,
        height: Int,
        timestamp: TimeInterval,
        repeatedFrameProbability: Float
    ) -> VisualMotionMetrics {
        guard !vectors.isEmpty else {
            return VisualMotionMetrics(
                timestamp: timestamp,
                meanPeripheralMotion: 0,
                medianPeripheralMotion: 0,
                radialExpansion: 0,
                rotationProxy: 0,
                verticalMotion: 0,
                horizontalMotion: 0,
                lowTextureRatio: Float(lowTexture) / Float(max(totalBlocks, 1)),
                repeatedFrameProbability: repeatedFrameProbability
            )
        }

        var weightedMagSum: Float = 0
        var weightSum: Float = 0
        var radialSum: Float = 0
        var rotationSum: Float = 0
        var horizontalSum: Float = 0
        var verticalSum: Float = 0
        var magnitudes: [Float] = []

        for vector in vectors {
            let magnitude = sqrt(vector.dx * vector.dx + vector.dy * vector.dy)
            weightedMagSum += magnitude * vector.weight
            weightSum += vector.weight
            magnitudes.append(magnitude)

            let nx = (vector.cx / Float(width) - 0.5) * 2
            let ny = (vector.cy / Float(height) - 0.5) * 2
            let length = max(0.001, sqrt(nx * nx + ny * ny))
            let ux = nx / length
            let uy = ny / length
            let radial = vector.dx * ux + vector.dy * uy
            let tangential = abs(vector.dx * (-uy) + vector.dy * ux)

            radialSum += max(0, radial) * vector.weight
            rotationSum += tangential * vector.weight
            horizontalSum += abs(vector.dx) * vector.weight
            verticalSum += abs(vector.dy) * vector.weight
        }

        let aggregateWeight = max(totalBlockWeight, weightSum, 0.001)
        let mean = weightedMagSum / aggregateWeight
        let sortedMagnitudes = magnitudes.sorted()
        let median = sortedMagnitudes[sortedMagnitudes.count / 2]
        let normalize: (Float) -> Float = { min(1, $0 / 3) }

        return VisualMotionMetrics(
            timestamp: timestamp,
            meanPeripheralMotion: normalize(mean),
            medianPeripheralMotion: normalize(median),
            radialExpansion: normalize(radialSum / aggregateWeight),
            rotationProxy: normalize(rotationSum / aggregateWeight),
            verticalMotion: normalize(verticalSum / aggregateWeight),
            horizontalMotion: normalize(horizontalSum / aggregateWeight),
            lowTextureRatio: Float(lowTexture) / Float(max(totalBlocks, 1)),
            repeatedFrameProbability: repeatedFrameProbability
        )
    }
}

func isBlockInsideFrame(x: Int, y: Int, block: Int, width: Int, height: Int) -> Bool {
    x >= 0 && y >= 0 && x + block <= width && y + block <= height
}

func blockVariance(_ luma: [UInt8], width: Int, x: Int, y: Int, block: Int) -> Float {
    var sum = 0
    var sumSquares = 0
    let count = block * block
    for row in y..<y + block {
        for col in x..<x + block {
            let value = Int(luma[row * width + col])
            sum += value
            sumSquares += value * value
        }
    }
    let mean = Float(sum) / Float(count)
    return Float(sumSquares) / Float(count) - mean * mean
}

func blockSSD(
    _ previous: [UInt8],
    _ current: [UInt8],
    width: Int,
    previousX: Int,
    previousY: Int,
    currentX: Int,
    currentY: Int,
    block: Int
) -> Int {
    var sum = 0
    for row in 0..<block {
        for col in 0..<block {
            let previousValue = Int(previous[(previousY + row) * width + previousX + col])
            let currentValue = Int(current[(currentY + row) * width + currentX + col])
            let diff = previousValue - currentValue
            sum += diff * diff
        }
    }
    return sum
}

func meanAbsoluteDifference(_ lhs: [UInt8], _ rhs: [UInt8]) -> Float {
    guard lhs.count == rhs.count, !lhs.isEmpty else {
        return 0
    }
    var sum = 0
    for index in lhs.indices {
        sum += abs(Int(lhs[index]) - Int(rhs[index]))
    }
    return Float(sum) / Float(lhs.count)
}
