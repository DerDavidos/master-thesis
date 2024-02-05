import Foundation

func epsilonEqual(_ a: Float, _ b: Float) -> Bool {
    return abs(a - b) <= Float.ulpOfOne
}

func rayPlaneIntersection(la: Vec3, lb: Vec3, n: Vec3, D: Float, hit: inout Vec3) -> Bool {
    let denom = Vec3.dot(n, (la - lb))
    
    if epsilonEqual(denom, 0.0) {
        return false
    }
    
    let t = (Vec3.dot(n, la) + D) / denom
    hit = la + (lb - la) * t
    return true
}

func splitTriangle(a: Vec3, b: Vec3, c: Vec3, fa: Float, fb: Float, fc: Float, normal: Vec3, D: Float, out: inout [Vec3], newVerts: inout [Vec3]) {
    // Rotation / mirroring.
    // ... (same as before)
    
    // Create mutable copies for swapping and modification.
    var mutableA = a
    var mutableB = b
    var mutableC = c
    
    var muatlbeFA = fa
    var mutableFB = fb
    var mutableFC = fc
    
    // If fa*fc is non-negative, both have the same sign -- and thus are on the
    // same side of the plane.
    if fa * fc >= 0 {
        swap(&mutableFB, &mutableFC)
        swap(&mutableB, &mutableC)
        swap(&muatlbeFA, &mutableFB)
        swap(&mutableA, &mutableB)
    } else if fb * fc >= 0 {
        swap(&muatlbeFA, &mutableFC)
        swap(&mutableA, &mutableC)
        swap(&muatlbeFA, &mutableFB)
        swap(&mutableA, &mutableB)
    }
    
    // Find the intersection points.
    var intersectionA = Vec3()
    var intersectionB = Vec3()
    if rayPlaneIntersection(la: mutableA, lb: mutableC, n: normal, D: D, hit: &intersectionA),
       rayPlaneIntersection(la: mutableB, lb: mutableC, n: normal, D: D, hit: &intersectionB) {
        print("error")
    }
    
    if fc >= 0 {
        out.append(contentsOf: [mutableA, mutableB, intersectionA, mutableB, intersectionB, intersectionA])
    } else {
        out.append(contentsOf: [intersectionA, intersectionB, mutableC])
    }
    newVerts.append(contentsOf: [intersectionA, intersectionB])
}

func rawToVec3(posData: [Float]) -> [Vec3] {
    var v = [Vec3](repeating: Vec3(), count: posData.count / 3)
    for i in 0..<posData.count / 3 {
        v[i] = Vec3(x: posData[i * 3], y: posData[i * 3 + 1], z: posData[i * 3 + 2])
    }
    return v
}

func vec3toRaw4(posData: [Vec3]) -> [Float] {
    var v = [Float](repeating: 0, count: posData.count * 4)
    for i in 0..<posData.count {
        v[i * 4] = posData[i].x
        v[i * 4 + 1] = posData[i].y
        v[i * 4 + 2] = posData[i].z
        v[i * 4 + 3] = 1
    }
    return v
}
func triPlane(posData: [Vec3], normal: Vec3, D: Float) -> ([Vec3], [Vec3]) {
    var newVertices: [Vec3] = []
    var out: [Vec3] = []
    
    if posData.count % 3 != 0 {
        return (newVertices, out)
    }
    
    for i in stride(from: 0, to: posData.count - 2, by: 3) {
        let a: Vec3 = posData[i]
        let b: Vec3 = posData[i + 1]
        let c: Vec3 = posData[i + 2]
        
        var fa: Float = Vec3.dot(normal, a) + D
        var fb: Float = Vec3.dot(normal, b) + D
        var fc: Float = Vec3.dot(normal, c) + D
        
        if abs(fa) < (2 * Float.ulpOfOne) {
            fa = 0
        }
        
        if abs(fb) < (2 * Float.ulpOfOne) {
            fb = 0
        }
        
        if abs(fc) < (2 * Float.ulpOfOne) {
            fc = 0
        }
        
        if fa >= 0 && fb >= 0 && fc >= 0 {
            continue // trivial reject
        } else if fa <= 0 && fb <= 0 && fc <= 0 {
            out.append(a)
            out.append(b)
            out.append(c)
        } else {
            var tris: [Vec3] = []
            var newVerts: [Vec3] = []
            
            splitTriangle(a: a, b: b, c: c, fa: fa, fb: fb, fc: fc, normal: normal, D: D, out: &tris, newVerts: &newVerts)
            
            out.append(contentsOf: tris)
            newVertices.append(contentsOf: newVerts)
        }
    }
    
    return (newVertices, posData)
}


struct CompSorter {
    static func compare(_ i: Vec3, _ j: Vec3) -> ComparisonResult {
        if i.x < j.x || (i.x == j.x && i.y < j.y) || (i.x == j.x && i.y == j.y && i.z < j.z) {
            return .orderedAscending
        } else {
            return .orderedDescending
        }
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

func meshPlane(posData: inout [Vec3], normal: Vec3, D: Float) {
    var (newVertices, posData) = triPlane(posData: posData, normal: normal, D: D)
    guard newVertices.count >= 3 else {
        return
    }
    
    // Remove duplicate vertices
    newVertices.sort(by: { CompSorter.compare($0, $1) == .orderedAscending })
    newVertices.removeDuplicates()
    
    // Sort counter-clockwise
    let center = newVertices.reduce(Vec3(), +) / Float(newVertices.count)
    
    let newVerticesCopy = newVertices
    
    newVertices.sort {
        angleSorter(i: $0, j: $1, center: center, refVec: Vec3.normalize(newVerticesCopy[0] - center), normal: normal)
    }
    
    // Create a triangle fan with the newly created vertices to close the polytope
    for vertexIndex in 2..<newVertices.count {
        let vertex = newVertices[vertexIndex]
        posData.append(newVertices[0])
        posData.append(newVertices[vertexIndex - 1])
        posData.append(vertex)
    }
    
}

func meshPlane(posData: [Float], A: Float, B: Float, C: Float, D: Float) -> [Float] {
    var vecPos = rawToVec3(posData: posData)
    meshPlane(posData: &vecPos, normal: Vec3(x: A, y: B, z: C), D: D)
    return vec3toRaw4(posData: vecPos)
}


extension Array where Element: Equatable {
    mutating func removeDuplicates() {
        var uniqueElements: [Element] = []
        for element in self {
            if !uniqueElements.contains(element) {
                uniqueElements.append(element)
            }
        }
        self = uniqueElements
    }
}

