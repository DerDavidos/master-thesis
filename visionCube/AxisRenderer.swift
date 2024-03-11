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

struct MaterialEntity {
    var entity: Entity
    var material: ShaderGraphMaterial
}

class AxisRenderer {
    
    @State var tran: Float = 0
    
    private var axisZPostive: [MaterialEntity] = []
    private var axisZNegative: [MaterialEntity] = []
    private var axisXPositive: [MaterialEntity] = []
    private var axisXNegative: [MaterialEntity] = []
    private var axisYPostive: [MaterialEntity] = []
    private var axisYNegative: [MaterialEntity] = []
    
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
            
        case "zPositive", "zNegative":
            imageWidth = width
            imageHeight = height
            imageData = Array()
            var j = width*height*id
            while j < width*height*(id+1) {
                var columnData = Array(dataset.volume.data[(j)...(j + width-1)])
                if (axis == "zNegative") {
                    columnData = columnData.reversed()
                }
                imageData.append(contentsOf: columnData)
                j = j + width
            }
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
                i = i + width * height
            }
        case "yPositive", "yNegative":
            imageWidth = width
            imageHeight = depth
            imageData = Array()
            var i = (id-height+1) * (-1) * width
            if (axis == "yNegative") {
                while imageData.count < width * depth {
                    imageData.append(contentsOf: dataset.volume.data[i...i+width-1].reversed())
                    i = i + width * height
                }
            } else {
                while imageData.count < width * depth {
                    imageData.append(contentsOf: dataset.volume.data[i...i+width-1])
                    i = i + width * height
                }
                imageData = imageData.reversed()
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
    fileprivate func createEntities(axis: String) async -> [MaterialEntity] {
        var entities: [MaterialEntity] = []
        if let scene = try? await Entity(named: "Scene", in: realityKitContentBundle) {
                    
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
                
                let entity = Entity()

                var sphereMaterial: ShaderGraphMaterial? = nil
                
                switch axis {
                case "zNegative":
                    let sphere = scene.findEntity(named: "placeHolder_Z_Neg") as! ModelEntity
                    sphereMaterial = sphere.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , -Float(layers)/2/Float(layers) + Float(layer)/Float(layers))
                case "zPositive":
                    let sphere = scene.findEntity(named: "placeHolder_Z_Pos") as! ModelEntity
                    sphereMaterial = sphere.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , -Float(layers)/2/Float(layers) + Float(layer)/Float(layers))
                    entity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                case "xPositive":
                    let sphereX = scene.findEntity(named: "placeHolder_X_Pos") as! ModelEntity
                    sphereMaterial = sphereX.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(Float(layers)/2/Float(layers) - Float(layer)/Float(layers), 0 , 0)
                case "xNegative":
                    let sphereX = scene.findEntity(named: "placeHolder_X_Neg") as! ModelEntity
                    sphereMaterial = sphereX.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(Float(layers)/2/Float(layers) - Float(layer)/Float(layers), 0 , 0)
                case "yPositive":
                    let sphereY = scene.findEntity(named: "placeHolder_Y_Pos") as! ModelEntity
                    sphereMaterial = sphereY.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, -Float(layers)/2/Float(layers) + Float(layer)/Float(layers), 0)
                case "yNegative":
                    let sphereY = scene.findEntity(named: "placeHolder_Y_Neg") as! ModelEntity
                    sphereMaterial = sphereY.model!.materials.first as? ShaderGraphMaterial
                    try? sphereMaterial?.setParameter(name: "Image", value: .textureResource(getTexture(dataset: dataset, id: layer, axis: axis)))
                    try? sphereMaterial?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, -Float(layers)/2/Float(layers) + Float(layer)/Float(layers), 0)
                default:
                    fatalError("Unexpected value \(axis)")}
                
                let materialEntity = MaterialEntity(entity: entity, material: sphereMaterial!)
                
                entities.append(materialEntity)
            }
        }
        return entities
    }
    
    @MainActor
    func getEntities(axis: String) async -> [MaterialEntity] {
        return await createEntities(axis: axis)
    }
}
