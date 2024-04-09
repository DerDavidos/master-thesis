import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ContentView: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow

    @State private var showAxisView = false
    @State private var showFullView = false
    @State private var immersiveSpaceIsShown = false

    var volumeModell: VolumeModell
    var visionProPose: VisionProPositon

    @MainActor
    func updateView(viewActive: Bool, viewName : String ) async {
        if volumeModell.loading {
            return
        }
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
            immersiveSpaceIsShown = false
            if !showAxisView && !showFullView {
                dismissWindow(id: "VolumeControll")
            }
        }

        volumeModell.axisView = showAxisView
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
                    Toggle("     Axis View     ", isOn: $showAxisView).font(.largeTitle)
                    Toggle("     Full View     ", isOn: $showFullView).font(.largeTitle)
                }.frame(width: 300, height: 150)
                    .opacity(volumeModell.loading ? 0.0 : 1.0)
            }
        }
        .onAppear {
            Task {
                await visionProPose.runArSession()
                await updateView(viewActive: showAxisView, viewName: "AxisView")
            }
        }
        .onDisappear {
            exit(0)
        }
    }
}
