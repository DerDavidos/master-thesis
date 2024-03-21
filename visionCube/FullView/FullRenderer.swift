import Foundation
import Metal
import MetalKit
import CompositorServices
import SwiftUI

//let RESOURCE = "engine"

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

func buildRenderPipelineWithDevice(device: MTLDevice, layerRenderer: LayerRenderer,
                                         mtlVertexDescriptor: MTLVertexDescriptor) throws -> MTLRenderPipelineState {
    /// Build a render state pipeline object

    let library = device.makeDefaultLibrary()

    let vertexFunction = library?.makeFunction(name: "vertexMain")
    let fragmentFunction = library?.makeFunction(name: "fragmentMain")

    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.label = "RenderPipeline"
    pipelineDescriptor.vertexFunction = vertexFunction
    pipelineDescriptor.fragmentFunction = fragmentFunction
    pipelineDescriptor.vertexDescriptor = mtlVertexDescriptor

    pipelineDescriptor.colorAttachments[0].pixelFormat = layerRenderer.configuration.colorFormat
    pipelineDescriptor.depthAttachmentPixelFormat = layerRenderer.configuration.depthFormat

    pipelineDescriptor.maxVertexAmplificationCount = layerRenderer.properties.viewCount
    
    return try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
}

func loadTexture(device: MTLDevice,
                       textureName: String) throws -> MTLTexture {
    /// Load texture data with optimal parameters for sampling
    let dataset = try QVis(filename: getFromResource(strFileName: RESOURCE, ext: "dat"))
    
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
