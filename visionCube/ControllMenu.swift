import Foundation
import RealityKit
import SwiftUI

func listRawFiles(at directoryPath: String) -> [String] {
    do {
        let fileManager = FileManager.default
        let items = try fileManager.contentsOfDirectory(atPath: directoryPath)
        
        var rawFiles: [String] = []
        for item in items {
            if item.hasSuffix(".raw") {
                rawFiles.append(item.split(separator: ".").first!.description)
            }
        }
        return rawFiles
    } catch {
        print("Error getting directory contents: \(error)")
        return []
    }
}

struct VolumeControll: View {
    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace
    
    @Environment(\.openWindow) var openWindow
    @Environment(\.dismissWindow) var dismissWindow
    
    @State private var immersiveSpaceIsShown = false
    
    var axisModell: AxisModell? = nil
    var volumeModell: VolumeModell
    
    @MainActor
    fileprivate func dismissSpaceIfShown() async {
        if (immersiveSpaceIsShown) {
            volumeModell.visionProPosition!.stopArSession()
            await dismissImmersiveSpace()
            immersiveSpaceIsShown = false
        }
    }
    
    @MainActor
    fileprivate func openSpace(_ viewName: String) async {
        switch await openImmersiveSpace(id: viewName) {
        case .opened:
            volumeModell.visionProPosition = VisionProPositon()
            await volumeModell.visionProPosition!.runArSession()
            immersiveSpaceIsShown = true
        case .error, .userCancelled:
            fallthrough
        @unknown default:
            immersiveSpaceIsShown = false
        }
    }
    
    @MainActor
    func updateView(viewActive: Bool, viewName : String ) async {
        if volumeModell.loading {
            return
        }
        if viewActive {
            await dismissSpaceIfShown()
            await openSpace(viewName)
            volumeModell.resetTransformation()
        } else {
            await dismissSpaceIfShown()
        }
    }
    
    var body: some View {
        @Bindable var volumeModell = volumeModell
        @Bindable var axisModell = volumeModell.axisModell
        
        VStack {
            Grid(verticalSpacing: 15) {
                VStack (spacing: 10) {
                    Toggle("Axis View", isOn: $volumeModell.axisView).font(.largeTitle)
                    Toggle("Full View", isOn: $volumeModell.fullView).font(.largeTitle)
                }
                .opacity(volumeModell.loading ? 0.0 : 1.0)
                .onChange(of: volumeModell.axisView) { _, showAxisView in
                    Task {
                        if volumeModell.axisView {
                            volumeModell.fullView = false
                        }
                        await updateView(viewActive: showAxisView, viewName: "AxisView")
                    }
                }
                .onChange(of: volumeModell.fullView) { _, showFullView in
                    Task {
                        if volumeModell.fullView {
                            volumeModell.axisView = false
                        }
                        await updateView(viewActive: showFullView, viewName: "FullView")
                    }
                }.frame(width: 400)
                
                Spacer()
                GridRow {
                    Text(volumeModell.selectedShader.contains("ISO") ? "ISO:" : "Start:").font(.title)
                    Slider(value: $volumeModell.smoothStepStart, in: 0...1) { editing in
                        if (!editing) {
                            volumeModell.updateAllAxis()
                        }
                    }.opacity(volumeModell.loading ? 0.0 : 1.0)
                }
                GridRow {
                    Text("Shift:").font(.title)
                    Slider(value: $volumeModell.smoothStepShift, in: 0...1) { editing in
                        if (!editing) {
                            volumeModell.updateAllAxis()
                        }
                    }.opacity(volumeModell.loading ? 0.0 : 1.0)
                }.opacity(volumeModell.selectedShader.contains("ISO") ? 0.0 : 1.0)
                GridRow {
                    Text("Oversampling:").font(.title2)
                    TextField(
                        "Oversampling", value: $volumeModell.oversampling, format: .number
                    ).onSubmit {
                        Task {
                            await volumeModell.initAxisView()
                        }
                    }.keyboardType(.numbersAndPunctuation)
                        .font(.title)
                        .frame(alignment: .trailing)
                }.opacity(volumeModell.loading ? 0.0 : 1.0)
                    .frame(width: 180)
                
                GridRow {
                    Toggle("X Clip", isOn: $axisModell.clipBoxX.isEnabled)
                        .font(.title)
                    Toggle("Y Clip", isOn: $axisModell.clipBoxY.isEnabled)
                        .font(.title)
                    Toggle("Z Clip", isOn: $axisModell.clipBoxZ.isEnabled)
                        .font(.title)
                }.padding(10).opacity(volumeModell.fullView ? 0.0 : 1.0)
                
                Form {
                    Section {
                        Picker("Shader", selection: $volumeModell.menuShader) {
                            
                            ForEach(["Standard", "Lighting", "ISO", "ISOLighting", "ClearView"], id: \.self) {
                                Text($0)
                            }
                        }.onChange(of: volumeModell.menuShader) {
                            volumeModell.shaderNeedsUpdate = true
                            volumeModell.selectedShader = volumeModell.menuShader
                        }
                        .font(.title)
                    }.opacity(volumeModell.loading ? 0.0 : 1.0)
                }.padding(10).opacity(volumeModell.axisView ? 0.0 : 1.0)
                
                Form {
                    Section {
                        Picker("Volume", selection: $volumeModell.selectedVolume) {
                            ForEach(listRawFiles(at: Bundle.main.resourcePath!), id: \.self) {
                                Text($0)
                            }
                        }.onChange(of: volumeModell.selectedVolume) {
                            Task {
                                await volumeModell.reset()
                            }
                        }
                        .font(.title)
                    }.opacity(volumeModell.loading ? 0.0 : 1.0)
                }.padding(10)
                
                Button(action: {
                    Task {
                        await volumeModell.reset()
                    }
                }, label: {
                    Text("Reset").font(.title)
                })
                
            }.frame(alignment: .center)
                .frame(width: 500, height: 550)
                .padding(40)
                .glassBackgroundEffect()
                .onDisappear {
                    Task {
                        if immersiveSpaceIsShown {
                            await dismissImmersiveSpace()
                        }
                    }
                }
        }
    }
}
