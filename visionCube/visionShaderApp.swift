import SwiftUI
import CompositorServices

let START_VOLUME: String = "c60"

let START_OVERSAMPLING: Float = 1

let START_SMOOTH_STEP_START: Float = 0
let START_SMOOTH_STEP_SHIFT: Float = 0.5

let START_TRANSLATION = SIMD3<Float>(x: 0, y: 1.0, z: -1.15)
let START_SCALE = SIMD3<Float>(1 , 1, 1) * 0.3
let START_ROTATION: simd_quatf = simd_quatf(.identity)

@main
struct visionShaderApp: App {
    @State private var volumeModell: VolumeModell
    
    init() {
        self.volumeModell = VolumeModell()
    }
    
    var body: some Scene {
        WindowGroup {
            VolumeControll(volumeModell: volumeModell)
        }.windowStyle(.plain)
        
        ImmersiveSpace(id: "Axis-Aligned") {
            AxisView(volumeModell: volumeModell)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        ImmersiveSpace(id: "Ray Casting") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer, volumeModell: volumeModell)
                fullView.startRenderLoop()
                
                let fullControlls = FullControls(volumeModell: volumeModell)
                layerRenderer.onSpatialEvent = { events in
                    fullControlls.handleSpatialEvents(events)
                }
            }
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
    }
}
