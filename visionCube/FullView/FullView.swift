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

class FullView {
    public let device: MTLDevice!
    
    let library: MTLLibrary!
    let commandQueue: MTLCommandQueue!
    
    var firstPipelineState: MTLRenderPipelineState!
    var secondPipelineState: MTLRenderPipelineState!
    var depthSencilState: MTLDepthStencilState!
    var texture: MTLTexture!
    var renderTargetTexture: [MTLTexture?] = Array(repeating: nil, count: 4)

    let arSession: ARKitSession
    let worldTracking: WorldTrackingProvider
    let layerRenderer: LayerRenderer
    
    var vertCount: size_t = 0
    
    var cube: Tesselation!
    
    var volumeModell: VolumeModell
    
    var volumeName: String
    
    var vertexBufferFullScreen: MTLBuffer!
    
    var vertexBuffer: MTLBuffer!
    var vertexBuffer1: MTLBuffer!
    
    var matrixBuffer: MTLBuffer!
    var parameterBuffer: MTLBuffer!
    
    var matrix: UnsafeMutablePointer<MatricesArray>!
    var param: UnsafeMutablePointer<ParamsArray>!
    
    struct Matrices {
        var modelViewProjection: simd_float4x4
        var clip: simd_float4x4
    }
    
    struct RenderParams {
        var smoothStepStart: Float
        var smoothStepShift: Float
        var oversampling: Float
        var xPos: UInt16;
        var yPos: UInt16;
        var cvScale: Float;
        var cameraPosInTextureSpace: simd_float3
        var minBounds: simd_float3
        var maxBounds: simd_float3
        var modelView: simd_float4x4
        var modelViewIT: simd_float4x4
    }
    
    fileprivate func createBuffers() {
        self.cube = Tesselation.genBrick(center: Vec3(x: 0, y: 0, z: 0), size: Vec3(x: 1, y: 1, z: 1), texScale: Vec3(x: 1, y: 1, z: 1) ).unpack()
        
        self.matrixBuffer = self.device.makeBuffer(length: MemoryLayout<Matrices>.stride * 2,
                                                   options: [MTLResourceOptions.storageModeShared])!
        self.matrix = UnsafeMutableRawPointer(matrixBuffer.contents()).bindMemory(to: MatricesArray.self, capacity: 1)
        self.parameterBuffer = self.device.makeBuffer(length: MemoryLayout<RenderParams>.stride * 2,
                                                      options: [MTLResourceOptions.storageModeShared])!
        self.param = UnsafeMutableRawPointer(parameterBuffer.contents()).bindMemory(to: ParamsArray.self, capacity: 1)
        
        let tris: [Float] = [
            3, -1, 0.0, 1,
            -1, -1, 0.0, 1,
            -1, 3, 0.0, 1
        ]
        let trisSize = tris.count * MemoryLayout<Float>.size
        self.vertexBufferFullScreen = device.makeBuffer(length: trisSize)!
        self.vertexBufferFullScreen.contents().copyMemory(from: tris, byteCount: trisSize)
    }
    
    init(_ layerRenderer: LayerRenderer, volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
        self.volumeName = volumeModell.selectedVolume
        self.layerRenderer = layerRenderer
        self.worldTracking = WorldTrackingProvider()
        self.arSession = ARKitSession()
        
        self.device = layerRenderer.device
        self.commandQueue = self.device.makeCommandQueue()!
        
        self.library = device.makeDefaultLibrary()
        self.firstPipelineState = createFirstPipelineState()
        self.secondPipelineState = createSecondPipelineState()
        self.depthSencilState = createDepthStencilState()
        
        self.texture = try! loadTexture(device: device, dataset: volumeModell.dataset)
        
        createRenderTargetTexture()
        
        createBuffers()
    }
    
    fileprivate func getTexture(_ i: Int, _ j: Int) -> (any MTLTexture)? {
        return renderTargetTexture[i]!.makeTextureView(pixelFormat: .rgba16Float, textureType: .type2D, levels: 0..<1, slices: j..<j+1)
    }
    
    func renderFrame() {
        guard let frame = layerRenderer.queryNextFrame() else { return }
        
        if (volumeName != volumeModell.selectedVolume) {
            self.texture = try! loadTexture(device: device, dataset: volumeModell.dataset)
        }
        
        frame.startUpdate()
        frame.endUpdate()

        guard let timing = frame.predictTiming() else { return }
        LayerRenderer.Clock().wait(until: timing.optimalInputTime)
        let commandBuffer = commandQueue.makeCommandBuffer()!
        guard let drawable = frame.queryDrawable() else { return }
        
        frame.startSubmission()
        
        let time = LayerRenderer.Clock.Instant.epoch.duration(to: drawable.frameTiming.presentationTime).timeInterval
        let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: time)
        drawable.deviceAnchor = deviceAnchor
        let viewports = drawable.views.map { $0.textureMap.viewport }

        updateMatrices(drawable: drawable, deviceAnchor: deviceAnchor)
        
        if (volumeModell.shaderNeedsUpdate) {
            self.firstPipelineState = createFirstPipelineState()
            self.secondPipelineState = createSecondPipelineState()
            volumeModell.shaderNeedsUpdate = false
        }
        
        /* ************************************************************************************************* */
        
        let firstRenderPassDescriptor = MTLRenderPassDescriptor()
        firstRenderPassDescriptor.colorAttachments[0].texture = self.renderTargetTexture[0]
        firstRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        firstRenderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)

        if layerRenderer.configuration.layout == .layered {
            firstRenderPassDescriptor.renderTargetArrayLength = drawable.views.count
        }
        
        if (volumeModell.selectedShader == "IsoRC" && !volumeModell.shaderNeedsUpdate) {
            for i in 1..<4 {
                firstRenderPassDescriptor.colorAttachments[i].texture = self.renderTargetTexture[i]
                firstRenderPassDescriptor.colorAttachments[i].loadAction = .clear
                firstRenderPassDescriptor.colorAttachments[i].clearColor = MTLClearColor(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.0)
            }
        }
        
        firstRenderPassDescriptor.rasterizationRateMap = drawable.rasterizationRateMaps.first
        
        let firstRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: firstRenderPassDescriptor)!
        firstRenderEncoder.setRenderPipelineState(self.firstPipelineState)
        
        firstRenderEncoder.setViewports(viewports)
        if drawable.views.count > 1 {
            var viewMappings = (0..<drawable.views.count).map {
                MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
                                                  renderTargetArrayIndexOffset: UInt32($0))
            }
            firstRenderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
        }
        
        firstRenderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, index: 0)
        firstRenderEncoder.setVertexBuffer(self.vertexBuffer1, offset: 0, index: 1)
        firstRenderEncoder.setVertexBuffer(self.matrixBuffer, offset: 0, index: 2)
        firstRenderEncoder.setFragmentTexture(self.texture, index: TextureIndex.color.rawValue)
        firstRenderEncoder.setFragmentBuffer(self.parameterBuffer, offset: 0, index: 0)
        
        firstRenderEncoder.setCullMode(.back)
        firstRenderEncoder.setFrontFacing(.counterClockwise)
        firstRenderEncoder.drawPrimitives(type: MTLPrimitiveType.triangle, vertexStart: 0, vertexCount: self.vertCount)
        firstRenderEncoder.endEncoding()
        
        /* ************************************************************************************************* */
        
        let secondRenderPassDescriptor = MTLRenderPassDescriptor()
        secondRenderPassDescriptor.colorAttachments[0].texture = drawable.colorTextures[0]
        secondRenderPassDescriptor.colorAttachments[0].loadAction = .clear
        
        secondRenderPassDescriptor.depthAttachment.texture = drawable.depthTextures[0]
        secondRenderPassDescriptor.depthAttachment.storeAction = .store
        
        if layerRenderer.configuration.layout == .layered {
            secondRenderPassDescriptor.renderTargetArrayLength = drawable.views.count
        }
        
        let secondRenderEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: secondRenderPassDescriptor)!
        secondRenderEncoder.setRenderPipelineState(self.secondPipelineState)
        secondRenderEncoder.setDepthStencilState(self.depthSencilState)
        
        secondRenderEncoder.setViewports(viewports)
        if drawable.views.count > 1 {
            var viewMappings = (0..<drawable.views.count).map {
                MTLVertexAmplificationViewMapping(viewportArrayIndexOffset: UInt32($0),
                                                  renderTargetArrayIndexOffset: UInt32($0))
            }
            secondRenderEncoder.setVertexAmplificationCount(viewports.count, viewMappings: &viewMappings)
        }
        
        secondRenderEncoder.setVertexBuffer(self.vertexBufferFullScreen, offset: 0, index: 0)
        secondRenderEncoder.setFragmentTexture(getTexture(0, 0), index: 0)
        secondRenderEncoder.setFragmentTexture(getTexture(0, 1), index: 1)
        if (volumeModell.selectedShader == "IsoRC" && !volumeModell.shaderNeedsUpdate) {
            secondRenderEncoder.setFragmentBuffer(self.parameterBuffer, offset: 0, index: 0)
            for i in 1..<4 {
                secondRenderEncoder.setFragmentTexture(getTexture(i, 0), index: i*2)
                secondRenderEncoder.setFragmentTexture(getTexture(i, 1), index: i*2+1)
            }
        }
        
        secondRenderEncoder.setCullMode(.none)
        secondRenderEncoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        secondRenderEncoder.endEncoding()
        
        /* ************************************************************************************************* */
        
        drawable.encodePresent(commandBuffer: commandBuffer)
        commandBuffer.commit()
        frame.endSubmission()
    }
    
    fileprivate func createFirstPipelineState() -> MTLRenderPipelineState {
        let firstPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        let mtlVertexDescriptor = buildMetalVertexDescriptor()
        let vertexFunction = library?.makeFunction(name: "vertexMain")
        let fragmentFunction = library?.makeFunction(name: "fragmentMain" + volumeModell.selectedShader)
        
        firstPipelineDescriptor.vertexFunction = vertexFunction
        firstPipelineDescriptor.fragmentFunction = fragmentFunction
        firstPipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
        
        firstPipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
        firstPipelineDescriptor.rasterSampleCount = 1
        firstPipelineDescriptor.isAlphaToCoverageEnabled = true
        
        firstPipelineDescriptor.colorAttachments[0].pixelFormat = .rgba16Float
        if (volumeModell.selectedShader == "IsoRC"){
            firstPipelineDescriptor.colorAttachments[1].pixelFormat = .rgba16Float
            firstPipelineDescriptor.colorAttachments[2].pixelFormat = .rgba16Float
            firstPipelineDescriptor.colorAttachments[3].pixelFormat = .rgba16Float
        } else {
            firstPipelineDescriptor.colorAttachments[1].pixelFormat = .invalid
            firstPipelineDescriptor.colorAttachments[2].pixelFormat = .invalid
            firstPipelineDescriptor.colorAttachments[3].pixelFormat = .invalid
        }
        firstPipelineDescriptor.depthAttachmentPixelFormat = .invalid
        
        return try! device.makeRenderPipelineState(descriptor: firstPipelineDescriptor)
    }
    
    fileprivate func createSecondPipelineState() -> MTLRenderPipelineState {
        let secondPipelineDescriptor = MTLRenderPipelineDescriptor()
        
        let secondvertexFunction = library?.makeFunction(name: "vertexMainBlit")
        var secondfragmentFunction: MTLFunction! = nil
        if (volumeModell.selectedShader == "IsoRC") {
            secondfragmentFunction = library?.makeFunction(name: "fragmentMainIsoSecond")
        } else {
            secondfragmentFunction = library?.makeFunction(name: "fragmentMainBlit")
        }
        
        secondPipelineDescriptor.vertexFunction = secondvertexFunction
        secondPipelineDescriptor.fragmentFunction = secondfragmentFunction
        
        secondPipelineDescriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        secondPipelineDescriptor.depthAttachmentPixelFormat = .depth32Float

        secondPipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
        secondPipelineDescriptor.isAlphaToCoverageEnabled = true
        
        return try!device.makeRenderPipelineState(descriptor: secondPipelineDescriptor)
    }
    
    fileprivate func createRenderTargetTexture() {
        let offscreenTextureDesc = MTLTextureDescriptor()
        offscreenTextureDesc.width = 1888
        offscreenTextureDesc.height = 1824
        offscreenTextureDesc.pixelFormat = .rgba16Float
        offscreenTextureDesc.textureType = .type2DArray
        offscreenTextureDesc.arrayLength = 2
        offscreenTextureDesc.usage = [.renderTarget, .shaderRead, .pixelFormatView]
        for i in 0..<4 {
            renderTargetTexture[i] = device.makeTexture(descriptor: offscreenTextureDesc)!
        }
    }
    
    fileprivate func createDepthStencilState() -> MTLDepthStencilState {
        let depthStateDescriptor = MTLDepthStencilDescriptor()
        depthStateDescriptor.isDepthWriteEnabled = false
        return device.makeDepthStencilState(descriptor: depthStateDescriptor)!
    }
    
    func updateMatrices(drawable: LayerRenderer.Drawable,  deviceAnchor: DeviceAnchor?) {
        let translate = volumeModell.transform.translation
        let scale = SIMD3<Float>(volumeModell.transform.scale.x * Float(volumeModell.dataset.volume.width), volumeModell.transform.scale.y * Float(volumeModell.dataset.volume.height), volumeModell.transform.scale.z * Float(volumeModell.dataset.volume.depth)) / Float(volumeModell.dataset.volume.maxSize)
        
        let modelMatrix = Transform(scale: scale, rotation: volumeModell.transform.rotation, translation: translate).matrix
        
        let simdDeviceAnchor = deviceAnchor?.originFromAnchorTransform ?? matrix_identity_float4x4
        
        var clipBoxSize = simd_float3(1, 1, 1)
        clipBoxSize.x = 1 - volumeModell.XClip
        clipBoxSize.y = 1 - volumeModell.YClip
        clipBoxSize.z = 1 - volumeModell.ZClip
        
        var clipBoxShift = simd_float3(0, 0, 0)
        clipBoxShift.x = volumeModell.XClip / 2
        clipBoxShift.y = volumeModell.YClip / 2
        clipBoxShift.z = volumeModell.ZClip / 2
        
        let clipBox = Transform(scale: clipBoxSize, translation: clipBoxShift).matrix
        let minBounds = clipBox * simd_float4(-0.5, -0.5, -0.5, 1.0) + 0.5
        let maxBounds = clipBox * simd_float4(0.5, 0.5, 0.5, 1.0) + 0.5
        
        func projection(forView: Int,  renderParams: inout ShaderRenderParamaters, matrix: inout shaderMatrices) {
            
            let view = drawable.views[forView]
            let viewMatrix: simd_float4x4 = (simdDeviceAnchor * view.transform).inverse
            
            let projection: simd_float4x4 = simd_float4x4(ProjectiveTransform3D(leftTangent: Double(view.tangents[0]),
                                                                                rightTangent: Double(view.tangents[1]),
                                                                                topTangent: Double(view.tangents[2]),
                                                                                bottomTangent: Double(view.tangents[3]),
                                                                                nearZ: Double(drawable.depthRange.y),
                                                                                farZ: Double(drawable.depthRange.x),
                                                                                reverseZ: true))
            
            let viewToTexture = Transform(translation: SIMD3<Float>(0.5, 0.5,0.5)).matrix * simd_inverse(viewMatrix * modelMatrix)
            
            renderParams.oversampling = volumeModell.oversampling
            renderParams.smoothStepStart = volumeModell.smoothStepStart
            renderParams.smoothStepShift = volumeModell.smoothStepShift
            renderParams.cameraPosInTextureSpace = simd_make_float3(viewToTexture * simd_float4(0, 0, 0, 1))
            renderParams.minBounds = simd_make_float3(minBounds)
            renderParams.maxBounds = simd_make_float3(maxBounds)
            renderParams.modelView = viewMatrix * modelMatrix * clipBox
            renderParams.modelViewIT = simd_transpose(simd_inverse(viewMatrix * modelMatrix * clipBox));
            
            renderParams.xPos = 1888 / 2
            renderParams.yPos = 1824 / 2
            renderParams.cvScale = 2.7
            
            matrix.clip = clipBox
            matrix.modelViewProjection = projection * viewMatrix * modelMatrix * clipBox
            
            clipCubeToNearplane(forView, viewMatrix * modelMatrix, drawable.depthRange.y)
        }
        
        projection(forView: 0, renderParams: &self.param.pointee.params.0, matrix: &self.matrix.pointee.matrices.0)
        
        if drawable.views.count > 1 {
            projection(forView: 1, renderParams: &self.param.pointee.params.1, matrix: &self.matrix.pointee.matrices.1)
        }
    }
    
    func clipCubeToNearplane(_ forView: Int, _ viewModel: simd_float4x4, _ near: Float) {
        let objectSpaceNearPlane = simd.simd_transpose(viewModel) * simd_float4(0, 0, 1.0, near + 0.01)
        
        let verts = meshPlane(
            posData: cube.vertices,
            A: objectSpaceNearPlane.x,
            B: objectSpaceNearPlane.y,
            C: objectSpaceNearPlane.z,
            D: objectSpaceNearPlane.w
        )

        let vertexDataSize = MemoryLayout<Float>.stride * verts.count
        self.vertCount = verts.count / 4
        
        if (forView == 0) {
            self.vertexBuffer = self.device.makeBuffer(length: MemoryLayout<Float>.stride * vertexDataSize,
                                                       options: [MTLResourceOptions.storageModeShared])!
            
            self.vertexBuffer.contents().copyMemory(from: verts, byteCount: vertexDataSize)
        } else {
            self.vertexBuffer1 = self.device.makeBuffer(length: MemoryLayout<Float>.stride * vertexDataSize,
                                                       options: [MTLResourceOptions.storageModeShared])!
            
            self.vertexBuffer1.contents().copyMemory(from: verts, byteCount: vertexDataSize)
        }
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
    
    func renderLoop() {
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
