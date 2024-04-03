import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let START_TRANSLATION = Vector3D(x: 0, y: -1800, z: -2000)
//let START_TRANSLATION = Vector3D(x: 0, y: 0, z: 0)

@Observable
class VolumeModell {
    var step: Float = 0
    var shift: Float = 0.1
    
    var rotation: Rotation3D = .identity
    
    var XClip: Float = 0.0
    var YClip: Float = 0.0
    var ZClip: Float = 0.0
    
    var axisLoaded = false
    
    var scale: Float = 1.0
    
    var translation: Vector3D = START_TRANSLATION
    
    func reset() {
        step = 0
        shift = 0.1
        rotation = .identity
        
        scale = 1.0
        
        XClip = 0
        YClip = 0
        ZClip = 0
        
        translation = START_TRANSLATION
    }
}
