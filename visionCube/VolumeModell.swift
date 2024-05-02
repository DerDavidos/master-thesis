import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let START_TRANSLATION = SIMD3<Float>(x: 0, y: 1.0, z: -1.2)
//let START_TRANSLATION = SIMD3<Float>(x: 0, y: 0, z: 0)
let START_SCALE: Float = 0.7
let START_SMOOTH_STEP_START: Float = 0.1
let START_SMOOTH_STEP_SHIFT: Float = 0.5


@Observable
class VolumeModell {
    var smoothStepStart: Float = START_SMOOTH_STEP_START
    var smoothStepShift: Float = START_SMOOTH_STEP_SHIFT
    
    var rotation: Rotation3D = .identity
    
    var XClip: Float = 0.0
    var YClip: Float = 0.0
    var ZClip: Float = 0.0
    
    var axisLoaded = false
    
    var scale: Float = START_SCALE

    var lastTranslation: SIMD3<Float> = START_TRANSLATION
    
    var loading = false
    var axisView = false
    
    var dataset: QVis!
    
    var root: Entity?

    var selectedVolume = ""
    
    var lighting = false;
    var lightingNeedsUpdate = false;
    
    init() {
//        selectedVolume = listRawFiles(at: Bundle.main.resourcePath!).first!
        selectedVolume = "c60"
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
    }
    
    func reset(selectedVolume: String) {
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
        
        smoothStepStart = START_SMOOTH_STEP_START
        smoothStepShift = START_SMOOTH_STEP_SHIFT
        rotation = .identity
        
        scale = START_SCALE
        
        XClip = 0
        YClip = 0
        ZClip = 0
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
        var scale: Float = Float(value.scale.width + value.scale.height + value.scale.depth) / 3
        scale *= self.scale
        root!.scale = SIMD3<Float>(scale, scale, scale)
    }
}
