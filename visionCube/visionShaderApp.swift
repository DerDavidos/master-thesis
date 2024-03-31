import SwiftUI
import CompositorServices

let RESOURCE = "bonsai"

@main
struct visionShaderApp: App {
    @State private var volumeModell: VolumeModell
    @State private var axisModell: AxisModell
    
    init() {
        let volumeModell = VolumeModell()
        self.axisModell = AxisModell(volumeModell: volumeModell)
        self.volumeModell = volumeModell
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView(volumeModell: volumeModell)
        }.windowStyle(.plain)
            .defaultSize(width: 1500, height: 500)
        
        ImmersiveSpace(id: "AxisView") {
            AxisView(axisModell: axisModell)
        }.immersionStyle(selection: .constant(.mixed), in: .mixed)
        
        WindowGroup(id: "VolumeControll") {
            VolumeControll(axisModell: axisModell)
        }.windowStyle(.plain)
            .defaultSize(width: 550, height: 500)
        
        ImmersiveSpace(id: "FullView") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer, volumeModell: volumeModell)
                fullView.startRenderLoop()
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
