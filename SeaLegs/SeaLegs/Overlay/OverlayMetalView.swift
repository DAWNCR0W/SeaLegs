import Combine
import MetalKit

@MainActor
final class OverlayMetalView: MTKView {
    private var overlayRenderer: OverlayRenderer?
    private var stateSubscription: AnyCancellable?

    func bind(state: OverlayState) {
        device = device ?? MTLCreateSystemDefaultDevice()
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        wantsLayer = true
        layer?.isOpaque = false
        framebufferOnly = true
        enableSetNeedsDisplay = true
        isPaused = true
        colorPixelFormat = .bgra8Unorm
        overlayRenderer = OverlayRenderer(metalView: self, state: state)
        delegate = overlayRenderer
        stateSubscription = state.objectWillChange.sink { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.setNeedsDisplay(self.bounds)
            }
        }
        setNeedsDisplay(bounds)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else {
            return
        }
        setNeedsDisplay(bounds)
        Task { @MainActor [weak self] in
            guard let self else { return }
            self.setNeedsDisplay(self.bounds)
        }
    }
}
