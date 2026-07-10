import Metal
import MetalKit
import simd

struct OverlayUniforms {
    var viewportSize: SIMD2<Float>
    var vignetteOpacity: Float
    var vignetteInnerRadius: Float
    var vignetteOuterRadius: Float
    var vignetteSoftness: Float
    var centerDotEnabled: UInt32
    var centerDotOpacity: Float
    var centerDotRadius: Float
    var crosshairEnabled: UInt32
    var crosshairOpacity: Float
    var crosshairLength: Float
    var crosshairThickness: Float
    var horizonEnabled: UInt32
    var horizonOpacity: Float
    var horizonY: Float
    var dashboardEnabled: UInt32
    var dashboardOpacity: Float
    var virtualNoseEnabled: UInt32
    var virtualNoseOpacity: Float
    var peripheralFrameEnabled: UInt32
    var peripheralFrameOpacity: Float
    var peripheralFrameThickness: Float
}

@MainActor
final class OverlayRenderer: NSObject, MTKViewDelegate {
    private weak var state: OverlayState?
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let pipelineState: MTLRenderPipelineState

    init?(metalView: MTKView, state: OverlayState) {
        guard
            let device = metalView.device ?? MTLCreateSystemDefaultDevice(),
            let commandQueue = device.makeCommandQueue(),
            let library = device.makeDefaultLibrary(),
            let vertexFunction = library.makeFunction(name: "overlayVertex"),
            let fragmentFunction = library.makeFunction(name: "overlayFragment")
        else {
            return nil
        }

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        guard let attachment = descriptor.colorAttachments[0] else {
            return nil
        }
        attachment.pixelFormat = metalView.colorPixelFormat
        attachment.isBlendingEnabled = true
        attachment.sourceRGBBlendFactor = .sourceAlpha
        attachment.destinationRGBBlendFactor = .oneMinusSourceAlpha
        attachment.rgbBlendOperation = .add
        attachment.sourceAlphaBlendFactor = .sourceAlpha
        attachment.destinationAlphaBlendFactor = .oneMinusSourceAlpha
        attachment.alphaBlendOperation = .add

        guard let pipelineState = try? device.makeRenderPipelineState(descriptor: descriptor) else {
            return nil
        }

        self.state = state
        self.device = device
        self.commandQueue = commandQueue
        self.pipelineState = pipelineState
        super.init()
    }

    nonisolated func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

    nonisolated func draw(in view: MTKView) {
        Task { @MainActor in
            render(in: view)
        }
    }

    private func render(in view: MTKView) {
        guard
            let state,
            state.enabled,
            let descriptor = view.currentRenderPassDescriptor,
            let drawable = view.currentDrawable,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: descriptor)
        else {
            return
        }

        var uniforms = OverlayUniforms(
            viewportSize: SIMD2<Float>(Float(view.drawableSize.width), Float(view.drawableSize.height)),
            vignetteOpacity: state.vignetteOpacity,
            vignetteInnerRadius: state.vignetteInnerRadius,
            vignetteOuterRadius: state.vignetteOuterRadius,
            vignetteSoftness: state.vignetteSoftness,
            centerDotEnabled: state.centerDotEnabled ? 1 : 0,
            centerDotOpacity: state.centerDotOpacity,
            centerDotRadius: state.centerDotRadius,
            crosshairEnabled: state.crosshairEnabled ? 1 : 0,
            crosshairOpacity: state.crosshairOpacity,
            crosshairLength: state.crosshairLength,
            crosshairThickness: state.crosshairThickness,
            horizonEnabled: state.horizonEnabled ? 1 : 0,
            horizonOpacity: state.horizonOpacity,
            horizonY: state.horizonY,
            dashboardEnabled: state.dashboardEnabled ? 1 : 0,
            dashboardOpacity: state.dashboardOpacity,
            virtualNoseEnabled: state.virtualNoseEnabled ? 1 : 0,
            virtualNoseOpacity: state.virtualNoseOpacity,
            peripheralFrameEnabled: state.peripheralFrameEnabled ? 1 : 0,
            peripheralFrameOpacity: state.peripheralFrameOpacity,
            peripheralFrameThickness: state.peripheralFrameThickness
        )

        encoder.setRenderPipelineState(pipelineState)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<OverlayUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 6)
        encoder.endEncoding()
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
