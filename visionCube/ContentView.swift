import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    @State private var showImmersiveSpace = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack {
//            ARView.
            
            if  (!immersiveSpaceIsShown) {
                RealityView { content in
                    let allAxis = await sharedRenderer.renderer.getEntities()
                    allAxis.forEach { oneAxis in
                        for entity in oneAxis {
                            entity.transform.translation += SIMD3<Float>(0, 0, 0)
                            content.add(entity)
                        }
                    }
                    
                }.padding(.bottom, 500)
                .opacity(isFocused ? 1.0 : 0.0)
                .focused($isFocused)
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
