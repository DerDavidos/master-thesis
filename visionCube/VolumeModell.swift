import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

@Observable
class VolumeModell {
    var transferValue: Float = 0
    var transferValue2: Float = 0.1
    
    var rotation: Angle = .zero
    var orientation: simd_float4x4 = simd_float4x4()
    
}
