import Foundation

struct Volume {
    var width: UInt
    var height: UInt
    var depth: UInt
    var maxSize: UInt
    var scale: Vec3
    
    var data: [UInt8]
    var normals: [Vec3]
    
    init() {
        width = 0
        height = 0
        depth = 0
        maxSize = 0
        scale = Vec3()
        
        data = []
        normals = []
    }
    
    func toString() -> String {
        var result = "width: \(width)\n"
        result += "height: \(height)\n"
        result += "depth: \(depth)\n"
        result += "datasize: \(data.count)\n"
        result += "scale: \(scale)\n"
        
        for (i, value) in data.enumerated() {
            if i > 0 && i % Int(width) == 0 {
                result += "\n"
            }
            if i > 0 && i % (Int(width) * Int(height)) == 0 {
                result += "\n"
            }
            result += "\(Int(value) % 10) \(Int(value) % 10)"
        }
        
        return result
    }
    
    mutating func computeNormals() {
        return
        normals = Array(repeating: Vec3(), count: data.count)
        for w in 1..<depth-1 {
            for v in 1..<height-1 {
                for u in 1..<width-1 {
                    let index = Int(u + v * UInt(width) + w * UInt(width) * UInt(height))
                    let x = Float(data[index-1]) - Float(data[index+1])
                    let y = Float(data[index-Int(width)]) - Float(data[index+Int(width)])
                    let z = Float(data[index-Int(width)*Int(height)]) - Float(data[index+Int(width)*Int(height)])
                    let normal = Vec3(
                        x: x,
                        y: y,
                        z: z
                    )
                    normals[index] = Vec3.normalize(normal)
                }
            }
        }
    }
}
