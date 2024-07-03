import Foundation

struct Vec2 {
    var e: [Float]
    var x: Float { return e[0] }
    var y: Float { return e[1] }
    var r: Float { return e[0] }
    var g: Float { return e[1] }
    
    init() {
        e = [Float](repeating: 0, count: 2)
    }
    
    init(x: Float, y: Float) {
        e = [x, y]
    }
    
    init(other: Vec2) {
        e = [Float(other.x), Float(other.y)]
    }
    
    func toString() -> String {
        return "[\(e[0]), \(e[1])]"
    }
    
    static func +(lhs: Vec2, rhs: Vec2) -> Vec2 {
        return Vec2(x: lhs.e[0] + rhs.e[0], y: lhs.e[1] + rhs.e[1])
    }
    
    static func -(lhs: Vec2, rhs: Vec2) -> Vec2 {
        return Vec2(x: lhs.e[0] - rhs.e[0], y: lhs.e[1] - rhs.e[1])
    }
    
    static func *(lhs: Vec2, rhs: Vec2) -> Vec2 {
        return Vec2(x: lhs.e[0] * rhs.e[0], y: lhs.e[1] * rhs.e[1])
    }
    
    static func /(lhs: Vec2, rhs: Vec2) -> Vec2 {
        return Vec2(x: lhs.e[0] / rhs.e[0], y: lhs.e[1] / rhs.e[1])
    }
    
    static func *(lhs: Vec2, rhs: Float) -> Vec2 {
        return Vec2(x: lhs.e[0] * rhs, y: lhs.e[1] * rhs)
    }
    
    static func /(lhs: Vec2, rhs:Float) -> Vec2 {
        return Vec2(x: lhs.e[0] / rhs, y: lhs.e[1] / rhs)
    }
    
    static func +(lhs: Vec2, rhs:Float) -> Vec2 {
        return Vec2(x: lhs.e[0] + rhs, y: lhs.e[1] + rhs)
    }
    
    static func -(lhs: Vec2, rhs:Float) -> Vec2 {
        return Vec2(x: lhs.e[0] - rhs, y: lhs.e[1] - rhs)
    }
    
    static func ==(lhs: Vec2, rhs: Vec2) -> Bool {
        return lhs.e == rhs.e
    }
    
    static func !=(lhs: Vec2, rhs: Vec2) -> Bool {
        return lhs.e != rhs.e
    }
    
    func length() ->Float{
        return sqrt(sqlength())
    }
    
    func sqlength() ->Float{
        return e[0] * e[0] + e[1] * e[1]
    }
    
    static func random() -> Vec2 {
        return Vec2(x: Float.random(in: 0...1), y: Float.random(in: 0...1))
    }
    
    static func normalize(a: Vec2) -> Vec2 {
        let l = a.length()
        return l != 0 ? a / l : Vec2(x: 0, y: 0)
    }
}

struct Vec3: Equatable {
    var e: [Float]
    var x:Float{ return e[0] }
    var y:Float{ return e[1] }
    var z:Float{ return e[2] }
    var r:Float{ return e[0] }
    var g:Float{ return e[1] }
    var b:Float{ return e[2] }
    var xy: Vec2 { return Vec2(x: Float(x), y: Float(y)) }
    
    init() {
        e = [Float](repeating: 0, count: 3)
    }
    
    init(e: [Float]) {
        self.e = e
    }
    
    init(x: Float, y: Float, z:Float) {
        e = [x, y, z]
    }
    
    init(_ other: Vec3) {
        e = [other.x, other.y, other.z]
    }
    
    init(_ other: Vec2, z:Float) {
        e = [other.x, other.y, z]
    }
    
    func toString() -> String {
        return "[\(e[0]), \(e[1]), \(e[2])]"
    }
    
    static func +(lhs: Vec3, rhs: Vec3) -> Vec3 {
        return Vec3(e: [lhs.e[0] + rhs.e[0], lhs.e[1] + rhs.e[1], lhs.e[2] + rhs.e[2]])
    }
    
    static func -(lhs: Vec3, rhs: Vec3) -> Vec3 {
        return Vec3(e: [lhs.e[0] - rhs.e[0], lhs.e[1] - rhs.e[1], lhs.e[2] - rhs.e[2]])
    }
    
    static func *(lhs: Vec3, rhs: Vec3) -> Vec3 {
        return Vec3(e: [lhs.e[0] * rhs.e[0], lhs.e[1] * rhs.e[1], lhs.e[2] * rhs.e[2]])
    }
    
    static func /(lhs: Vec3, rhs: Vec3) -> Vec3 {
        return Vec3(e: [lhs.e[0] / rhs.e[0], lhs.e[1] / rhs.e[1], lhs.e[2] / rhs.e[2]])
    }
    
    static func *(lhs: Vec3, rhs:Float) -> Vec3 {
        return Vec3(e: [lhs.e[0] * rhs, lhs.e[1] * rhs, lhs.e[2] * rhs])
    }
    
    static func /(lhs: Vec3, rhs:Float) -> Vec3 {
        return Vec3(e: [lhs.e[0] / rhs, lhs.e[1] / rhs, lhs.e[2] / rhs])
    }
    
    static func +(lhs: Vec3, rhs:Float) -> Vec3 {
        return Vec3(e: [lhs.e[0] + rhs, lhs.e[1] + rhs, lhs.e[2] + rhs])
    }
    
    static func -(lhs: Vec3, rhs:Float) -> Vec3 {
        return Vec3(e: [lhs.e[0] - rhs, lhs.e[1] - rhs, lhs.e[2] - rhs])
    }
    
    static func ==(lhs: Vec3, rhs: Vec3) -> Bool {
        return lhs.e[0] == rhs.e[0] && lhs.e[1] == rhs.e[1] && lhs.e[2] == rhs.e[2]
    }
    
    static func !=(lhs: Vec3, rhs: Vec3) -> Bool {
        return lhs.e[0] != rhs.e[0] || lhs.e[1] != rhs.e[1] || lhs.e[2] != rhs.e[2]
    }
    
    func length() ->Float{
        return sqrt(sqlength())
    }
    
    func sqlength() ->Float{
        return e[0] * e[0] + e[1] * e[1] + e[2] * e[2]
    }
    
    static func dot(_ a: Vec3, _ b: Vec3) -> Float {
        return Float(a.e[0] * b.e[0] + a.e[1] * b.e[1] + a.e[2] * b.e[2])
    }
    
    static func cross(_ a: Vec3, _ b: Vec3) -> Vec3 {
        return Vec3(e: [a.e[1] * b.e[2] - a.e[2] * b.e[1],
                        a.e[2] * b.e[0] - a.e[0] * b.e[2],
                        a.e[0] * b.e[1] - a.e[1] * b.e[0]])
    }
    
    static func normalize(_ a: Vec3) -> Vec3 {
        let l = a.length()
        return l != 0.0 ? a / l : Vec3()
    }
    
    static func reflect(_ a: Vec3, _ n: Vec3) -> Vec3 {
        return a - n * dot(a, n) * 2
    }
    
    static func refract(_ a: Vec3, _ n: Vec3, _ index:Float) -> Vec3 {
        let cosTheta = min(-dot(a, n), 1)
        let rOutParallel = (a + n * cosTheta) * index
        let rOutPerpendicular = n * -sqrt(1 - min(rOutParallel.sqlength(), 1))
        return rOutParallel + rOutPerpendicular
    }
    
    static func minV(_ a: Vec3, _ b: Vec3) -> Vec3 {
        return Vec3(e: [min(a.x, b.x), min(a.y, b.y), min(a.z, b.z)])
    }
    
    static func maxV(_ a: Vec3, _ b: Vec3) -> Vec3 {
        return Vec3(e: [max(a.x, b.x), max(a.y, b.y), max(a.z, b.z)])
    }
    
    static func random() -> Vec3 {
        return Vec3(e: [Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1)])
    }
    
    static func randomPointInSphere() -> Vec3 {
        while true {
            let p = Vec3(x: Float.random(in: -1...1), y: Float.random(in: -1...1), z: Float.random(in: -1...1))
            if p.sqlength() > 1 { continue }
            return p
        }
    }
    
    static func randomPointInHemisphere() -> Vec3 {
        while true {
            let p = Vec3(x: Float.random(in: 0...1), y: Float.random(in: 0...1), z: Float.random(in: 0...1))
            if p.sqlength() > 1 { continue }
            return p
        }
    }
    
    static func randomPointInDisc() -> Vec3 {
        while true {
            let p = Vec3(x: Float.random(in: -1...1), y: Float.random(in: -1...1), z: 0)
            if p.sqlength() > 1 { continue }
            return p
        }
    }
    
    static func randomUnitVector() -> Vec3 {
        let a = Float.random(in: 0...(2 * Float.pi))
        let z = Float.random(in: -1...1)
        let r = sqrt(1 - z * z)
        return Vec3(x: r * cos(a), y: r * sin(a), z: z)
    }
}
