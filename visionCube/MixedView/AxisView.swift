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
    

    var dragX: some Gesture {
        DragGesture().targetedToEntity(axisModell.clipBoxX).onChanged{value in
            let newPosition = axisModell.clipBoxY.position.x + Float(-(value.translation.width + value.translation.height)/5000)
            axisModell.clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.X = max(-0.5, min(axisModell.clipBoxX.position.x, 0.5)) + 0.5
           
           
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    var dragY: some Gesture {
        DragGesture().targetedToEntity(axisModell.clipBoxY).onChanged{value in
            let newPosition = axisModell.clipBoxY.position.y + Float(-(value.translation.width + value.translation.height)/5000)
            axisModell.clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.Y = max(-0.5, min(axisModell.clipBoxY.position.y, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    var dragZ: some Gesture {
        DragGesture().targetedToEntity(axisModell.clipBoxZ).onChanged{value in
            let newPosition = axisModell.clipBoxZ.position.z + Float(-(value.translation.width + value.translation.height)/5000)
            axisModell.clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
            axisModell.volumeModell.Z = max(-0.5, min(axisModell.clipBoxZ.position.z, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        }
    }
    
    fileprivate func updateSliceStack() async {
        if (axisModell.loading) {
            return
        }
        
        let viewMatrix = await visionProPose.getTransform()!
        let modelMatrix = await axisModell.root!.transform.matrix
        let modelViewMatrix = viewMatrix.inverse * modelMatrix
        let viewVector: simd_float4 = matrix_multiply(simd_float4(0, 0, -1, 0), modelViewMatrix)
        
        if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
            if (viewVector.z > 0) {
                await axisModell.enableAxis(entity: axisModell.zPositiveEntities.entity)
            } else {
                await axisModell.enableAxis(entity: axisModell.zNegativeEntities.entity)
            }
        }
        else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
            if (viewVector.x > 0) {
                await axisModell.enableAxis(entity: axisModell.xPositiveEntities.entity)
            } else {
                await axisModell.enableAxis(entity: axisModell.xNegativeEntities.entity)
            }
        }
        else {
            if (viewVector.y > 0) {
                await axisModell.enableAxis(entity: axisModell.yPositiveEntities.entity)
            } else {
                await axisModell.enableAxis(entity: axisModell.yNegativeEntities.entity)
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
            
            axisModell.loading = false
            axisModell.updateAllAxis()
            print(axisModell.loading)
            print("Loaded")
        }
        .gesture(DragGesture().targetedToEntity(axisModell.rotater).onChanged{ value in
            axisModell.rotate(X: value.translation.width, Y: value.translation.height)
        })
        .gesture(dragX)
        .gesture(dragY)
        .gesture(dragZ)
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    await updateSliceStack()
                }
            }
        }
    }
}
