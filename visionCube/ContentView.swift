import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView: View {
    
    @State private var showAxisView = false
    @State private var showFullView = false
    @State private var immersiveSpaceIsShown = false

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @FocusState private var isFocused: Bool
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    let visionProPose = VisionProPositon()

    var body: some View {
        VStack {
            VStack {
                Grid(alignment: .leading, verticalSpacing: 30) {
                    GridRow {
                        Toggle("Show Axis View", isOn: $showAxisView)
                            .font(.extraLargeTitle)
                            .onChange(of: showAxisView) { _, newValue in
                                Task {
                                    if newValue {
                                        if immersiveSpaceIsShown {
                                            await dismissImmersiveSpace()
                                            immersiveSpaceIsShown = false
                                            showFullView = false
                                        }
                                        switch await openImmersiveSpace(id: "AxisView") {
                                        case .opened:
                                            immersiveSpaceIsShown = true
                                        case .error, .userCancelled:
                                            fallthrough
                                        @unknown default:
                                            immersiveSpaceIsShown = false
                                            showAxisView = false
                                        }
                                    } else if immersiveSpaceIsShown {
                                        await dismissImmersiveSpace()
                                        immersiveSpaceIsShown = false
                                    }
                                }
                            }
                    }.padding(10)
                    Spacer().frame(height: 30)
                    GridRow {
                        Toggle("Show Full View", isOn: $showFullView)
                            .font(.extraLargeTitle)
                            .onChange(of: showFullView) { _, newValue in
                                Task {
                                    if newValue {
                                        if immersiveSpaceIsShown {
                                            await dismissImmersiveSpace()
                                            immersiveSpaceIsShown = false
                                            showAxisView = false
                                        }
                                        switch await openImmersiveSpace(id: "FullView") {
                                        case .opened:
                                            immersiveSpaceIsShown = true
                                        case .error, .userCancelled:
                                            fallthrough
                                        @unknown default:
                                            immersiveSpaceIsShown = false
                                            showFullView = false
                                        }
                                    } else if immersiveSpaceIsShown {
                                        await dismissImmersiveSpace()
                                        immersiveSpaceIsShown = false
                                    }
                                }
                            }
                    }.padding(10)
                }
            }.frame(alignment: .center)
            .frame(width: 800, alignment: .center)
            .padding(30)
            .glassBackgroundEffect()
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
}
