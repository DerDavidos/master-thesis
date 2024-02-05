import Foundation

struct Tesselation {
    var vertices: [Float] = []
    var normals: [Float] = []
    var tangents: [Float] = []
    var texCoords: [Float] = []
    var indices: [UInt32] = []
    
    static let PI: Float = 3.14159265358979323846
    
    static func genSphere(center: Vec3, radius: Float, sectorCount: UInt32, stackCount: UInt32) -> Tesselation {
        var tess = Tesselation()
        
        let lengthInv: Float = 1.0 / radius
        let sectorStep: Float = 2.0 * PI / Float(sectorCount)
        let stackStep: Float = PI / Float(stackCount)
        
        for i in 0...stackCount {
            let stackAngle = PI / 2.0 - Float(i) * stackStep
            let xy = radius * cosf(stackAngle)
            let z = radius * sinf(stackAngle)
            
            for j in 0...sectorCount {
                let sectorAngle = Float(j) * sectorStep
                
                let x = xy * cosf(sectorAngle)
                let y = xy * sinf(sectorAngle)
                
                tess.vertices.append(center.x + x)
                tess.vertices.append(center.y + y)
                tess.vertices.append(center.z + z)
                
                tess.normals.append(x * lengthInv)
                tess.normals.append(y * lengthInv)
                tess.normals.append(z * lengthInv)
                
                let nextSectorAngle = Float(j + 1) * sectorStep
                let nx = xy * cosf(nextSectorAngle)
                let ny = xy * sinf(nextSectorAngle)
                
                let n = Vec3(x: x * lengthInv, y: y * lengthInv, z: z * lengthInv)
                let t = Vec3.normalize(Vec3(x: nx, y: ny, z: z) - Vec3(x: x, y: y, z: z))
                let b = Vec3.cross(n, t)
                let tCorr = Vec3.cross(b, n)
                
                tess.tangents.append(tCorr.x)
                tess.tangents.append(tCorr.y)
                tess.tangents.append(tCorr.z)
                
                tess.texCoords.append(Float(j) / Float(sectorCount))
                tess.texCoords.append(1.0 - Float(i) / Float(stackCount))
            }
        }
        
        for i in 0..<stackCount {
            var k1 = i * (sectorCount + 1)
            var k2 = k1 + sectorCount + 1
            
            for _ in 0..<sectorCount {
                if i != 0 {
                    tess.indices.append(k1)
                    tess.indices.append(k2)
                    tess.indices.append(k1 + 1)
                }
                
                if i != (stackCount - 1) {
                    tess.indices.append(k1 + 1)
                    tess.indices.append(k2)
                    tess.indices.append(k2 + 1)
                }
                
                k1 += 1
                k2 += 1
            }
        }
        
        return tess
    }
    
    static func genRectangle(center: Vec3, width: Float, height: Float) -> Tesselation {
        let u = Vec3(x: width / 2.0, y: 0.0, z: 0.0)
        let v = Vec3(x: 0.0, y: height / 2.0, z: 0.0)
        return genRectangle(a: center - u - v, b: center + u - v, c: center + u + v, d: center - u + v)
    }
    
    static func genRectangle(a: Vec3, b: Vec3, c: Vec3, d: Vec3) -> Tesselation {
        var tess = Tesselation()
        
        let u = b - a
        let v = c - a
        
        tess.vertices = [
            a.x, a.y, a.z,
            b.x, b.y, b.z,
            c.x, c.y, c.z,
            d.x, d.y, d.z,
        ]
        
        let normal = Vec3.normalize(Vec3.cross(u, v))
        
        tess.normals = [
            normal.x, normal.y, normal.z,
            normal.x, normal.y, normal.z,
            normal.x, normal.y, normal.z,
            normal.x, normal.y, normal.z
        ]
        
        let tangent = Vec3.normalize(u)
        tess.tangents = [
            tangent.x, tangent.y, tangent.z,
            tangent.x, tangent.y, tangent.z,
            tangent.x, tangent.y, tangent.z,
            tangent.x, tangent.y, tangent.z
        ]
        
        tess.texCoords = [
            0.0, 0.0,
            1.0, 0.0,
            1.0, 1.0,
            0.0, 1.0
        ]
        
        tess.indices = [0, 1, 2, 0, 2, 3]
        
        return tess
    }
    
    static func genBrick(center: Vec3, size: Vec3, texScale: Vec3) -> Tesselation {
        var tess = Tesselation()
        
        let E = center - size / 2.0
        let C = center + size / 2.0
        
        let A = Vec3(x: E.x, y: E.y, z: C.z)
        let B = Vec3(x: C.x, y: E.y, z: C.z)
        let D = Vec3(x: E.x, y: C.y, z: C.z)
        let F = Vec3(x: C.x, y: E.y, z: E.z)
        let G = Vec3(x: C.x, y: C.y, z: E.z)
        let H = Vec3(x: E.x, y: C.y, z: E.z)
        
        tess.vertices = [
            // front
            A.x, A.y, A.z,
            B.x, B.y, B.z,
            C.x, C.y, C.z,
            D.x, D.y, D.z,
            
            // back
            F.x, F.y, F.z,
            E.x, E.y, E.z,
            H.x, G.y, H.z,
            
            G.x, G.y, G.z,
            
            // left
            E.x, E.y, E.z,
            A.x, A.y, A.z,
            D.x, D.y, D.z,
            H.x, H.y, H.z,
            
            // right
            B.x, B.y, B.z,
            F.x, F.y, F.z,
            G.x, G.y, G.z,
            C.x, C.y, C.z,
            
            // top
            D.x, D.y, D.z,
            C.x, C.y, C.z,
            G.x, G.y, G.z,
            H.x, H.y, H.z,
            
            // bottom
            B.x, B.y, B.z,
            A.x, A.y, A.z,
            E.x, E.y, E.z,
            F.x, F.y, F.z
        ]
        
        tess.normals = [
            // front
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            
            // back
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            
            // left
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            
            // right
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            
            // top
            0.0, 1.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 1.0, 0.0,
            0.0, 1.0, 0.0,
            
            // bottom
            0.0, -1.0, 0.0,
            0.0, -1.0, 0.0,
            0.0, -1.0, 0.0,
            0.0, -1.0, 0.0
        ]
        
        tess.tangents = [
            // front
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            
            // back
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            
            // left
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            0.0, 0.0, 1.0,
            
            // right
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            0.0, 0.0, -1.0,
            
            // top
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            1.0, 0.0, 0.0,
            
            // bottom
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0,
            -1.0, 0.0, 0.0
        ]
        
        tess.texCoords = [
            // front
            0.0, 0.0,
            texScale.x, 0.0,
            texScale.x, texScale.y,
            0.0, texScale.y,
            
            // back
            0.0, 0.0,
            texScale.x, 0.0,
            texScale.x, texScale.y,
            0.0, texScale.y,
            
            // left
            0.0, 0.0,
            texScale.z, 0.0,
            texScale.z, texScale.y,
            0.0, texScale.y,
            
            // right
            0.0, 0.0,
            texScale.z, 0.0,
            texScale.z, texScale.y,
            0.0, texScale.y,
            
            // top
            0.0, 0.0,
            texScale.x, 0.0,
            texScale.x, texScale.z,
            0.0, texScale.z,
            
            // bottom
            0.0, 0.0,
            texScale.x, 0.0,
            texScale.x, texScale.z,
            0.0, texScale.z
        ]
        
        tess.indices = [
            0, 1, 2, 0, 2, 3,
            4, 5, 6, 4, 6, 7,
            
            8, 9, 10, 8, 10, 11,
            12, 13, 14, 12, 14, 15,
            
            16, 17, 18, 16, 18, 19,
            20, 21, 22, 20, 22, 23
        ]
        
        return tess
    }
    
    static func genTorus(center: Vec3, majorRadius: Float, minorRadius: Float, majorSteps: UInt32, minorSteps: UInt32) -> Tesselation {
        var tess = Tesselation()
        
        for x in 0...majorSteps {
            let phi = (2.0 * PI * Float(x)) / Float(majorSteps)
            
            for y in 0...minorSteps {
                let theta = (2.0 * PI * Float(y)) / Float(minorSteps)
                
                let vertice = Vec3(
                    x: (majorRadius + minorRadius * cos(theta)) * cos(phi),
                    y: (majorRadius + minorRadius * cos(theta)) * sin(phi),
                    z: minorRadius * sin(theta)
                )
                
                let normal = Vec3.normalize(vertice - Vec3(x: majorRadius * cos(phi), y: majorRadius * sin(phi), z: 0))
                
                let tangent = Vec3(x: -majorRadius * sin(phi), y: majorRadius * cos(phi), z: 0)
                let texture = Vec2(
                    x: Float(x) / Float(majorSteps),
                    y: Float(y) / Float(minorSteps)
                )
                
                tess.vertices.append(vertice.x + center.x)
                tess.vertices.append(vertice.y + center.y)
                tess.vertices.append(vertice.z + center.z)
                
                tess.normals.append(normal.x)
                tess.normals.append(normal.y)
                tess.normals.append(normal.z)
                
                tess.tangents.append(tangent.x)
                tess.tangents.append(tangent.y)
                tess.tangents.append(tangent.z)
                
                tess.texCoords.append(texture.x)
                tess.texCoords.append(texture.y)
            }
        }
        
        for x in 0..<majorSteps {
            for y in 0..<minorSteps {
                // push 2 triangles per point
                tess.indices.append((x + 0) * (minorSteps + 1) + (y + 0))
                tess.indices.append((x + 1) * (minorSteps + 1) + (y + 0))
                tess.indices.append((x + 1) * (minorSteps + 1) + (y + 1))
                
                tess.indices.append((x + 0) * (minorSteps + 1) + (y + 0))
                tess.indices.append((x + 1) * (minorSteps + 1) + (y + 1))
                tess.indices.append((x + 0) * (minorSteps + 1) + (y + 1))
            }
        }
        
        return tess
    }
    
    func unpack() -> Tesselation {
        var t = Tesselation()
        
        var i: UInt32 = 0
        for index in indices {
            t.indices.append(i)
            for component in 0..<3 {
                t.vertices.append(vertices[Int(index) * 3 + component])
                t.normals.append(normals[Int(index) * 3 + component])
                t.tangents.append(tangents[Int(index) * 3 + component])
            }
            for component in 0..<2 {
                t.texCoords.append(texCoords[Int(index) * 2 + component])
            }
            i += 1
        }
        
        return t
    }
}
