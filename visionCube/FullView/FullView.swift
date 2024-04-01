import CompositorServices
import SwiftUI
import Metal
import MetalKit
import simd
import Spatial
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let maxBuffersInFlight = 10

enum RendererError: Error {
    case badVertexDescriptor
}

struct ContentStageConfiguration: CompositorLayerConfiguration {
    func makeConfiguration(capabilities: LayerRenderer.Capabilities, configuration: inout LayerRenderer.Configuration) {
        configuration.depthFormat = .depth32Float
        configuration.colorFormat = .bgra8Unorm_srgb
    
        let foveationEnabled = capabilities.supportsFoveation
        configuration.isFoveationEnabled = foveationEnabled
        
        let options: LayerRenderer.Capabilities.SupportedLayoutsOptions = foveationEnabled ? [.foveationEnabled] : []
        let supportedLayouts = capabilities.supportedLayouts(options: options)
        
        configuration.layout = supportedLayouts.contains(.layered) ? .layered : .dedicated
    }
}

extension LayerRenderer.Clock.Instant.Duration {
    var timeInterval: TimeInterval {
        let nanoseconds = TimeInterval(components.attoseconds / 1_000_000_000)
        return TimeInterval(components.seconds) + (nanoseconds / TimeInterval(NSEC_PER_SEC))
    }
}

let OVERSAMPLING: Float = 8.0

class FullView {
    public let device: MTLDevice
    let commandQueue: MTLCommandQueue

    var pipelineState: MTLRenderPipelineState
    var depthState: MTLDepthStencilState
    var texture: MTLTexture

    let inFlightSemaphore = DispatchSemaphore(value: maxBuffersInFlight)
    var rotation: Float = 0

    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider
    let layerRenderer: LayerRenderer
    
    var vertexBuffer: MTLBuffer?
    var matrixBuffer: MTLBuffer?
    var parameterBuffer: MTLBuffer?
    var vertCount: size_t = 0
    
    var smothStep: Float = 0
    var view = simd_float4x4()
    var model = simd_float4x4()
    var clipBoxSize = simd_float3(1, 1, 1)
    var clipBoxShift = simd_float3(0, 0, 0)
    
    var cube: Tesselation!
    var meshNeedsUpdate = true
   
    var volumeModell: VolumeModell
    
    struct Matrices {
        var modelViewProjection: simd_float4x4
        var clip: simd_float4x4
    }
    
    struct RenderParams {
        var smoothStepStart: Float
        var smoothStepWidth: Float
        var oversampling: Float
        var cameraPosInTextureSpace: simd_float3
        var minBounds: simd_float3
        var maxBounds: simd_float3
    }
    
    init(_ layerRenderer: LayerRenderer, volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
        
        self.layerRenderer = layerRenderer
        self.device = layerRenderer.device
        self.commandQueue = self.device.makeCommandQueue()!

        let mtlVertexDescriptor = buildMetalVertexDescriptor()

        do {
            pipelineState = try buildRenderPipelineWithDevice(device: device,
                                                                       layerRenderer: layerRenderer,
                                                                       mtlVertexDescriptor: mtlVertexDescriptor)
        } catch {
            fatalError("Unable to compile render pipeline state.  Error info: \(error)")
        }

        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.depthCompareFunction = MTLCompareFunction.greater
        depthStateDescriptor.isDepthWriteEnabled = true
        self.depthState = device.makeDepthStencilState(descriptor:depthStateDescriptor)!

        do {
            texture = try loadTexture(device: device, textureName: "ColorMap")
        } catch {
            fatalError("Unable to load texture. Error info: \(error)")
        }
        
        worldTracking = WorldTrackingProvider()
        arSession = ARKitSession()
    }
    
    func startRenderLoop() {
        Task {
            do {
                try await arSession.run([worldTracking])
            } catch {
                fatalError("Failed to initialize ARSession")
            }
            
            let renderThread = Thread {
                self.renderLoop()
            }
            renderThread.name = "Render Thread"
            renderThread.start()
        }
    }

    func buildBuffers() {
        print("buildBuffers")
        let matrixDataSize = MemoryLayout<Matrices>.stride
        let paramDataSize = MemoryLayout<RenderParams>.stride
        
        matrixBuffer = device.makeBuffer(length: matrixDataSize)
        parameterBuffer = device.makeBuffer(length: paramDataSize)
    }
    
    func updateMatrices() {
        clipBoxSize.x = 1 - volumeModell.X
        clipBoxSize.y = 1 - volumeModell.Y
        clipBoxSize.z = 1 - volumeModell.Z
        
        clipBoxShift.x = volumeModell.X / 2
        clipBoxShift.y = volumeModell.Y / 2
        clipBoxShift.z = volumeModell.Z / 2
   
        let clipBox = makeTranslate(clipBoxShift) * makeScale(clipBoxSize)
        let minBounds = clipBox * simd_float4(-0.5, -0.5, -0.5, 1.0) + 0.5
        let maxBounds = clipBox * simd_float4(0.5, 0.5, 0.5, 1.0) + 0.5
        
        view = makeLookAt(vEye: simd_float3(0, 0, 3), vAt: simd_float3(0, 0, 0), vUp: simd_float3(0, 1, 0))
        
        model =
        makeTranslate(
            simd_float3(Float(volumeModell.translation.x) / 2000, Float(volumeModell.translation.y) / -2000 - 0.9, Float(volumeModell.translation.z) / 2000 + 2.25))
        * Transform(rotation: simd_quatf(volumeModell.rotation)).matrix
        * makeScale(simd_float3(volumeModell.scale/2, volumeModell.scale/2, volumeModell.scale/2))
        
        let projection = makePerspective(fovRadians: 45.0 * Float.pi / 180.0, aspect: Float(500) / Float(500), znear: 0.03, zfar: 500.0)
        let viewToTexture = makeTranslate(simd_float3(0.5, 0.5, 0.5)) * simd_inverse(view * model)
        
        let pMatrixData = matrixBuffer!.contents().bindMemory(to: Matrices.self, capacity: 1)
        pMatrixData.pointee.clip = clipBox
        pMatrixData.pointee.modelViewProjection = projection * view * model * clipBox
        
        let paramData = parameterBuffer!.contents().bindMemory(to: RenderParams.self, capacity: 1)
        paramData.pointee.oversampling = OVERSAMPLING
        paramData.pointee.smoothStepStart = volumeModell.transferValue
        paramData.pointee.smoothStepWidth = volumeModell.transferValue2
        paramData.pointee.cameraPosInTextureSpace = simd_make_float3(viewToTexture * simd_float4(0, 0, 0, 1))
        paramData.pointee.minBounds = simd_make_float3(minBounds)
        paramData.pointee.maxBounds = simd_make_float3(maxBounds)
        
        meshNeedsUpdate = true
    }
    
    func clipCubeToNearplane() {
        if !meshNeedsUpdate {
            print("NO UPDATE")
            return
        }
        
        meshNeedsUpdate = false
        
        let objectSpaceNearPlane = simd_transpose(view * model) * simd_float4(0, 0, 1.0, 0.1 + 0.01)
        let verts = meshPlane(
            posData: cube.vertices,
            A: objectSpaceNearPlane.x,
            B: objectSpaceNearPlane.y,
            C: objectSpaceNearPlane.z,
            D: objectSpaceNearPlane.w
        )
        let vertexDataSize = MemoryLayout<Float>.stride * verts.count
        
        if vertexBuffer == nil || vertexBuffer!.length < vertexDataSize {
            vertexBuffer = device.makeBuffer(length: vertexDataSize)
        }
        
        vertexBuffer!.contents().copyMemory(from: verts, byteCount: vertexDataSize)
        vertCount = verts.count / 4
    }
    
    func renderFrame() {
        /// Per frame updates hare
        guard let frame = layerRenderer.queryNextFrame() else { return }
        
        frame.startUpdate()
        
        // Perform frame independent work
        updateMatrices()
        clipCubeToNearplane()
        
        frame.endUpdate()
        
        guard let timing = frame.predictTiming() else { return }
        LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            fatalError("Failed to create command buffer")
        }
        
        guard let drawable = frame.queryDrawable() else { return }
        
        _ = inFlightSemaphore.wait(timeout: DispatchTime.distantFuture)
        
        frame.startSubmission()
        
        let time = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime).timeInterval
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: time)
        
        drawable.deviceAnchor = deviceAnchor
        
        let semaphore = inFlightSemaphore
        commandBuffer.addCompletedHandler { (_ commandBuffer)-> Swift.Void in
            semaphore.signal()
        }
        
        let renderPassDescriptor = MTLRenderPassDescriptor()
        renderPassDescriptor.colorAttachments[0].texture = drawable.colorTextures[0]
        renderPassDescriptor.colorAttachments[0].loadAction = .clear
        renderPassDescriptor.colorAttachments[0].storeAction = .store
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 5.0, green: 0.0, blue: 0.0, alpha: 5.0)
        renderPassDescriptor.depthAttachment.texture = drawable.depthTextures[0]
        renderPassDescriptor.depthAttachment.loadAction = .clear
        renderPassDescriptor.depthAttachment.storeAction = .store
        renderPassDescriptor.depthAttachment.clearDepth = 0.0
        renderPassDescriptor.rasterizationRateMap = drawable.rasterizationRateMaps.first
        if layerRenderer.configuration.layout == .layered {
            renderPassDescriptor.renderTargetArrayLength = drawable.views.count
        }
        
        /// Final pass rendering code here
        guard let renderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor) else {
            fatalError("Failed to create render encoder")
        }
    
        renderEncoder.label = "Primary Render Encoder"
        renderEncoder.pushDebugGroup("Draw Box")
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.setRenderPipelineState(pipelineState)
        renderEncoder.setDepthStencilState(depthState)
        
        let viewports = drawable.views.map { $0.textureMap.viewport }
        renderEncoder.setViewports(viewports)
        renderEncoder.setFragmentTexture(texture, index: TextureIndex.color.rawValue)
        renderEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
        renderEncoder.setVertexBuffer(matrixBuffer, offset: 0, index: 1)
        renderEncoder.setFragmentBuffer(parameterBuffer, offset: 0, index: 0)
        renderEncoder.setCullMode(.back)
        renderEncoder.setFrontFacing(.counterClockwise)
        renderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: vertCount)
        renderEncoder.popDebugGroup()
        renderEncoder.endEncoding()
        
        drawable.encodePresent(commandBuffer: commandBuffer)
        
        commandBuffer.commit()
        
        frame.endSubmission()
    }
    
    func renderLoop() {
        buildBuffers()
        print("buffers build")
        cube = Tesselation.genBrick(center: Vec3(x: 0, y: 0, z: 0), size: Vec3(x: 1, y: 1, z: 1), texScale: Vec3(x: 1, y: 1, z: 1) ).unpack()
        while true {
            if layerRenderer.state == .invalidated {
                print("Layer is invalidated")
                return
            } else if layerRenderer.state == .paused {
                layerRenderer.waitUntilRunning()
                continue
            } else {
                autoreleasepool {
                    self.renderFrame()
                }
            }
        }
    }
}
