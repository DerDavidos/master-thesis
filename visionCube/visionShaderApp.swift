import SwiftUI
import CompositorServices

let OVERSAMPLING: Float = 1
let START_VOLUME: String = "c60"

var visionProPosition: VisionProPositon?

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
        
        ImmersiveSpace(id: "AxisView") {
            AxisView(volumeModell: volumeModell)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        ImmersiveSpace(id: "FullView") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer, volumeModell: volumeModell)
                fullView.startRenderLoop()
                
                layerRenderer.onSpatialEvent = { events in
                    fullView.handleSpatialEvents(events)
                }
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
