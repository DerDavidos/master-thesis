import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let START_TRANSLATION = SIMD3<Float>(x: 0, y: 1.0, z: -1.2)
let START_SCALE = SIMD3<Float>(1 , 1, 1) * 0.5
let START_ROTATION: simd_quatf = simd_quatf(.identity)
let START_SMOOTH_STEP_START: Float = 0
let START_SMOOTH_STEP_SHIFT: Float = 0.5

let START_TRANSFORM = Transform(scale: START_SCALE, rotation: START_ROTATION, translation: START_TRANSLATION)

@Observable
class VolumeModell {
    var axisModell: AxisModell = AxisModell(loadedVolume: START_VOLUME)
    
    var smoothStepStart: Float = START_SMOOTH_STEP_START
    var smoothStepShift: Float = START_SMOOTH_STEP_SHIFT

    var XClip: Float = 0.0
    var YClip: Float = 0.0
    var ZClip: Float = 0.0
    
    var transform: Transform = START_TRANSFORM
    var lastTransform: Transform = START_TRANSFORM

    var loading = false
    var axisView = false
    var fullView = false
    
    var dataset: QVis!

    var selectedVolume = START_VOLUME
    
    var lighting = false;
    var lightingNeedsUpdate = false;
    
    init() {
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
    }

    @MainActor
    func initAxisView() async {
        if !axisModell.axisLoaded || axisModell.loadedVolume != selectedVolume {
            loading = true
            await axisModell.loadAllEntities()
            await axisModell.createEntityList(dataset: dataset, loadedVolume: selectedVolume)
            axisModell.axisLoaded = true
            loading = false
        }
    }
    
    func resetTransformation() {
        transform = START_TRANSFORM
        lastTransform = START_TRANSFORM
    }
    
    @MainActor
    func reset(selectedVolume: String) async {
        loading = true
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
        
        smoothStepStart = START_SMOOTH_STEP_START
        smoothStepShift = START_SMOOTH_STEP_SHIFT
        resetTransformation()
        
        XClip = 0
        YClip = 0
        ZClip = 0
        
        axisModell.resetClipPlanes()
        
        if axisView {
            await initAxisView()
            axisModell.root!.transform = transform
            updateAllAxis()
        }
        loading = false
    }
    
    func updateAllAxis() {
        if !axisView {
            return
        }
        Task {
            loading = true
            await axisModell.updateAllAxis(volumeModell: self)
            loading = false
        }
    }
    
    func updateTransformation(_ value: AffineTransform3D!) {
        transform.rotation = lastTransform.rotation * simd_quatf(value.rotation!)
        transform.translation = lastTransform.translation + makeToOtherCordinate(vector: SIMD3<Float>(value.translation.vector))
        let scale: Float = Float(value.scale.width + value.scale.height + value.scale.depth) / 3
        transform.scale = lastTransform.scale * scale
    }

}
