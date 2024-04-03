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
    
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @FocusState private var isFocused: Bool
    
    var volumeModell: VolumeModell
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    let visionProPose = VisionProPositon()

    @MainActor
    func updateView(viewActive: Bool, viewName : String ) async {
        if viewActive {
            if immersiveSpaceIsShown {
                await dismissImmersiveSpace()
            } else {
                openWindow(id: "VolumeControll")
            }
            switch await openImmersiveSpace(id: viewName) {
            case .opened:
                immersiveSpaceIsShown = true
            case .error, .userCancelled:
                fallthrough
            @unknown default:
                immersiveSpaceIsShown = false
            }
        } else {
            await dismissImmersiveSpace()
            dismissWindow(id: "VolumeControll")
            immersiveSpaceIsShown = false
        }
    }
    
    var body: some View {
        @Bindable var volumeModell = volumeModell
    
        
        RealityView { _ in }
        .onChange(of: showAxisView) { _, showAxisView in
            Task {
                if showAxisView {
                    showFullView = false
                }
                await updateView(viewActive: showAxisView, viewName: "AxisView")
            }
        }
        .onChange(of: showFullView) { _, showFullView in
            Task {
                if showFullView {
                    showAxisView = false
                }
                await updateView(viewActive: showFullView, viewName: "FullView")
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .bottomOrnament) {
                VStack (spacing: 12) {
                    Toggle("     Axis View     ", isOn: $showAxisView).font(/*@START_MENU_TOKEN@*/.title/*@END_MENU_TOKEN@*/)
                    Toggle("     Full View     ", isOn: $showFullView).font(.title)
                }.frame(width: 300, height: 150)
            }
        }
    }
}
