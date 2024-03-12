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
    
    @State private var X: Float = 0
    @State private var Y: Float = 0
    @State private var Z: Float = 0
    
    @State var clipBoxX = Entity()
    @State var clipBoxY = Entity()
    @State var clipBoxZ = Entity()
    @State var rotater = Entity()
    @State var root = Entity()
    @State var clipRotation: Angle = .zero

    @State var loading: Bool = true
    
    @State var axises: [axisList] = Array()
    @State var zPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    @State var zNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    @State var xPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    @State var xNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    @State var yPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    @State var yNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])

    @State private var planePosition: CGFloat = 0
    
    func setEntities(entity: Entity) {
        for axis in axises {
            if (axis.entity == entity) {
                axis.entity.isEnabled = true
            } else {
                axis.entity.isEnabled = false
            }
        }
    }
    
    func updateAxis(axisList: inout axisList) {
        loading = true
        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStep", value: MaterialParameters.Value.float(sliderValue))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(X))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(Y))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(Z))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: 1, height: 1),
                materials: [axisList.materialEntity[i].material]
            ))
        }
        loading = false
    }
    
    func addEntities(allEntities: Entity, axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            axisList.entity.addChild(axisList.materialEntity[i].entity)
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStep", value: MaterialParameters.Value.float(0))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(X))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(Y))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(Z))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: 1, height: 1),
                materials: [axisList.materialEntity[i].material]
            ))
        }
        allEntities.addChild(axisList.entity)
        axises.append(axisList)
    }
    
    fileprivate func updateAllAxis() {
        print("updating")
        updateAxis(axisList: &zNegativeEntities)
        updateAxis(axisList: &zPositiveEntities)
        updateAxis(axisList: &xNegativeEntities)
        updateAxis(axisList: &xPositiveEntities)
        updateAxis(axisList: &yNegativeEntities)
        updateAxis(axisList: &yPositiveEntities)
        print("updated")
    }
    
    var body: some View {
        VStack {
            Spacer()
            Grid(alignment: .leading, verticalSpacing: 30) {
                GridRow {
                    Text("Slider Value:")
                    Slider(value: $sliderValue, in: 0...1) { editing in
                        if (!editing && !loading) {
                            updateAllAxis()
                        }
                    }
                }
                GridRow {
                    Button(action: {
                        rotater.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 0))
                        clipBoxZ.position.z = -0.55
                        clipBoxX.position.x = -0.55
                        clipBoxY.position.y = -0.55
                        X = 0
                        Y = 0
                        Z = 0
                        sliderValue = 0
                        updateAllAxis()
                    }, label: {
                        Text("Reset")
                    })
                }
            }.frame(alignment: .center)
            .frame(width: 500, alignment: .center)
            .padding(30)
            .glassBackgroundEffect()
        }
        
        RealityView {content in
            Task {
                await visionProPose.runArSession()
            }
            
            if let scene = try? await Entity(named: "Plane", in: realityKitContentBundle) {
                root = scene.findEntity(named: "root")!
                rotater = scene.findEntity(named: "Rotater")!
                rotater.components.set(InputTargetComponent())
                rotater.generateCollisionShapes(recursive: false)
                root.transform.translation = SIMD3<Float>(0, 1.6, -2)
                
                clipBoxX = scene.findEntity(named: "clipBoxX")!
                clipBoxX.components.set(InputTargetComponent())
                clipBoxX.generateCollisionShapes(recursive: false)
                clipBoxY = scene.findEntity(named: "clipBoxY")!
                clipBoxZ = scene.findEntity(named: "clipBoxZ")!
                
                root.addChild(rotater)
                root.addChild(clipBoxX)
                root.addChild(clipBoxY)
                root.addChild(clipBoxZ)
            }
            
            let axisRenderer: AxisRenderer = AxisRenderer()
            zPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "zPositive")
            addEntities(allEntities: root, axisList: &zPositiveEntities)
            zNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "zNegative")
            addEntities(allEntities: root, axisList: &zNegativeEntities)
            xPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "xPositive")
            addEntities(allEntities: root, axisList: &xPositiveEntities)
            xNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "xNegative")
            addEntities(allEntities: root, axisList: &xNegativeEntities)
            yPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "yPositive")
            addEntities(allEntities: root, axisList: &yPositiveEntities)
            yNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "yNegative")
            addEntities(allEntities: root, axisList: &yNegativeEntities)
            
            content.add(root)
            print("Loaded")
            loading = false
        }
        .gesture(DragGesture().targetedToEntity(rotater).onChanged{ value in
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
            root.orientation = quaternion
            root.transform.translation = SIMD3<Float>(0, 1.6, -2)
        })
        .gesture(DragGesture().targetedToEntity(clipBoxX).onChanged{value in
            let newPosition = clipBoxX.position.x + Float((value.translation.width + value.translation.height)/10000)
            clipBoxX.position.x = max(-0.55, min(newPosition, 0.55))
            X = max(-0.5, min(clipBoxX.position.x, 0.5)) + 0.5
        }.onEnded{_ in
            updateAllAxis()
        })
        .gesture(DragGesture().targetedToEntity(clipBoxY).onChanged{value in
            let newPosition = clipBoxY.position.y + Float(-(value.translation.width + value.translation.height)/10000)
            clipBoxY.position.y = max(-0.55, min(newPosition, 0.55))
            Y = max(-0.5, min(clipBoxY.position.y, 0.5)) + 0.5
        }.onEnded{_ in
            updateAllAxis()
        })
        .gesture(DragGesture().targetedToEntity(clipBoxZ).onChanged{value in
            let newPosition = clipBoxZ.position.z + Float(-(value.translation.width + value.translation.height)/10000)
            clipBoxZ.position.z = max(-0.55, min(newPosition, 0.55))
            Z = max(-0.5, min(clipBoxZ.position.z, 0.5)) + 0.5
        }.onEnded{_ in
           updateAllAxis()
        })
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    if (loading) {
                        return
                    }
                    
                    let viewMatrix = await visionProPose.getTransform()!
                    let modelMatrix = root.transform.matrix
                    let modelViewMatrix = viewMatrix.inverse * modelMatrix
                    let viewVector: simd_float4 = matrix_multiply(simd_float4(0, 0, -1, 0), modelViewMatrix)

                    if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
                        if (viewVector.z > 0) {
                            setEntities(entity: zPositiveEntities.entity)
                        } else {
                            setEntities(entity: zNegativeEntities.entity)
                        }
                    }
                    else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
                        if (viewVector.x > 0) {
                            setEntities(entity: xPositiveEntities.entity)
                        } else {
                            setEntities(entity: xNegativeEntities.entity)
                        }
                    }
                    else {
                        if (viewVector.y > 0) {
                            setEntities(entity: yPositiveEntities.entity)
                        } else {
                            setEntities(entity: yNegativeEntities.entity)
                        }
                    }
                }
            }
        }
    }
}
