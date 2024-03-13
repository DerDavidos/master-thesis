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
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()
    let visionProPose = VisionProPositon()
    
    @State var rotation: Angle = .zero
    @State var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0,0,0)
    @State private var sliderValue: Float = 0
    @State private var angle = Angle(degrees: 0.0)
    
    var axisModell: AxisModell
    
    func setEntities(entity: Entity) {
        for axis in axisModell.axises {
            if (axis.entity == entity) {
                axis.entity.isEnabled = true
            } else {
                axis.entity.isEnabled = false
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
                let scene = try! await Entity(named: "Plane", in: realityKitContentBundle)
                
                let root = scene.findEntity(named: "root")!
                axisModell.root = root
                
                axisModell.rotater = scene.findEntity(named: "Rotater")!
                axisModell.rotater.components.set(InputTargetComponent())
                axisModell.rotater.generateCollisionShapes(recursive: false)
                root.addChild(axisModell.rotater)
                
                axisModell.clipBoxX = scene.findEntity(named: "clipBoxX")!
                axisModell.clipBoxX.isEnabled = false
                axisModell.clipBoxY = scene.findEntity(named: "clipBoxY")!
                axisModell.clipBoxY.isEnabled = false
                axisModell.clipBoxZ = scene.findEntity(named: "clipBoxZ")!
                axisModell.clipBoxZ.isEnabled = false
                root.addChild(axisModell.clipBoxX)
                root.addChild(axisModell.clipBoxY)
                root.addChild(axisModell.clipBoxZ)
                
                let axisRenderer: AxisRenderer = AxisRenderer()
                axisModell.zPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "zPositive")
                axisModell.addEntities(root: root, axisList: &axisModell.zPositiveEntities)
                axisModell.zNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "zNegative")
                axisModell.addEntities(root: root, axisList: &axisModell.zNegativeEntities)
                axisModell.xPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "xPositive")
                axisModell.addEntities(root: root, axisList: &axisModell.xPositiveEntities)
                
                axisModell.xNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "xNegative")
                axisModell.addEntities(root: root, axisList: &axisModell.xNegativeEntities)
                axisModell.yPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "yPositive")
                axisModell.addEntities(root: root, axisList: &axisModell.yPositiveEntities)
                axisModell.yNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "yNegative")
                axisModell.addEntities(root: root, axisList: &axisModell.yNegativeEntities)
                
                root.transform.translation = SIMD3<Float>(0, 1.6, -1.5)
            }
            content.add(axisModell.root!)
            
            axisModell.loading = false
            axisModell.updateAllAxis()
            print("Loaded")
        }
        .gesture(DragGesture().targetedToEntity(axisModell.rotater).onChanged{ value in
            let angle = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
            rotation += Angle(degrees: Double(angle)) * 0.05
            let axisX = -value.translation.height / CGFloat(angle)
            let axisY = value.translation.width / CGFloat(angle)
            rotationAxis = (x: axisX, y: axisY, z: 0)
            let quaternion = simd_quatf(
                angle: Float(rotation.radians),
                axis: SIMD3<Float>(
                    x: Float(rotationAxis.x),
                    y: Float(rotationAxis.y),
                    z: Float(rotationAxis.z)
                )
            )
            axisModell.root!.orientation = quaternion
            axisModell.root!.transform.translation = SIMD3<Float>(0, 1.6, -1.5)
        })
        .gesture(DragGesture().targetedToEntity(axisModell.clipBoxX).onChanged{value in
            let newPosition = axisModell.clipBoxX.position.x + Float((value.translation.width + value.translation.height)/10000)
            axisModell.clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
            axisModell.X = max(-0.5, min(axisModell.clipBoxX.position.x, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        })
        .gesture(DragGesture().targetedToEntity(axisModell.clipBoxY).onChanged{value in
            let newPosition = axisModell.clipBoxY.position.y + Float(-(value.translation.width + value.translation.height)/10000)
            axisModell.clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
            axisModell.Y = max(-0.5, min(axisModell.clipBoxY.position.y, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        })
        .gesture(DragGesture().targetedToEntity(axisModell.clipBoxZ).onChanged{value in
            let newPosition = axisModell.clipBoxZ.position.z + Float(-(value.translation.width + value.translation.height)/10000)
            axisModell.clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
            axisModell.Z = max(-0.5, min(axisModell.clipBoxZ.position.z, 0.5)) + 0.5
        }.onEnded{_ in
            axisModell.updateAllAxis()
        })
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    if (axisModell.loading) {
                        return
                    }
                    
                    let viewMatrix = await visionProPose.getTransform()!
                    let modelMatrix = axisModell.root!.transform.matrix
                    let modelViewMatrix = viewMatrix.inverse * modelMatrix
                    let viewVector: simd_float4 = matrix_multiply(simd_float4(0, 0, -1, 0), modelViewMatrix)

                    if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
                        if (viewVector.z > 0) {
                            setEntities(entity: axisModell.zPositiveEntities.entity)
                        } else {
                            setEntities(entity: axisModell.zNegativeEntities.entity)
                        }
                    }
                    else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
                        if (viewVector.x > 0) {
                            setEntities(entity: axisModell.xPositiveEntities.entity)
                        } else {
                            setEntities(entity: axisModell.xNegativeEntities.entity)
                        }
                    }
                    else {
                        if (viewVector.y > 0) {
                            setEntities(entity: axisModell.yPositiveEntities.entity)
                        } else {
                            setEntities(entity: axisModell.yNegativeEntities.entity)
                        }
                    }
                }
            }
        }
    }
}
