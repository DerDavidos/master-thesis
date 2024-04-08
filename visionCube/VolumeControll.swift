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
                    Text("Step:")
                    Slider(value: $axisModell.volumeModell.step, in: 0...1) { editing in
                        if (!editing && axisModell.volumeModell.axisLoaded) {
                            axisModell.updateAllAxis()
                        }
                    }
                }
                GridRow {
                    Text("Shift:")
                    Slider(value: $axisModell.volumeModell.shift, in: 0...1) { editing in
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
