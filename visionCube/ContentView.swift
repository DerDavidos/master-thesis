import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @FocusState private var isFocused: Bool
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    let visionProPose = VisionProPositon()


    
    var body: some View {
        VStack {
            if  (!immersiveSpaceIsShown) {
                
                RealityView {content in
                    if let scene = try? await Entity(named: "c60", in: realityKitContentBundle) {
                        scene.transform.translation += SIMD3(-0.4, -0.25, 0)
                        content.add(scene)
                    }
                }
                
            }
            
                
            VStack {
                Toggle("Show ImmersiveSpace", isOn: $showImmersiveSpace)
                    .font(.extraLargeTitle)
                    .padding(36)
                    .frame(width: 700, height: 150, alignment: .center)
                    .glassBackgroundEffect()
                    .onChange(of: showImmersiveSpace) { _, newValue in
                        Task {
                            if newValue {
                                switch await openImmersiveSpace(id: "ImmersiveSpace") {
                                case .opened:
                                    immersiveSpaceIsShown = true
                                case .error, .userCancelled:
                                    fallthrough
                                @unknown default:
                                    immersiveSpaceIsShown = false
                                    showImmersiveSpace = false
                                }
                            } else if immersiveSpaceIsShown {
                                await dismissImmersiveSpace()
                                immersiveSpaceIsShown = false
                            }
                        }
                    }
            }.frame(depth: 0, alignment: .front)
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
