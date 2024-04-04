import SwiftUI
import CompositorServices

let RESOURCE = "tooth"

@main
struct visionShaderApp: App {
    @State private var volumeModell: VolumeModell
    @State private var axisModell: AxisModell
    
    @State private var visionProPose = VisionProPositon()
    
    init() {
        let volumeModell = VolumeModell()
        self.axisModell = AxisModell(volumeModell: volumeModell)
        self.volumeModell = volumeModell
    }
    
    var body: some Scene {
 
        WindowGroup {
            ContentView(volumeModell: volumeModell, visionProPose: visionProPose)
        }.windowStyle(.plain)
            .defaultSize(width: 1000, height: 500)
        
        ImmersiveSpace(id: "AxisView") {
            AxisView(axisModell: axisModell, visionProPose: visionProPose)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(id: "VolumeControll") {
            VolumeControll(axisModell: axisModell)
        }.windowStyle(.plain)
            .defaultSize(width: 550, height: 500)
        
        ImmersiveSpace(id: "FullView") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer, volumeModell: volumeModell)
                fullView.startRenderLoop()
                layerRenderer.onSpatialEvent = { eventCollection in
//                    print(eventCollection)
                }
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
