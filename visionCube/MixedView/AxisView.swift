import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct AxisView: View {
    @State private var updateStackTimer: Timer?
    
    init(volumeModell: VolumeModell) {
        self.axisModell = volumeModell.axisModell
        self.volumeModell = volumeModell
    }
    
    var axisModell: AxisModell
    var volumeModell: VolumeModell
    
    var dragX: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxX).onChanged{value in
            let newPosition = axisModell.lastX + Float((value.translation.width)/2500)
            axisModell.clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
        }.onEnded{_ in
            volumeModell.XClip = max(-0.5, min(axisModell.clipBoxX.position.x, 0.5)) + 0.5
            axisModell.lastX = axisModell.clipBoxX.position.x
            volumeModell.updateAllAxis()
        }
    }
    
    var dragY: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxY).onChanged{value in
            let newPosition = axisModell.lastY + Float(-(value.translation.height)/2500)
            axisModell.clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
        }.onEnded{_ in
            volumeModell.YClip = max(-0.5, min(axisModell.clipBoxY.position.y, 0.5)) + 0.5
            axisModell.lastY = axisModell.clipBoxY.position.y
            volumeModell.updateAllAxis()
        }
    }
    
    var dragZ: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxZ).onChanged{value in
            let newPosition = axisModell.lastZ + Float(-(value.translation.width)/2500)
            axisModell.clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
        }.onEnded{_ in
            volumeModell.ZClip = max(-0.5, min(axisModell.clipBoxZ.position.z, 0.5)) + 0.5
            axisModell.lastZ = axisModell.clipBoxZ.position.z
            volumeModell.updateAllAxis()
        }
    }
    
    @MainActor
    fileprivate func updateSliceStack() async {
        if (!volumeModell.axisModell.axisLoaded) {
            return
        }
        
        let viewMatrixInv = await visionProPosition!.getTransform()
        if (viewMatrixInv == nil) {
            return
        }
        
        let modelMatrix = volumeModell.axisModell.root!.transform.matrix
        
        let modelViewMatrixInv = modelMatrix.inverse * viewMatrixInv!
        let viewVector = modelViewMatrixInv * simd_float4(0, 0, 0, 1)
        
        if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
            if (viewVector.z > 0) {
                axisModell.enableAxis(axisName: "zPositive")
            } else {
                axisModell.enableAxis(axisName: "zNegative")
            }
        }
        else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
            if (viewVector.x > 0) {
                axisModell.enableAxis(axisName: "xPositive")
            } else {
                axisModell.enableAxis(axisName: "xNegative")
            }
        }
        else {
            if (viewVector.y > 0) {
                axisModell.enableAxis(axisName: "yPositive")
            } else {
                axisModell.enableAxis(axisName: "yNegative")
            }
        }
    }

    var body: some View {
        @Bindable var axisModell = axisModell
        @Bindable var volumeModell = volumeModell
        
        RealityView {content in
            await volumeModell.initAxisView()
            volumeModell.axisModell.root!.transform = volumeModell.transform
            volumeModell.updateAllAxis()
            content.add(volumeModell.axisModell.root!)
        }
        .gesture(dragX)
        .gesture(dragY)
        .gesture(dragZ)
        .gesture(manipulationGesture.onChanged{ value in
            volumeModell.updateTransformation(value)
            volumeModell.axisModell.root!.transform = volumeModell.transform
        }.onEnded { value in
            volumeModell.lastTransform = volumeModell.transform
        })
        .onAppear {
            updateStackTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task {
                    await updateSliceStack()
                }
            }
        }
        .onDisappear{
            updateStackTimer!.invalidate()
        }
    }
}

var manipulationGesture: some Gesture<AffineTransform3D> {
    DragGesture()
        .simultaneously(with: MagnifyGesture())
        .simultaneously(with: RotateGesture3D(minimumAngleDelta: .zero))
        .map { gesture in
            let (translation, scale, rotation) = gesture.components()
            return AffineTransform3D(
                scale: scale,
                rotation: rotation,
                translation: translation
            )
        }
}

extension SimultaneousGesture<
    SimultaneousGesture<DragGesture, MagnifyGesture>,
    RotateGesture3D>.Value {
        func components() -> (Vector3D, Size3D, Rotation3D) {
            let translation = self.first?.first?.translation3D ?? .zero
            let magnification = self.first?.second?.magnification ?? 1
            let size = Size3D(width: magnification, height: magnification, depth: magnification)
            let rotation = self.second?.rotation ?? .identity
            return (translation, size, rotation)
        }
    }

func makeToOtherCordinate(vector: SIMD3<Float>) -> SIMD3<Float> {
    return simd_float3(vector.x / 1000, vector.y / -1000, vector.z / 1000)
}
