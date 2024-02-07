import SwiftUI

@main
struct visionShaderApp: App {
    
    var sharedData = SharedRenderer()
    
    var body: some Scene {
    
        WindowGroup {
            ContentView().environmentObject(sharedData)
        }.windowStyle(.volumetric).defaultSize(width: 1500, height: 2000, depth: 1500)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView().environmentObject(sharedData)
        }
    }
}
