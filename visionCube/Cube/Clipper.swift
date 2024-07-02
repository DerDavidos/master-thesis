func epsilonEqual(_ a: Float, _ b: Float) -> Bool {
    return abs(a - b) <= Float.ulpOfOne
}

func rayPlaneIntersection(la: Vec3, lb: Vec3, n: Vec3, D: Float, hit: inout Vec3) -> Bool {
    let denom = Vec3.dot(n, la - lb)
    
    if epsilonEqual(denom, 0.0) {
        return false
    }
    
    let t = (Vec3.dot(n, la) + D) / denom
    hit = la + (lb - la) * t
    return true
}

func splitTriangle(a: Vec3, b: Vec3, c: Vec3, fa: Float, fb: Float, fc: Float, normal: Vec3, D: Float, out: inout [Vec3], newVerts: inout [Vec3]) {
    var a = a, b = b, c = c
    var fa = fa, fb = fb, fc = fc
    
    if fa * fc >= 0 {
        swap(&fb, &fc)
        swap(&b, &c)
        swap(&fa, &fb)
        swap(&a, &b)
    } else if fb * fc >= 0 {
        swap(&fa, &fc)
        swap(&a, &c)
        swap(&fa, &fb)
        swap(&a, &b)
    }
    
    var A = Vec3(x: 0, y: 0, z: 0)
    var B = Vec3(x: 0, y: 0, z: 0)
    _ = rayPlaneIntersection(la: a, lb: c, n: normal, D: D, hit: &A)
    _ = rayPlaneIntersection(la: b, lb: c, n: normal, D: D, hit: &B)
    
    if fc >= 0 {
        out.append(a); out.append(b); out.append(A)
        out.append(b); out.append(B); out.append(A)
    } else {
        out.append(A); out.append(B); out.append(c)
    }
    newVerts.append(A)
    newVerts.append(B)
}

class Clipper {
    static func triPlane(posData: inout [Vec3], normal: Vec3, D: Float) -> [Vec3] {
        var newVertices = [Vec3]()
        var out = [Vec3]()
        if posData.count % 3 != 0 { return newVertices }
        
        for i in stride(from: 0, to: posData.count, by: 3) {
            let a = posData[i]
            let b = posData[i + 1]
            let c = posData[i + 2]
            
            var fa = Vec3.dot(normal, a) + D
            var fb = Vec3.dot(normal, b) + D
            var fc = Vec3.dot(normal, c) + D
            
            if abs(fa) < (2 * Float.ulpOfOne) { fa = 0 }
            if abs(fb) < (2 * Float.ulpOfOne) { fb = 0 }
            if abs(fc) < (2 * Float.ulpOfOne) { fc = 0 }
            
            if fa >= 0 && fb >= 0 && fc >= 0 {
                continue
            } else if fa <= 0 && fb <= 0 && fc <= 0 {
                out.append(a)
                out.append(b)
                out.append(c)
            } else {
                var tris = [Vec3]()
                var newVerts = [Vec3]()
                splitTriangle(a: a, b: b, c: c, fa: fa, fb: fb, fc: fc, normal: normal, D: D, out: &tris, newVerts: &newVerts)
                
                out.append(contentsOf: tris)
                newVertices.append(contentsOf: newVerts)
            }
        }
        
        posData = out
        return newVertices
    }
    
    static func meshPlane(posData: inout [Vec3], normal: Vec3, D: Float) {
        var newVertices = Clipper.triPlane(posData: &posData, normal: normal, D: D)
        
        if newVertices.count < 3 { return }
        
        newVertices.sort(by: { $0.x < $1.x || ($0.x == $1.x && $0.y < $1.y) || ($0.x == $1.x && $0.y == $1.y && $0.z < $1.z) })
        newVertices = Array(newVertices)
        
        var center = Vec3(x: 0, y: 0, z: 0)
        for vertex in newVertices {
            center = center + vertex
        }
        center = center / Float(newVertices.count)
        
        let a = newVertices[0]
        newVertices.sort(by: { angleSorter(i: $0, j: $1, center: center, refVec: Vec3.normalize(a - center), normal: normal) })
        
        for i in 2..<newVertices.count {
            posData.append(newVertices[0])
            posData.append(newVertices[i - 1])
            posData.append(newVertices[i])
        }
    }
    
    static func meshPlane(posData: [Float], A: Float, B: Float, C: Float, D: Float) -> [Float] {
        var vecPos = rawToVec3(posData: posData)
        meshPlane(posData: &vecPos, normal: Vec3(x: A, y: B, z: C), D: D)
        return vec3toRaw4(posData: vecPos)
    }
}

func angleSorter(i: Vec3, j: Vec3, center: Vec3, refVec: Vec3, normal: Vec3) -> Bool {
    let vecI = Vec3.normalize(i - center)
    let cosI = Vec3.dot(refVec, vecI)
    let sinI = Vec3.dot(Vec3.cross(vecI, refVec), normal)
    
    let vecJ = Vec3.normalize(j - center)
    let cosJ = Vec3.dot(refVec, vecJ)
    let sinJ = Vec3.dot(Vec3.cross(vecJ, refVec), normal)
    
    let acI = atan2(sinI, cosI)
    let acJ = atan2(sinJ, cosJ)
    
    return acI > acJ
}

func rawToVec3(posData: [Float]) -> [Vec3] {
    var v = [Vec3]()
    for i in stride(from: 0, to: posData.count, by: 3) {
        v.append(Vec3(x: posData[i], y: posData[i + 1], z: posData[i + 2]))
    }
    return v
}

func vec3toRaw4(posData: [Vec3]) -> [Float] {
    var v = [Float]()
    for vec in posData {
        v.append(vec.x)
        v.append(vec.y)
        v.append(vec.z)
        v.append(1)
    }
    return v
}
