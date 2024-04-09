import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct AxisView: View {

    init(axisModell: AxisModell, visionProPose: VisionProPositon) {
        self.axisModell = axisModell
        self.visionProPose = visionProPose
    }
    
    var axisModell: AxisModell
    
    var visionProPose: VisionProPositon
    
    @State var lastX: Float = -0.55
    @State var lastY: Float = -0.55
    @State var lastZ: Float = -0.55
    
    var dragX: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxX).onChanged{value in
            let newPosition = lastX + Float((value.translation.width)/2500)
            axisModell.clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.XClip = max(-0.5, min(axisModell.clipBoxX.position.x, 0.5)) + 0.5
        }.onEnded{_ in
            lastX = axisModell.clipBoxX.position.x
            axisModell.updateAllAxis()
        }
    }
    
    var dragY: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxY).onChanged{value in
            let newPosition = lastY + Float(-(value.translation.height)/2500)
            axisModell.clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.YClip = max(-0.5, min(axisModell.clipBoxY.position.y, 0.5)) + 0.5
        }.onEnded{_ in
            lastY = axisModell.clipBoxY.position.y
            axisModell.updateAllAxis()
        }
    }
    
    var dragZ: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxZ).onChanged{value in
            let newPosition = lastZ + Float(-(value.translation.width)/2500)
            axisModell.clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.ZClip = max(-0.5, min(axisModell.clipBoxZ.position.z, 0.5)) + 0.5
        }.onEnded{_ in
            lastZ = axisModell.clipBoxZ.position.z
            axisModell.updateAllAxis()
        }
    }
    
    @MainActor
    fileprivate func updateSliceStack() async {
        if (!axisModell.volumeModell.axisLoaded) {
            return
        }
        
        let viewMatrixInv = await visionProPose.getTransform()!
        let modelMatrix = axisModell.root!.transform.matrix
        
        let modelViewMatrixInv = modelMatrix.inverse * viewMatrixInv
        let viewVector = modelViewMatrixInv * simd_float4(0, 0, 0, 1)

        if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
            if (viewVector.z > 0) {
                axisModell.enableAxis(entity: axisModell.zPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.zNegativeEntities.entity)
            }
        }
        else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
            if (viewVector.x > 0) {
                axisModell.enableAxis(entity: axisModell.xPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.xNegativeEntities.entity)
            }
        }
        else {
            if (viewVector.y > 0) {
                axisModell.enableAxis(entity: axisModell.yPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.yNegativeEntities.entity)
            }
        }
    }

    var body: some View {
        @Bindable var axisModell = axisModell
        
        RealityView {content in
  
            if (axisModell.root == nil) {
                await axisModell.loadAllEntities()
            }
            content.add(axisModell.root!)
            
            axisModell.volumeModell.axisLoaded = true
            axisModell.updateAllAxis()
            print("Loaded")
        }
        .gesture(dragX)
        .gesture(dragY)
        .gesture(dragZ)
        .gesture(manipulationGesture.onChanged{ value in
            axisModell.updateTransformation(value)
        }.onEnded { value in
            axisModell.volumeModell.rotation = axisModell.volumeModell.rotation.rotated(by: value.rotation!)
            axisModell.volumeModell.translation += value.translation
//            axisModell.volumeModell.scale = axisModell.root!.scale.x
        })
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    await updateSliceStack()
                }
            }
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
