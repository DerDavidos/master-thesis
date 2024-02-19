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

    @State private var pitch: Float = 0.0
    @State private var yaw: Float = 0.0
    
    @State private var axisOpacity0: Double = 1.0
    @State private var axisOpacity1: Double = 1.0
    @State private var axisOpacity2: Double = 1.0
    
    var body: some View {
        VStack {
            if  (!immersiveSpaceIsShown) {
                
                RealityView { _ in
                    
                    Task {
                        await visionProPose.runArSession()
                    }
                    
                }.onAppear {
                    Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                        Task {
                            let mtx = await visionProPose.getTransform()
                            let angles = mtx!.eulerAngles
                            pitch = angles.x
                            yaw = angles.y
                            
                            axisOpacity0 = 0.0
                            axisOpacity1 = 0.0
                            axisOpacity2 = 0.0
                            
                            if (pitch <= -0.5 || pitch >= 0.5) {
                                axisOpacity2 = 1.0
                            } else if ((yaw >= -0.75 && yaw <= 0.75) ||  yaw >= 2.25 ||  yaw <= -2.25) {
                                axisOpacity0 = 1.0
                            } else {
                                axisOpacity1 = 1.0
                            }
                        }
                    }
                }
                
                
                RealityView {content in
                    let entities = await sharedRenderer.renderer.getEntities(axisNumber: 0)
                    
                    for entity in entities {
        //                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                        content.add(entity)
                    }
                }.opacity(axisOpacity0).position(CGPoint())
                RealityView {content in
                    let entities = await sharedRenderer.renderer.getEntities(axisNumber: 1)
                    
                    for entity in entities {
        //                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                        content.add(entity)
                    }
                }.opacity(axisOpacity1).padding(0).position(CGPoint())
                RealityView {content in
                    let entities = await sharedRenderer.renderer.getEntities(axisNumber: 2)
                    
                    for entity in entities {
        //                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                        content.add(entity)
                    }
                }.opacity(axisOpacity2).padding(0).position(CGPoint())
                
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
