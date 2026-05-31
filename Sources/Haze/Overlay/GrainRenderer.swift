import AppKit
import MetalKit

@MainActor
final class GrainRenderer: NSObject, MTKViewDelegate {
    
    let metalView: MTKView
    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private let grainEngine: GrainEngine
    
    init?(frame: CGRect) {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            return nil
        }
        
        self.device = device
        self.commandQueue = commandQueue
        self.grainEngine = GrainEngine(device: device)
        
        self.metalView = MTKView(frame: frame, device: device)
        super.init()
        
        self.metalView.delegate = self
        self.metalView.framebufferOnly = false
        self.metalView.layer?.isOpaque = false
        self.metalView.clearColor = MTLClearColorMake(0.5, 0.5, 0.5, 0) // Neutral gray for perfect overlay blend
        self.metalView.preferredFramesPerSecond = 24 // Cinematic frame rate
        
        // We use standard alpha blending. The shader will output pure black pixels with random alpha.
        // This creates a rich "soot" grain that never washes out the image or blows out highlights.
        self.metalView.layer?.compositingFilter = nil
    }
    
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    
    func draw(in view: MTKView) {
        let store = SettingsStore.shared
        guard store.grainIntensity > 0 && store.grainSize > 0 else {
            // No grain needed, clear to transparent
            if let drawable = view.currentDrawable,
               let commandBuffer = commandQueue.makeCommandBuffer(),
               let passDescriptor = view.currentRenderPassDescriptor,
               let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
                encoder.endEncoding()
                commandBuffer.present(drawable)
                commandBuffer.commit()
            }
            return
        }
        
        guard let drawable = view.currentDrawable,
              let commandBuffer = commandQueue.makeCommandBuffer() else { return }
        
        // If we want to clear before compute shader (not strictly necessary since we overwrite, but good practice)
        if let passDescriptor = view.currentRenderPassDescriptor,
           let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: passDescriptor) {
            encoder.endEncoding()
        }
        
        grainEngine.applyGrain(inputTexture: drawable.texture, outputTexture: drawable.texture, commandBuffer: commandBuffer)
        
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }
}
