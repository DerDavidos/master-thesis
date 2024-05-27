import Foundation
import Metal
import MetalKit
import CompositorServices
import SwiftUI

func buildMetalVertexDescriptor() -> MTLVertexDescriptor {
    let mtlVertexDescriptor = MTLVertexDescriptor()
    
    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].format = MTLVertexFormat.float3
    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].offset = 0
    mtlVertexDescriptor.attributes[VertexAttribute.position.rawValue].bufferIndex = BufferIndex.meshPositions.rawValue
    
    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].format = MTLVertexFormat.float2
    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].offset = 0
    mtlVertexDescriptor.attributes[VertexAttribute.texcoord.rawValue].bufferIndex = BufferIndex.meshGenerics.rawValue
    
    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stride = 12
    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepRate = 1
    mtlVertexDescriptor.layouts[BufferIndex.meshPositions.rawValue].stepFunction = MTLVertexStepFunction.perVertex
    
    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stride = 8
    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepRate = 1
    mtlVertexDescriptor.layouts[BufferIndex.meshGenerics.rawValue].stepFunction = MTLVertexStepFunction.perVertex
    
    return mtlVertexDescriptor
}

func buildFirstRenderPipelineWithDevice(device: MTLDevice, layerRenderer: LayerRenderer, shader: String) throws -> MTLRenderPipelineState {
    let mtlVertexDescriptor = buildMetalVertexDescriptor()
    
    let library = device.makeDefaultLibrary()
    
    let vertexFunction = library?.makeFunction(name: "vertexMain")

    let fragmentFunction = library?.makeFunction(name: "fragmentMain" + shader)
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "RenderPipeline"
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
    
    pipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
    
//    pipelineDescriptor.isAlphaToCoverageEnabled = true
    pipelineDescriptor.colorAttachments[0].pixelFormat = .rgba32Float /*layerRenderer.configuration.colorFormat*/
    pipelineDescriptor.depthAttachmentPixelFormat = .invalid
    pipelineDescriptor.rasterSampleCount = 1
    
    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
}

func buildSecondRenderPipelineWithDevice(device: MTLDevice, layerRenderer: LayerRenderer) throws -> MTLRenderPipelineState {
//    let mtlVertexDescriptor = buildMetalVertexDescriptor()
    
    let library = device.makeDefaultLibrary()
    
    let vertexFunction = library?.makeFunction(name: "vertexMainBlit")

    let fragmentFunction = library?.makeFunction(name: "fragmentMainBlit")
    
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "RenderPipeline2"
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
//    pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor
    
    pipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
    
//    pipelineDescriptor.colorAttachments[
//    pipelineDescriptor.isAlphaToCoverageEnabled = true
    pipelineDescriptor.colorAttachments[0].pixelFormat = /*.bgra8Unorm_srgb*/ layerRenderer.configuration.colorFormat
    pipelineDescriptor.depthAttachmentPixelFormat = /*.depth16Unorm*/ layerRenderer.configuration.depthFormat
    
    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
}

func loadTexture(device: MTLDevice,
                 dataset: QVis) throws -> MTLTexture {
    /// Load texture data with optimal parameters for sampling
    let volumeTextureDesc = MTLTextureDescriptor()
    volumeTextureDesc.width = Int(dataset.volume.width)
    volumeTextureDesc.height = Int(dataset.volume.height)
    volumeTextureDesc.depth = Int(dataset.volume.depth)
    volumeTextureDesc.pixelFormat = .r8Unorm
    volumeTextureDesc.textureType = .type3D
    
    let texture = device.makeTexture(descriptor: volumeTextureDesc)
    
    texture!.replace(
        region: MTLRegionMake3D(0, 0, 0, Int(dataset.volume.width), Int(dataset.volume.height), Int(dataset.volume.depth)),
        mipmapLevel: 0, slice: 0,
        withBytes: dataset.volume.data,
        bytesPerRow: Int(dataset.volume.width),
        bytesPerImage: Int(dataset.volume.width) * Int(dataset.volume.height)
    )
    return texture!
}

enum RendererError: Error {
    case badVertexDescriptor
}

extension LayerRenderer.Clock.Instant.Duration {
    var timeInterval: TimeInterval {
        let nanoseconds = TimeInterval(components.attoseconds / 1_000_000_000)
        return TimeInterval(components.seconds) + (nanoseconds / TimeInterval(NSEC_PER_SEC))
    }
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


