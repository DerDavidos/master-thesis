import SwiftUI
import CompositorServices

@main
struct visionShaderApp: App {
    @State private var axisModell = AxisModell()
    
    var body: some Scene {
    
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric).defaultSize(width: 1500, height: 2000, depth: 1500)

        ImmersiveSpace(id: "AxisView") {
            AxisView(axisModell: axisModell)
        }
        
        WindowGroup(id: "AxisControll") {
            AxisControll(axisModell: axisModell)
        }.windowStyle(.plain)
        
        ImmersiveSpace(id: "FullView") {
            CompositorLayer(configuration: ContentStageConfiguration()) { layerRenderer in
                let fullView = FullView(layerRenderer)
                fullView.startRenderLoop()
            }
        }.immersionStyle(selection: .constant(.full), in: .full)
    }
}
