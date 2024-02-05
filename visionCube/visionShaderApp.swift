import SwiftUI

@main
struct visionShaderApp: App {
    var body: some Scene {
        
        WindowGroup {
            ContentView()
        }.windowStyle(.volumetric).defaultSize(width: 1500, height: 2000, depth: 1500)

        ImmersiveSpace(id: "ImmersiveSpace") {
            ImmersiveView()
        }
    }
}
