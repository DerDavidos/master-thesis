import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers
import Foundation
import ImageIO
import MobileCoreServices

import ImageIO
import MobileCoreServices

let RESOURCE = "engine"

class SharedRenderer: ObservableObject {
    @Published var renderer: Renderer = Renderer()
}

class Renderer {
    
    private var axisZPostive: [Entity] = []
    private var axisZNegative: [Entity] = []
    private var axisXPositive: [Entity] = []
    private var axisXNegative: [Entity] = []
    private var axisYPostive: [Entity] = []
    private var axisYNegative: [Entity] = []
    
    private var qVis: QVis? = nil
    
    func loadTexture() -> QVis{
        if (qVis == nil) {
            print("Loading \(RESOURCE)...")
            qVis = try! QVis(filename: getFromResource(strFileName: RESOURCE, ext: "dat"))
        }
        return qVis!
    }
    
//            let subData = dataset.volume.data.enumerated().filter { $0.offset % width == id }.map { $0.element }

//    func saveImage(image: CGImage, id: Int) {
//                let fileManager = FileManager.default
//                let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
//                let resultFolderURL = directoryURL.appendingPathComponent("results")
//                if !fileManager.fileExists(atPath: resultFolderURL.path) {
//                    try? fileManager.createDirectory(at: resultFolderURL, withIntermediateDirectories: true, attributes: nil)
//                }
//                resultFolderURL.appendingPathComponent(String(id) + ".png")
//    }
    
    func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    func getTexture(dataset: QVis, id: Int, axis: String) -> TextureResource {
        let width = Int(dataset.volume.width)
        let height = Int(dataset.volume.height)
        let depth = Int(dataset.volume.depth)
        
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        
        var imageWidth: Int
        var imageHeight: Int
        
        var image: CGImage
        var imageData: Array<UInt8>
        
        switch axis {
            
        case "zPositive":
            imageWidth = width
            imageHeight = height
            imageData = Array(dataset.volume.data[(width*height*id)...(width*height*(id+1))])
        case "zNegative":
            imageWidth = width
            imageHeight = height
            var j = width*height*id
            imageData = Array()
            while j < width*height*(id+1) {
                imageData.append(contentsOf: dataset.volume.data[(j)...(j + width-1)].reversed())
                j = j + width
            }
        case "xPositive":
            imageWidth = depth
            imageHeight = height
            imageData = Array()
            var i = id
            var j = 0
            while imageData.count < depth * height {
                if i >= dataset.volume.data.count {
                    i = id + (width*j)
                    j = j + 1
                }
                imageData.append(dataset.volume.data[i])
                i = i + width * height
            }
        case "xNegative":
            imageWidth = depth
            imageHeight = height
            imageData = Array()
            var i = id
            var j = 0
            var imageColumn: Array<UInt8>
            imageColumn = Array()
            while imageData.count < depth * height {
                
                if i >= dataset.volume.data.count {
                    i = id + (width*j)
                    j = j + 1
                    imageData.append(contentsOf: imageColumn.reversed())
                    imageColumn = Array()
                }
                imageColumn.append(dataset.volume.data[i])
                i = i + width * height
            }
        case "yPositive":
            imageWidth = width
            imageHeight = depth
            imageData = Array()
            var i = (id-height+1) * (-1) * width
            while imageData.count < width * depth {
                imageData.append(contentsOf: dataset.volume.data[i...i+width-1].reversed())
                i = i + width * height
            }
            imageData = imageData.reversed()
        case "yNegative":
            imageWidth = width
            imageHeight = depth
            imageData = Array()
            var i = (id-height+1) * (-1) * width
            while imageData.count < width * depth {
                imageData.append(contentsOf: dataset.volume.data[i...i+width-1])
                i = i + width * height
            }
        default:
            fatalError("Unexpected value \(axis)")
        }
        
        var imageRawPointer: UnsafeRawPointer? = nil
        imageData.withUnsafeBytes { rawBufferPointer in
            imageRawPointer = rawBufferPointer.baseAddress!
        }
        
        let provider = CGDataProvider(dataInfo: nil, data: imageRawPointer!, size: imageWidth*imageHeight) { _, _, _ in}
        image = CGImage(width: imageWidth, height: imageHeight, bitsPerComponent: bitsPerComponent, bitsPerPixel: bitsPerPixel, bytesPerRow: imageWidth, space: colorSpace, bitmapInfo: bitmapInfo, provider: provider!, decode: nil, shouldInterpolate: false, intent: renderingIntent)!
        
        let textureResource = try! TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAll))
        
        return textureResource
    }

    @MainActor
    fileprivate func createEntities(axis: String) async -> [Entity] {
        var entities: [Entity] = []
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
            
            if let sphere = scene.findEntity(named: "placeHolder") as? ModelEntity {
                if var sphereMaterial = sphere.model?.materials.first as? ShaderGraphMaterial {
                    
                    let dataset = loadTexture()
                         
                    var layers = 0
                    switch axis {
                    case "zPositive", "zNegative":
                        layers = Int(dataset.volume.depth)
                    case "xPositive", "xNegative":
                        layers = Int(dataset.volume.width)
                    case "yPositive", "yNegative":
                        layers = Int(dataset.volume.height)
                    default:
                        fatalError("Unexpected value \(axis)")
                        
                    }
                    print("loading \(axis)")
                    for layer in 0...layers - 2 {
                        try? sphereMaterial.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                        
                        let entity = Entity()
                       
                        switch axis {
                        case "zPositive", "zNegative":
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 1, height: 1, depth: 0),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(0, 0 , -0.5 + Float(layer)/Float(layers-2)))
                        case "xPositive", "xNegative":
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 0, height: 1, depth: 1),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(-0.5 + Float(layer)/Float(layers-2), 0 , 0))
                        case "yPositive", "yNegative":
                            entity.components.set(ModelComponent(
                                mesh: .generateBox(width: 1, height: 0, depth: 1),
                                materials: [sphereMaterial]
                            ))
                            entity.transform.translation = (SIMD3<Float>(0, -0.5 + Float(layer)/Float(layers-2), 0))
                        default:
                            fatalError("Unexpected value \(axis)")}
                        
                        entities.append(entity)
                    }
                }
            }
        }
        return entities
    }
    
    @MainActor
    func getEntities(axis: String) async -> [Entity] {
        
        var entities: [Entity]
        switch axis {
        case "zPositive":
            entities = axisZPostive
        case "zNegative":
            entities = axisZNegative
        case "xPositive":
            entities = axisXPositive
        case "xNegative":
            entities = axisXNegative
        case "yPositive":
            entities = axisYPostive
        case "yNegative":
            entities = axisYNegative
        default:
            fatalError("Unexpected value \(axis)")
        }
        
        if entities.isEmpty {
            entities = await createEntities(axis: axis)
            switch axis {
            case "zPositive":
                  axisZPostive = entities
            case "zNegative":
                 axisZNegative = entities
            case "xPositive":
                 axisXPositive = entities
            case "xNegative":
                 axisXNegative = entities
            case "yPositive":
                 axisYPostive = entities
            case "yNegative":
                 axisYNegative = entities
            default:
                fatalError("Unexpected value \(axis)")
            }
        }

        var copy: [Entity] = []
        
        copy = entities.map { $0.copy() as! Entity }
        
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

