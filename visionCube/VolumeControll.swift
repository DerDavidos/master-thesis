import Foundation
import SwiftUI

struct VolumeControll: View {
    
    var axisModell: AxisModell
    
    var body: some View {
        
        @Bindable var axisModell = axisModell
        
        VStack {
            Spacer()
            Grid(verticalSpacing: 30) {
                GridRow {
                    Text("Step start:")
                    Slider(value: $axisModell.volumeModell.transferValue, in: 0...1) { editing in
                        if (!editing && axisModell.volumeModell.axisLoaded) {
                            axisModell.updateAllAxis()
                        }
                    }
                }
                GridRow {
                    Text("Step width:")
                    Slider(value: $axisModell.volumeModell.transferValue2, in: 0.1...0.2) { editing in
                        if (!editing && axisModell.volumeModell.axisLoaded) {
                            axisModell.updateAllAxis()
                        }
                    }
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
                            axisModell.setClipPlane()
                        }
                    Toggle("", isOn: $axisModell.clipBoxYEnabled)
                        .font(.extraLargeTitle)
                        .onChange(of: axisModell.clipBoxYEnabled) { _, newValue in
                            axisModell.setClipPlane()
                        }
                    Toggle("", isOn: $axisModell.clipBoxZEnabled)
                        .font(.extraLargeTitle)
                        .onChange(of: axisModell.clipBoxZEnabled) { _, newValue in
                            axisModell.setClipPlane()
                        }
                }
                
                GridRow {
                    Button(action: {
                        axisModell.reset()
                    }, label: {
                        Text("Reset")
                    })
                }
                
            }.frame(alignment: .center)
                .frame(width: 500, alignment: .center)
                .padding(30)
                .glassBackgroundEffect()
        }
    }
}
