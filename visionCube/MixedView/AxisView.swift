import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct axisList {
    var entity: Entity
    var materialEntity: [MaterialEntity]
}

struct AxisView: View {
    let visionProPose = VisionProPositon()
    var axisModell: AxisModell
    
    @State var rotation: Rotation3D = .identity
    @State var scale: Double = 1
    
    var dragX: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxX).onChanged{value in
            let newPosition = axisModell.clipBoxY.position.x + Float(-(value.translation.width)/5000)
            axisModell.clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.X = max(-0.5, min(axisModell.clipBoxX.position.x, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    var dragY: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxY).onChanged{value in
            let newPosition = axisModell.clipBoxY.position.y + Float(-(value.translation.height)/5000)
            axisModell.clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.Y = max(-0.5, min(axisModell.clipBoxY.position.y, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    var dragZ: some Gesture {
        DragGesture(coordinateSpace: .local).targetedToEntity(axisModell.clipBoxZ).onChanged{value in
            let newPosition = axisModell.clipBoxZ.position.z + Float(-(value.translation.width)/5000)
            axisModell.clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.Z = max(-0.5, min(axisModell.clipBoxZ.position.z, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    @MainActor
    fileprivate func updateSliceStack(rot: Rotation3D) async {
        if (!axisModell.volumeModell.axisLoaded) {
            return
        }
        
        let viewMatrixInv = await visionProPose.getTransform()!
        let modelMatrix = axisModell.root!.transform.matrix
        
        let modelViewMatrixInv = modelMatrix.inverse * viewMatrixInv
//        let modelViewMatrix = viewMatrix * modelMatrix.inverse
        
        let viewVector = modelViewMatrixInv * simd_float4(0, 0, 0, 1)
        
        print(viewMatrixInv)
        print(modelMatrix)
        print()
        
        if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
            if (viewVector.z < 0) {
                axisModell.enableAxis(entity: axisModell.zPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.zNegativeEntities.entity)
            }
        }
        else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
            if (viewVector.x < 0) {
                axisModell.enableAxis(entity: axisModell.xPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.xNegativeEntities.entity)
            }
        }
        else {
            if (viewVector.y < 0) {
                axisModell.enableAxis(entity: axisModell.yPositiveEntities.entity)
            } else {
                axisModell.enableAxis(entity: axisModell.yNegativeEntities.entity)
            }
        }
    }

    var body: some View {
        @Bindable var axisModell = axisModell
        
        RealityView {content in
            Task {
                await visionProPose.runArSession()
            }
            
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
        .rotation3DEffect(rotation)
        .gesture(manipulationGesture.onChanged{ value in
//            scale = value.scale.width
            axisModell.updateTransformation(value)
        }.onEnded { value in
            axisModell.volumeModell.rotation = axisModell.volumeModell.rotation.rotated(by: value.rotation!)
            axisModell.translation += value.translation
        })
        //        .scaleEffect(scale)
//        .offset(x: axisModell.translation.x, y: axisModell.translation.y)
//        .offset(z: axisModell.translation.z)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    await updateSliceStack(rot: rotation)
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

