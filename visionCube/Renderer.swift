import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers
import Foundation
import ImageIO
import MobileCoreServices

class SharedRenderer: ObservableObject {
    @Published var renderer: Renderer = Renderer()
}

class Renderer {
    
    private var allAxis: [[Entity]] = []
    
    func loadTexture() -> QVis{
        return try! QVis(filename: getFromResource(strFileName: "c60", ext: "dat"))
    }
    
//            let subData = dataset.volume.data.enumerated().filter { $0.offset % width == id }.map { $0.element }
    
    func getTexture(dataset: QVis, id: Int, axis: Int) -> TextureResource {
        let width = Int(dataset.volume.width)
        let height = Int(dataset.volume.height)
        let depth = Int(dataset.volume.depth)
        
        print(width)
        print(height)
        print(depth)
        
        var subData: Array<UInt8>
        switch axis {
        case 0: // z
            subData = Array(dataset.volume.data[(width*height*id)...(width*height*(id+1))])
        case 1: // x
            subData = Array()
            var i = id
            var j = 1
            while subData.count < depth * height {
                subData.append(dataset.volume.data[i])
                i = i + width * height
                if i >= dataset.volume.data.count {
                    i = id + (width * j)
                    j = j + 1
                }
            }
        default: // y
            subData = Array()
            var i = width * height * (depth - 1) + (id * width)
            while subData.count < width * depth {
                for x in i...i+width-1 {
                    subData.append(dataset.volume.data[x])
                }
                i = i - width * height
            }
        }
        
        var unsafeRawPointer: UnsafeRawPointer? = nil
        subData.withUnsafeBytes { rawBufferPointer in
            unsafeRawPointer = rawBufferPointer.baseAddress!
        }
        
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        
        var image: CGImage
        switch axis {
        case 0: // z
            let imageByteCount = width * height
            let bytesPerRow = width
            let provider = CGDataProvider(dataInfo: nil, data: unsafeRawPointer!, size: imageByteCount) { _, _, _ in}
            image = CGImage(width: width, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!
        case 1: // x
            let imageByteCount = depth * height
            let bytesPerRow = depth
            let provider = CGDataProvider(dataInfo: nil, data: unsafeRawPointer!, size: imageByteCount) { _, _, _ in}
            image = CGImage(width: depth, height: height, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!
       default: // y
            let imageByteCount = width * depth
            let bytesPerRow = width
            let provider = CGDataProvider(dataInfo: nil, data: unsafeRawPointer!, size: imageByteCount) { _, _, _ in}
            image = CGImage(width: width, height: depth, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!

        }
        
        let textureResource = try! TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAll))
        
        return textureResource
    }
    
    @MainActor
    fileprivate func createEntities() async -> [[Entity]] {
        var entitiesAxis: [[Entity]] = []
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
            
            if let sphere = scene.findEntity(named: "placeHolder") as? ModelEntity {
                if var sphereMaterial = sphere.model?.materials.first as? ShaderGraphMaterial {
                    
                    let dataset = loadTexture()
                    
                    var entities: [Entity] = []
                    var layers = Int(dataset.volume.width)
                    for layer in 0...layers - 2 {
                        print(String(Float(layer)/Float(layers) * 100) + "%")
                        
                        try? sphereMaterial.setParameter(name: "test", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: 1)))
                        
                        let entity = Entity()
                        entity.components.set(ModelComponent(
                            mesh: .generateBox(width: 0, height: 1, depth: 1),
                            materials: [sphereMaterial]
                        ))
                        entity.transform.translation = (SIMD3<Float>(-0.5 + Float(layer)/Float(layers), 0 , 0))
                        entities.append(entity)
                    }
                    entitiesAxis.append(entities)
                    
                    entities = []
                    layers = Int(dataset.volume.depth)
                    for layer in 0...layers - 2 {
                        print(String(Float(layer)/Float(layers) * 100) + "%")
                        
                        try? sphereMaterial.setParameter(name: "test", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: 0)))
                        
                        let entity = Entity()
                        entity.components.set(ModelComponent(
                            mesh: .generateBox(width: 1, height: 1, depth: 0),
                            materials: [sphereMaterial]
                        ))
                        entity.transform.translation = (SIMD3<Float>(0, 0 , -0.5 + Float(layer)/Float(layers)))
                        entities.append(entity)
                    }
                    entitiesAxis.append(entities)
                    
                    entities = []
                    layers = Int(dataset.volume.height)
                    for layer in 0...layers - 2 {
                        try? sphereMaterial.setParameter(name: "test", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: 2)))
                        
                        let entity = Entity()
                        entity.components.set(ModelComponent(
                            mesh: .generateBox(width: 1, height: 0, depth: 1),
                            materials: [sphereMaterial]
                        ))
                        entity.transform.translation = (SIMD3<Float>(0, -0.5 + Float(layer)/Float(layers), 0))
                        entities.append(entity)
                    }
                    entitiesAxis.append(entities)
                }
            }
        }
        return entitiesAxis
    }
    
    @MainActor
    func getEntities() async -> [[Entity]] {
        
        if allAxis.isEmpty {
            allAxis = await createEntities()
        }
       
        var copy: [[Entity]] = [[]]
        
        allAxis.forEach { axis in
            copy.append(axis.map { $0.copy() as! Entity })
        }
        
        return copy
    }
}

extension Entity {
    func copy(with zone: NSZone? = nil) -> Any {
        let copy = Entity()
        copy.transform = self.transform
        copy.components.set(ModelComponent(
            mesh: self.components[ModelComponent.self]!.mesh,
            materials: self.components[ModelComponent.self]!.materials
        ))
        return copy
    }
}

