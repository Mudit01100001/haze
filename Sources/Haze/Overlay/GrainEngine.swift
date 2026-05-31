import MetalKit

final class GrainEngine {
    private let device: MTLDevice
    private var filmPipelineState: MTLComputePipelineState?
    private var chromaticPipelineState: MTLComputePipelineState?
    
    init(device: MTLDevice) {
        self.device = device
        
        guard let library = device.makeDefaultLibrary() else { return }
        
        if let filmFunction = library.makeFunction(name: "filmGrain") {
            filmPipelineState = try? device.makeComputePipelineState(function: filmFunction)
        }
        
        if let chromaFunction = library.makeFunction(name: "chromaticGrain") {
            chromaticPipelineState = try? device.makeComputePipelineState(function: chromaFunction)
        }
    }
    
    func applyGrain(inputTexture: MTLTexture, outputTexture: MTLTexture, commandBuffer: MTLCommandBuffer) {
        let store = SettingsStore.shared
        guard store.grainIntensity > 0 && store.grainSize > 0 else { return }
        
        guard let encoder = commandBuffer.makeComputeCommandEncoder() else { return }
        
        let pipelineState = filmPipelineState
        guard let state = pipelineState else {
            encoder.endEncoding()
            return
        }
        
        encoder.setComputePipelineState(state)
        encoder.setTexture(outputTexture, index: 0) // write directly to output
        
        // Use a wrapping frame counter so we don't lose precision on high uptimes.
        // Base is 24fps multiplied by grainSpeed.
        let frameCount = store.isGrainAnimated ? Float(UInt32(CACurrentMediaTime() * 24.0 * store.grainSpeed) % 10000) : 0.0
        
        var params = GrainConstants(
            intensity: Float(store.grainIntensity),
            time: frameCount,
            size: Float(store.grainSize)
        )
        
        encoder.setBytes(&params, length: MemoryLayout<GrainConstants>.stride, index: 0)
        
        let w = state.threadExecutionWidth
        let h = state.maxTotalThreadsPerThreadgroup / w
        let threadsPerThreadgroup = MTLSize(width: w, height: h, depth: 1)
        
        let threadsPerGrid = MTLSize(width: outputTexture.width, height: outputTexture.height, depth: 1)
        
        encoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        encoder.endEncoding()
    }
}

struct GrainConstants {
    var intensity: Float
    var time: Float
    var size: Float
}
