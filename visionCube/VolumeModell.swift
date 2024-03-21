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
    
    var X: Float = 0.0
    var Y: Float = 0.0
    var Z: Float = 0.0
    
    func reset() {
        transferValue = 0
        transferValue2 = 0.1
        rotation = .zero
        
        X = 0
        Y = 0
        Z = 0   
    }
}
