import SwiftUI
import RealityKit
import RealityKitContent
import UniformTypeIdentifiers
import Foundation
import ImageIO
import MobileCoreServices

import ImageIO
import MobileCoreServices

struct MaterialEntity {
    var entity: Entity
    var material: ShaderGraphMaterial
    var width: Float
    var height: Float
}

class AxisRenderer {
    private var depth: Int
    private var height: Int
    private var width: Int
    
    private var maxValue: Float
    private var abstand: Float
    
    private var dataset: QVis!
    
    init(dataset: QVis) {
        self.dataset = dataset
        
        self.depth = Int(dataset.volume.depth)
        self.height = Int(dataset.volume.height)
        self.width = Int(dataset.volume.width)
        
        self.maxValue = Float(max(depth, height, width))
        self.abstand = 1/maxValue
    }

    func getTexture(id: Int, axis: String) -> TextureResource {
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
            
        case "zPositive", "zNegative":
            imageWidth = width
            imageHeight = height
            imageData = Array()
            var j = width*height*id
            while j < width*height*(id+1) {
                var columnData = Array(dataset.volume.data[(j)...(j + width-1)])
                
                if (axis == "zPositive") {
                    columnData = columnData.reversed()
                }
                imageData.append(contentsOf: columnData)
                j += width
            }
            imageData = imageData.reversed()

        case "xPositive", "xNegative":
            imageWidth = depth
            imageHeight = height
            imageData = Array()
            var imageColumn: Array<UInt8>
            imageColumn = Array()
            var i = id
            var j = 0
            while imageData.count < depth * height {
                if i >= dataset.volume.data.count {
                    i = id + (width*j)
                    j = j + 1
                    if (axis == "xNegative") {
                        imageColumn = imageColumn.reversed()
                    }
                    imageData.append(contentsOf: imageColumn)
                    imageColumn = Array()
                }
                imageColumn.append(dataset.volume.data[i])
                i += width * height
            }
            imageData = imageData.reversed()
        case "yPositive", "yNegative":
            imageWidth = width
            imageHeight = depth
            imageData = Array()
            var i = (id * width) + width * (height) * (depth - 1)
            if (axis == "yPositive") {
                while imageData.count < width * depth {
                    imageData.append(contentsOf: dataset.volume.data[i...i+width-1].reversed())
                    i -= width * height
                }
                imageData = imageData.reversed()
            } else {
                while imageData.count < width * depth {
                    imageData.append(contentsOf: dataset.volume.data[i...i+width-1])
                    i -= width * height
                }
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
     func createEntities(axis: String) async -> [MaterialEntity] {
        var entities: [MaterialEntity] = []
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                 
            var layers = 0
            switch axis {
            case "zPositive", "zNegative":
                layers = depth
            case "xPositive", "xNegative":
                layers = width
            case "yPositive", "yNegative":
                layers = height
            default:
                fatalError("Unexpected value \(axis)")
            }
           
            print("loading \(axis)")
            for layer in 0...layers - 2 {
                let entity = Entity()
                var sphereMaterial: ShaderGraphMaterial? = nil
                let offset = Float(layer) * abstand
                var pWidth: Float = Float(layers)
                var pHeight: Float = Float(layers)
                
                let startPos = -abstand * Float(layers) / 2
                
                switch axis {
                case "zNegative":
                    let sphere = scene.findEntity(named: "placeHolder_Z_Negative") as! ModelEntity
                    sphereMaterial = sphere.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , startPos  + offset)
                    entity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                    pWidth = Float(width) / maxValue
                    pHeight = Float(height) / maxValue
                case "zPositive":
                    let sphere = scene.findEntity(named: "placeHolder_Z_Positive") as! ModelEntity
                    sphereMaterial = sphere.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , startPos + offset)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(height) / maxValue
                case "xPositive":
                    let sphereX = scene.findEntity(named: "placeHolder_X_Positive") as! ModelEntity
                    sphereMaterial = sphereX.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(startPos + offset, 0 , 0)
                    pWidth = Float(depth) / maxValue
                    pHeight = Float(height) / maxValue
                case "xNegative":
                    let sphereX = scene.findEntity(named: "placeHolder_X_Negative") as! ModelEntity
                    sphereMaterial = sphereX.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(startPos + offset, 0 , 0)
                    pWidth = Float(depth) / maxValue
                    pHeight = Float(height) / maxValue
                case "yPositive":
                    let sphereY = scene.findEntity(named: "placeHolder_Y_Positive") as! ModelEntity
                    sphereMaterial = sphereY.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, startPos + offset, 0)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(depth) / maxValue
                case "yNegative":
                    let sphereY = scene.findEntity(named: "placeHolder_Y_Negative") as! ModelEntity
                    sphereMaterial = sphereY.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, startPos + offset, 0)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(depth) / maxValue
                default:
                    fatalError("Unexpected value \(axis)")}
                
                let materialEntity = MaterialEntity(entity: entity, material: sphereMaterial!, width: pWidth, height: pHeight)
                entities.append(materialEntity)
            }
        }
        return entities
    }
    
    func writeCGImage(_ image: CGImage, to destinationURL: URL) -> Bool {
        guard let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else { return false }
        CGImageDestinationAddImage(destination, image, nil)
        return CGImageDestinationFinalize(destination)
    }
    
    func saveImage(image: CGImage, id: Int) {
        let fileManager = FileManager.default
        let directoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        var resultFolderURL = directoryURL.appendingPathComponent("results")
        if !fileManager.fileExists(atPath: resultFolderURL.path) {
            try? fileManager.createDirectory(at: resultFolderURL, withIntermediateDirectories: true, attributes: nil)
        }
        resultFolderURL = resultFolderURL.appendingPathComponent(String(id) + ".png")
        var _ = writeCGImage(image, to: resultFolderURL)
        print(resultFolderURL)
    }
}


