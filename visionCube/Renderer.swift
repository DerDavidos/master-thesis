import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers
import Foundation
import Foundation
import ImageIO
import MobileCoreServices

func loadTexture() -> QVis{
    return try! QVis(filename: getFromResource(strFileName: "c60", ext: "dat"))
}

func getTexture(dataset: QVis, id: Int) -> TextureResource {
    let width = Int(dataset.volume.width)
    let height = Int(dataset.volume.height)
    
    let subData = Array(dataset.volume.data[(width*height*id)...(width*height*(id+1))])
    var unsafeRawPointer: UnsafeRawPointer? = nil
    
    subData.withUnsafeBytes { rawBufferPointer in
        unsafeRawPointer = rawBufferPointer.baseAddress!
    }
    
    let imageByteCount = width * height
    let bytesPerRow = width
    
    let provider = CGDataProvider(dataInfo: nil, data: unsafeRawPointer!, size: imageByteCount) { _, _, _ in}
    
    let bitsPerComponent = 8
    let bitsPerPixel = 8
    let colorSpace = CGColorSpaceCreateDeviceGray()
    let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
    
    let renderingIntent = CGColorRenderingIntent.defaultIntent
    let image = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!
    
    let textureResource = try! TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAll))
    
    return textureResource
}

@MainActor
func createEntities() async -> [Entity] {
    var entities: [Entity] = []
    if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
        if let sphere = scene.findEntity(named: "placeHolder") as? ModelEntity {
            if var sphereMaterial = sphere.model?.materials.first as? ShaderGraphMaterial {
                
                let dataset = loadTexture()
                
                for j in 0...(Int(dataset.volume.depth) - 2) {
                    print(String(Float(Float(j)/Float(dataset.volume.depth)) * 100) + "%")
                    
                    try? sphereMaterial.setParameter(name: "test", value: .textureResource(getTexture(dataset: dataset, id: j)))
                    
                    let entity = Entity()
                    entity.components.set(ModelComponent(
                        mesh: .generatePlane(width: 1, height: 1),
//                        mesh: .generateBox(width: 1, height: 1, depth: 1/64),
                        materials: [sphereMaterial]
                    ))
                    entity.transform.translation = (SIMD3<Float>(0, 0, 0 - Float(j) / 64))
                    entities.append(entity)
                }
            }
        }
    }
    return entities
}
