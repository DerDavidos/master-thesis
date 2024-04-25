import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let START_TRANSLATION = SIMD3<Float>(x: 0, y: 1.8, z: -2)
//let START_TRANSLATION = Vector3D(x: 0, y: 0, z: 0)

@Observable
class VolumeModell {
    var smoothStepStart: Float = 0.5
    var smoothStepShift: Float = 0.5
    
    var rotation: Rotation3D = .identity
    
    var XClip: Float = 0.0
    var YClip: Float = 0.0
    var ZClip: Float = 0.0
    
    var axisLoaded = false
    
    var scale: Float = 1.0
    
    var lastTranslation: SIMD3<Float> = SIMD3<Float>(0, 1.8, -2)
    
    var loading = false
    var axisView = false
    
    var dataset: QVis!
    
    var root: Entity?

    var selectedVolume = ""
    
    init() {
        selectedVolume = listRawFiles(at: Bundle.main.resourcePath!).first!
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
    }
    
    func reset(selectedVolume: String) {
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
        
        smoothStepStart = 0.5
        smoothStepShift = 0.5
        rotation = .identity
        
        scale = 1.0
        
        XClip = 0
        YClip = 0
        ZClip = 0
        
//        updateTranslation(translation: START_TRANSLATION)
    }
    
    func updateTranslation(translation: SIMD3<Float>) {
        if root == nil {
            return
        }
        root!.transform.translation.x = Float((lastTranslation.x + translation.x))
        root!.transform.translation.y = Float((lastTranslation.y + translation.y))
        root!.transform.translation.z = Float((lastTranslation.z + translation.z))
    }
    
    func updateTransformation(_ value: AffineTransform3D!) {
        if root == nil {
            return
        }
        root!.orientation = simd_quatf(rotation.rotated(by: value.rotation!))
        
        updateTranslation(translation: makeToOtherCordinate(vector: SIMD3<Float>(value.translation.vector)))
        //        var scale: Float = Float(value.scale.width * value.scale.height * value.scale.depth)
        //        if scale > 1 { scale = (scale - 1) * 0.05 + 1 }
        //        scale *= Float(volumeModell.scale)
        //        volumeModell.root!.scale = SIMD3<Float>(scale, scale, scale)
    }
}
