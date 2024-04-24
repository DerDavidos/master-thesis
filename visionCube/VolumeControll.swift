import Foundation
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

    var axisModell: AxisModell
    
    var body: some View {
        
        @Bindable var axisModell = axisModell
        
        VStack {
            Spacer()
            Grid(verticalSpacing: 30) {
                GridRow {
                    Text("Start:")
                    Slider(value: $axisModell.volumeModell.smoothStepStart, in: 0...1) { editing in
                        if (!editing && axisModell.volumeModell.axisLoaded) {
                            axisModell.updateAllAxis()
                        }
                    }.opacity(axisModell.volumeModell.loading ? 0.0 : 1.0)
                }
                GridRow {
                    Text("Shift:")
                    Slider(value: $axisModell.volumeModell.smoothStepShift, in: 0...1) { editing in
                        if (!editing && axisModell.volumeModell.axisLoaded) {
                            axisModell.updateAllAxis()
                        }
                    }.opacity(axisModell.volumeModell.loading ? 0.0 : 1.0)
                }
                
                GridRow {
                    Text("X Plane")
                    Text("Y Plane")
                    Text("Z Plane")
                }
                
                GridRow {
                    Toggle("", isOn: $axisModell.clipBoxXEnabled)
                        .font(.extraLargeTitle)
                        .onChange(of: axisModell.clipBoxXEnabled) { _, newValue in
                            axisModell.setClipPlanes()
                        }
                    Toggle("", isOn: $axisModell.clipBoxYEnabled)
                        .font(.extraLargeTitle)
                        .onChange(of: axisModell.clipBoxYEnabled) { _, newValue in
                            axisModell.setClipPlanes()
                        }
                    Toggle("", isOn: $axisModell.clipBoxZEnabled)
                        .font(.extraLargeTitle)
                        .onChange(of: axisModell.clipBoxZEnabled) { _, newValue in
                            axisModell.setClipPlanes()
                        }
                }
                
                NavigationStack {
                    Form {
                        Section {
                            Picker("Volume", selection: $axisModell.volumeModell.selectedVolume) {
                                ForEach(listRawFiles(at: Bundle.main.resourcePath!), id: \.self) {
                                    Text($0)
                                }
                            }.onChange(of: axisModell.volumeModell.selectedVolume) {
                                Task {
                                    await axisModell.reset(selectedVolume: axisModell.volumeModell.selectedVolume)
                                }
                            }
                        }
                    }
                }
                
                GridRow {
                    Button(action: {
                        Task {
                            await axisModell.reset(selectedVolume: axisModell.volumeModell.selectedVolume)
                        }
                    }, label: {
                        Text("Reset")
                    })
                }
                
            }.frame(alignment: .center)
                .frame(width: 500, height: 400, alignment: .center)
                .padding(30)
                .glassBackgroundEffect()
        }
    }
}
