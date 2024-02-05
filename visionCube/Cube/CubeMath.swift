import simd

func add(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> SIMD3<Float> {
    return SIMD3<Float>(a.x + b.x, a.y + b.y, a.z + b.z)
}

func makeIdentity() -> simd_float4x4 {
    return simd_float4x4(SIMD4<Float>(1.0, 0.0, 0.0, 0.0),
                         SIMD4<Float>(0.0, 1.0, 0.0, 0.0),
                         SIMD4<Float>(0.0, 0.0, 1.0, 0.0),
                         SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}

func makePerspective(fovRadians: Float, aspect: Float, znear: Float, zfar: Float) -> float4x4 {
    let ys = 1.0 / tanf(fovRadians * 0.5)
    let xs = ys / aspect
    let zs = zfar / (znear - zfar)
    return simd_matrix_from_rows(SIMD4<Float>(xs, 0.0, 0.0, 0.0),
                                 SIMD4<Float>(0.0, ys, 0.0, 0.0),
                                 SIMD4<Float>(0.0, 0.0, zs, znear * zs),
                                 SIMD4<Float>(0.0, 0.0, -1.0, 0.0))
}

func makeLookAt(vEye: SIMD3<Float>, vAt: SIMD3<Float>, vUp: SIMD3<Float>) -> float4x4 {
    var f = vAt - vEye
    var u = vUp
    var s = cross(f, u)
    u = cross(s, f)
    f = normalize(f)
    u = normalize(u)
    s = normalize(s)
    
    return simd_matrix_from_rows(SIMD4<Float>(s.x, s.y, s.z, -dot(s, vEye)),
                                 SIMD4<Float>(u.x, u.y, u.z, -dot(u, vEye)),
                                 SIMD4<Float>(-f.x, -f.y, -f.z, dot(f, vEye)),
                                 SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}

func makeXRotate(angleRadians: Float) -> float4x4 {
    let a = angleRadians
    return simd_matrix_from_rows(SIMD4<Float>(1.0, 0.0, 0.0, 0.0),
                                 SIMD4<Float>(0.0, cosf(a), sinf(a), 0.0),
                                 SIMD4<Float>(0.0, -sinf(a), cosf(a), 0.0),
                                 SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}

func makeYRotate(angleRadians: Float) -> float4x4 {
    let a = angleRadians
    return simd_matrix_from_rows(SIMD4<Float>(cosf(a), 0.0, sinf(a), 0.0),
                                 SIMD4<Float>(0.0, 1.0, 0.0, 0.0),
                                 SIMD4<Float>(-sinf(a), 0.0, cosf(a), 0.0),
                                 SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}

func makeZRotate(angleRadians: Float) -> float4x4 {
    let a = angleRadians
    return simd_matrix_from_rows(SIMD4<Float>(cosf(a), sinf(a), 0.0, 0.0),
                                 SIMD4<Float>(-sinf(a), cosf(a), 0.0, 0.0),
                                 SIMD4<Float>(0.0, 0.0, 1.0, 0.0),
                                 SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}

func makeTranslate(_ v: SIMD3<Float>) -> float4x4 {
    let col0 = SIMD4<Float>(1.0, 0.0, 0.0, 0.0)
    let col1 = SIMD4<Float>(0.0, 1.0, 0.0, 0.0)
    let col2 = SIMD4<Float>(0.0, 0.0, 1.0, 0.0)
    let col3 = SIMD4<Float>(v.x, v.y, v.z, 1.0)
    return float4x4(col0, col1, col2, col3)
}

func makeScale(_ v: SIMD3<Float>) -> float4x4 {
    return float4x4(SIMD4<Float>(v.x, 0.0, 0.0, 0.0),
                    SIMD4<Float>(0.0, v.y, 0.0, 0.0),
                    SIMD4<Float>(0.0, 0.0, v.z, 0.0),
                    SIMD4<Float>(0.0, 0.0, 0.0, 1.0))
}
