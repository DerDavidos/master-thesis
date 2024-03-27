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
    
    var rotation: Rotation3D = .identity
    
    var X: Float = 0.0
    var Y: Float = 0.0
    var Z: Float = 0.0
    
    var axisLoaded = false
    
    var scale: Float = 1.0
    
    func reset() {
        transferValue = 0
        transferValue2 = 0.1
        rotation = .identity
        
        scale = 1.0
        
        X = 0
        Y = 0
        Z = 0   
    }
}
