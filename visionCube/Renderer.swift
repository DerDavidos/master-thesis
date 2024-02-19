import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers
import Foundation
import ImageIO
import MobileCoreServices

import ImageIO
import MobileCoreServices

class SharedRenderer: ObservableObject {
    @Published var renderer: Renderer = Renderer()
}

class Renderer {
    
    private var axis0: [Entity] = []
    private var axis1: [Entity] = []
    private var axis2: [Entity] = []
    
    func loadTexture() -> QVis{
        return try! QVis(filename: getFromResource(strFileName: "c60", ext: "dat"))
    }
    
//            let subData = dataset.volume.data.enumerated().filter { $0.offset % width == id }.map { $0.element }

    func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }

    
    func getTexture(dataset: QVis, id: Int, axis: Int) -> TextureResource {
        let width = Int(dataset.volume.width)
        let height = Int(dataset.volume.height)
        let depth = Int(dataset.volume.depth)
        
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
//            var i = width * height * (depth - 1) + (id * width)
            var i = id * width
            while subData.count < width * depth {
                for x in i...i+width-1 {
                    subData.append(dataset.volume.data[x])
                }
                i = i + width * height
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
        
//        let fileManager = FileManager.default
//        let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//        let resultFolderURL = directoryURL.appendingPathComponent("results")
//        if !fileManager.fileExists(atPath: resultFolderURL.path) {
//            try? fileManager.createDirectory(at: resultFolderURL, withIntermediateDirectories: true, attributes: nil)
//        }
//        let destinationURL = resultFolderURL.appendingPathComponent(String(id) + ".png")
        
        let textureResource = try! TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAll))
        
        return textureResource
    }

    @MainActor
    fileprivate func createEntities(axis: Int) async -> [Entity] {
        var entities: [Entity] = []
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
            
            if let sphere = scene.findEntity(named: "placeHolder") as? ModelEntity {
                if var sphereMaterial = sphere.model?.materials.first as? ShaderGraphMaterial {
                    
                    let dataset = loadTexture()
                    
                    
                    var layers = 0
                    switch axis {
                    case 0:
                        layers = Int(dataset.volume.depth)
                    case 1:
                        layers = Int(dataset.volume.width)
                    default:
                        layers = Int(dataset.volume.height)
                        
                    }
                    
                    for layer in 0...layers - 2 {
                        try? sphereMaterial.setParameter(name: "test", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                        
                        let entity = Entity()
                       
                        switch axis {
                        case 0:
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 1, height: 1, depth: 0),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(0, 0 , -0.5 + Float(layer)/Float(layers-2)))
                        case 1:
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 0, height: 1, depth: 1),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(-0.5 + Float(layer)/Float(layers-2), 0 , 0))
                        default:
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 1, height: 0, depth: 1),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(0, -0.5 + Float(layer)/Float(layers-2), 0))
                        }
                        
                        entities.append(entity)
                    }
                }
            }
        }
        return entities
    }
    
    @MainActor
    func getEntities(axisNumber: Int) async -> [Entity] {
        
        var axis: [Entity]
        switch axisNumber {
        case 0:
            axis = axis0
        case 1:
            axis = axis1
        default:
            axis = axis2
        }
        
        if axis.isEmpty {
            axis = await createEntities(axis: axisNumber)
        }
       
        var copy: [Entity] = []
        
        copy = axis.map { $0.copy() as! Entity }
        
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

