import SwiftUI
import CompositorServices

let OVERSAMPLING: Float = 2
let START_VOLUME: String = "c60"

@main
struct visionShaderApp: App {
    @State private var volumeModell: VolumeModell
    @State private var visionProPose = VisionProPositon()
    
    init() {
        self.volumeModell = VolumeModell()
    }
   
    @State private var tmpTranslation: SIMD3<Float> = .zero
    @State private var tmpRotation: simd_quatf = .init(.identity)

    func handleSpatialEvents(_ events: SpatialEventCollection) {
        let event = events.first!
        switch event.phase {
        case .active:
            if let pose = event.inputDevicePose {
                if tmpTranslation == .zero {
                    tmpTranslation = SIMD3<Float>(pose.pose3D.position.vector)
                    tmpRotation = simd_quatf(pose.pose3D.rotation)
                }
                
                let translate = (SIMD3<Float>(pose.pose3D.position.vector) - tmpTranslation) * 2

                volumeModell.transform.rotation = volumeModell.lastTransform.rotation * simd_quatf(pose.pose3D.rotation) * tmpRotation.inverse
                volumeModell.transform.translation = volumeModell.lastTransform.translation + translate
            }
        case .cancelled:
            print("Event cancelled")
        case .ended:
            print("Event ended normally")
            volumeModell.lastTransform.translation = volumeModell.transform.translation
            volumeModell.lastTransform.rotation = volumeModell.transform.rotation
            tmpTranslation = .zero
            tmpRotation = .init(.identity)
        default:
            break
        }
    }
    
    var body: some Scene {
        WindowGroup {
            VolumeControll(volumeModell: volumeModell, visionProPose: visionProPose)
        }.windowStyle(.plain)
        
        ImmersiveSpace(id: "AxisView") {
            AxisView(volumeModell: volumeModell, visionProPose: visionProPose)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        ImmersiveSpace(id: "FullView") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer, volumeModell: volumeModell)
                fullView.startRenderLoop()
                
                layerRenderer.onSpatialEvent = { events in
                    handleSpatialEvents(events)
                                }
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
