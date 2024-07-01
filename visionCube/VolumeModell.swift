import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

let START_TRANSFORM: Transform = Transform(scale: START_SCALE, rotation: START_ROTATION, translation: START_TRANSLATION)

@Observable
class VolumeModell {
    var visionProPosition: VisionProPositon?
    
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
    
    var selectedShader = "Standard";
    var menuShader = "Standard";
    
    var shaderNeedsUpdate = false;
    
    var oversampling = START_OVERSAMPLING
    
    init() {
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
    }
    
    @MainActor
    func initAxisView() async {
        if axisView {
            if !axisModell.axisLoaded || axisModell.loadedVolume != selectedVolume || oversampling != axisModell.oversampling {
                axisModell.oversampling = oversampling
                print(oversampling)
                loading = true
                await axisModell.loadAllEntities()
                await axisModell.createEntityList(dataset: dataset, loadedVolume: selectedVolume)
                axisModell.axisLoaded = true
                loading = false
            }
            axisModell.root!.transform = transform
            updateAllAxis()
        }
    }
    
    func resetTransformation() {
        transform = START_TRANSFORM
        lastTransform = START_TRANSFORM
    }
    
    @MainActor
    func reset() async {
        loading = true
        dataset = try! QVis(filename: getFromResource(strFileName: selectedVolume, ext: "dat"))
        
        oversampling = START_OVERSAMPLING
        
        smoothStepStart = START_SMOOTH_STEP_START
        smoothStepShift = START_SMOOTH_STEP_SHIFT
        resetTransformation()
        
        XClip = 0
        YClip = 0
        ZClip = 0
        
        axisModell.resetClipPlanes()
        
        await initAxisView()

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
        transform.translation = lastTransform.translation + convertToMeters(vector: SIMD3<Float>(value.translation.vector))
        let scale: Float = Float(value.scale.width + value.scale.height + value.scale.depth) / 3
        transform.scale = lastTransform.scale * scale
    }
}
