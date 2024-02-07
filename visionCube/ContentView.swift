import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    var body: some View {
        VStack {
            if  (!immersiveSpaceIsShown) {
                RealityView { content in
                    let entities = await sharedRenderer.renderer.getEntities()
                    for entity in entities {
                        entity.transform.translation += SIMD3<Float>(0, 0, 0.5)
                        content.add(entity)
                    }
                }.padding(.bottom, 500)
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
