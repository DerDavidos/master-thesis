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
    private var layerDistance: Float
    
    private var dataset: QVis!
    
    init(dataset: QVis) {
        self.dataset = dataset
        
        self.depth = Int(dataset.volume.depth)
        self.height = Int(dataset.volume.height)
        self.width = Int(dataset.volume.width)
        
        self.maxValue = Float(max(depth, height, width))
        self.layerDistance = 1 / maxValue
    }

    func getTexture(id: Float, axis: String) -> TextureResource {
        let bitsPerComponent = 8
        let bitsPerPixel = 8
        let colorSpace = CGColorSpaceCreateDeviceGray()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.none.rawValue)
        let renderingIntent = CGColorRenderingIntent.defaultIntent
        
        var imageWidth: Int
        var imageHeight: Int
        
        var image: CGImage
        var imageData: Array<UInt8>
        
        let id_0 = Int(floor(id))
        let id_1 = Int(ceil(id))
        var id_0_weigth = id - Float(id_0)
        if (id_0_weigth == 0) {
            id_0_weigth = 1
        }
        let id_1_weigth = Float(id_1) - id
        switch axis {
            
        case "zPositive", "zNegative":
            imageWidth = width
            imageHeight = height
            imageData = Array()
            var j_0 = width*height*id_0
            var j_1 = width*height*id_1
            while j_0 < width*height*(id_0 + 1) {
                var columnData: Array<UInt8> = Array()
                var index0 = j_0
                var index1 = j_1
                while index0 <= (j_0 + width-1) {
                    let pixel_0 = UInt16(Float(dataset.volume.data[index0]) * id_0_weigth)
                    let pixel_1 = UInt16(Float(dataset.volume.data[index1]) * id_1_weigth)
                    columnData.append(UInt8(pixel_0 + pixel_1))
                    index0 += 1
                    index1 += 1
                }
                
                if (axis == "zPositive") {
                    columnData = columnData.reversed()
                }
                imageData.append(contentsOf: columnData)
                j_0 += width
                j_1 += width
            }
            imageData = imageData.reversed()
            
        case "xPositive", "xNegative":
            imageWidth = depth
            imageHeight = height
            imageData = Array()
            var imageColumn: Array<UInt8>
            imageColumn = Array()
            var index0 = id_0
            var index1 = id_1
            var j = 0
            while imageData.count < depth * height {
                if index0 >= dataset.volume.data.count {
                    index0 = id_0 + (width*j)
                    index1 = id_1 + (width*j)
                    j = j + 1
                    if (axis == "xNegative") {
                        imageColumn = imageColumn.reversed()
                    }
                    imageData.append(contentsOf: imageColumn)
                    imageColumn = Array()
                }
                let pixel_0 = UInt16(Float(dataset.volume.data[index0]) * id_0_weigth)
                let pixel_1 = UInt16(Float(dataset.volume.data[index1]) * id_1_weigth)
                imageColumn.append(UInt8(pixel_0 + pixel_1))
                index0 += width * height
                index1 += width * height
            }
            imageData = imageData.reversed()
        case "yPositive", "yNegative":
            imageWidth = width
            imageHeight = depth
            imageData = Array()
            var i_0 = (id_0 * width) + width * (height) * (depth - 1)
            var i_1 = (id_1 * width) + width * (height) * (depth - 1)
            if (axis == "yPositive") {
                while imageData.count < width * depth {
                    var index0 = i_0 + width - 1
                    var index1 = i_1 + width - 1
                    while index0 >= i_0 {
                        let pixel_0 = UInt16(Float(dataset.volume.data[index0]) * id_0_weigth)
                        let pixel_1 = UInt16(Float(dataset.volume.data[index1]) * id_1_weigth)
                        imageData.append(UInt8(pixel_0 + pixel_1))
                        index0 -= 1
                        index1 -= 1
                    }
                    i_0 -= width * height
                    i_1 -= width * height
                }
                imageData = imageData.reversed()
            } else {
                while imageData.count < width * depth {
                    var index0 = i_0
                    var index1 = i_1
                    while index0 <= (i_0 + width - 1) {
                        let pixel_0 = UInt16(Float(dataset.volume.data[index0]) * id_0_weigth)
                        let pixel_1 = UInt16(Float(dataset.volume.data[index1]) * id_1_weigth)
                        imageData.append(UInt8(pixel_0 + pixel_1))
                        index0 += 1
                        index1 += 1
                    }
                    i_0 -= width * height
                    i_1 -= width * height
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
        
//        if (OVERSAMPLING < 1.0) {
//            image = UIImage(cgImage: image).resize(height:CGFloat(image.height) / (1 / CGFloat(OVERSAMPLING))).cgImage!
//        }
        
        let textureResource = try! TextureResource.generate(from: image, options: TextureResource.CreateOptions(semantic: .color, mipmapsMode: .allocateAndGenerateAll))
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
            for layer in stride(from: 0.0, through: Float(layers - 3), by: 1/OVERSAMPLING) {
                let entity = Entity()
                var material: ShaderGraphMaterial? = nil
                let offset = Float(layer) * layerDistance
                var pWidth: Float = Float(layers)
                var pHeight: Float = Float(layers)
                
                let startPos = -layerDistance * Float(layers) / 2
                
                switch axis {
                case "zNegative":
                    let placeHolderZ = scene.findEntity(named: "placeHolder_Z_Negative") as! ModelEntity
                    material = placeHolderZ.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: layer, axis: axis)))
                    try? material?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , startPos  + offset)
                    entity.transform.rotation = simd_quatf(angle: .pi, axis: SIMD3<Float>(0, 1, 0))
                    pWidth = Float(width) / maxValue
                    pHeight = Float(height) / maxValue
                case "zPositive":
                    let placeHolderZ = scene.findEntity(named: "placeHolder_Z_Positive") as! ModelEntity
                    material = placeHolderZ.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: Float(layer), axis: axis)))
                    try? material?.setParameter(name: "ZLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.translation = SIMD3<Float>(0, 0 , startPos + offset)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(height) / maxValue
                case "xPositive":
                    let placeHolderX = scene.findEntity(named: "placeHolder_X_Positive") as! ModelEntity
                    material = placeHolderX.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: Float(layer), axis: axis)))
                    try? material?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(startPos + offset, 0 , 0)
                    pWidth = Float(depth) / maxValue
                    pHeight = Float(height) / maxValue
                case "xNegative":
                    let placeHolderX = scene.findEntity(named: "placeHolder_X_Negative") as! ModelEntity
                    material = placeHolderX.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: Float(layer), axis: axis)))
                    try? material?.setParameter(name: "XLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(0, 1, 0))
                    entity.transform.translation = SIMD3<Float>(startPos + offset, 0 , 0)
                    pWidth = Float(depth) / maxValue
                    pHeight = Float(height) / maxValue
                case "yPositive":
                    let placeHolderY = scene.findEntity(named: "placeHolder_Y_Positive") as! ModelEntity
                    material = placeHolderY.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: Float(layer), axis: axis)))
                    try? material?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: -.pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, startPos + offset, 0)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(depth) / maxValue
                case "yNegative":
                    let placeHolderY = scene.findEntity(named: "placeHolder_Y_Negative") as! ModelEntity
                    material = placeHolderY.model!.materials.first as? ShaderGraphMaterial
                    try? material?.setParameter(name: "Image", value: .textureResource(getTexture(id: Float(layer), axis: axis)))
                    try? material?.setParameter(name: "YLayer", value: .float(Float(layer)/Float(layers)))
                    entity.transform.rotation = simd_quatf(angle: .pi/2, axis: SIMD3<Float>(1, 0, 0))
                    entity.transform.translation = SIMD3<Float>(0, startPos + offset, 0)
                    pWidth = Float(width) / maxValue
                    pHeight = Float(depth) / maxValue
                default:
                    fatalError("Unexpected value \(axis)")}
                
                try? material?.setParameter(name: "opacityCorrection", value: .float(Float(layers) * OVERSAMPLING))
                
                let materialEntity = MaterialEntity(entity: entity, material: material!, width: pWidth, height: pHeight)
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

extension UIImage {
    /// Resizes the image by keeping the aspect ratio
    func resize(height: CGFloat) -> UIImage {
        let scale = height / self.size.height
        let width = self.size.width * scale
        let newSize = CGSize(width: width, height: height)
        
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
