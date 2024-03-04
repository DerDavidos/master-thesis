import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct axisList {
    var entity: Entity
    var materialEntity: [MaterialEntity]
    var lastSliderValue: Float = -1.0
}

func setEntities(sliderValue: Float, axisList: inout axisList) {
    axisList.entity.isEnabled = true
    if (axisList.lastSliderValue != sliderValue) {
        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStep", value: MaterialParameters.Value.float(sliderValue))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: 1, height: 1),
                materials: [axisList.materialEntity[i].material]
            ))
        }
        axisList.lastSliderValue = sliderValue
    }
}

func addEntities(allEntities: Entity, axisList: axisList) {
    for materialEntity in  axisList.materialEntity {
        axisList.entity.addChild(materialEntity.entity)
        materialEntity.entity.components.set(ModelComponent(
            mesh: .generatePlane(width: 1, height: 1),
            materials: [materialEntity.material]
        ))
    }
    allEntities.addChild(axisList.entity)
}

struct AxisView: View {
    
    var axisRenderer: AxisRenderer = AxisRenderer()
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    let visionProPose = VisionProPositon()

    @State private var isDragging: Bool = false
    
    @State var rotation: Angle = .zero
    @State var rotationAxis: (x: CGFloat, y: CGFloat, z: CGFloat) = (0,0,0)
    @State private var sliderValue: Float = 0
    @State private var angle = Angle(degrees: 0.0)
    
    @State var clipPlane = Entity()
    @State var clipBox = Entity()
    @State var rotater = Entity()
    @State var clipRotation: Angle = .zero

    @State var loading = true
    
    var body: some View {
        let allEntities = Entity()
        
        var zPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
        var zNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
        var xPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
        var xNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
        var yPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
        var yNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])

        RealityView { _ in
            Task {
                await visionProPose.runArSession()
            }
        }
        
        VStack {
            Text("Slider Value: \(Int(sliderValue))")
            Slider(value: $sliderValue, in: 0...1)
                .padding()
        }
        
        RealityView {content in
            if let scene = try? await Entity(named: "Plane", in: realityKitContentBundle) {
                clipPlane = scene.findEntity(named: "Plane")!
                clipBox = scene.findEntity(named: "Cube")!
                clipPlane.components.set(InputTargetComponent())
                clipPlane.generateCollisionShapes(recursive: false)
                clipBox.transform.translation = SIMD3<Float>(-0.5, 1.3, 0)
                clipPlane.transform.translation = SIMD3<Float>(0.5, 0, 0)
//                content.add(clipBox)
                content.add(clipPlane)
            }
        }
        .gesture(DragGesture().targetedToEntity(clipPlane).onChanged{ value in
            let angle = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
            rotation = Angle(degrees: Double(angle)) * 0.5
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
            clipBox.orientation = quaternion
            clipPlane.orientation = quaternion
        })
        
        RealityView {content in
            if let scene = try? await Entity(named: "Plane", in: realityKitContentBundle) {
                rotater = scene.findEntity(named: "Rotater")!
                rotater.components.set(InputTargetComponent())
                rotater.generateCollisionShapes(recursive: false)
                rotater.transform.translation = SIMD3<Float>(0, 1.6, 0)
            }
            
            zPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "zPositive")
            addEntities(allEntities: rotater, axisList: zPositiveEntities)
            zNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "zNegative")
            addEntities(allEntities: rotater, axisList: zNegativeEntities)
            xPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "xPositive")
            addEntities(allEntities: rotater, axisList: xPositiveEntities)
            xNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "xNegative")
            addEntities(allEntities: rotater, axisList: xNegativeEntities)
            yPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "yPositive")
            addEntities(allEntities: rotater, axisList: yPositiveEntities)
            yNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "yNegative")
            addEntities(allEntities: rotater, axisList: yNegativeEntities)
            
            content.add(rotater)
            print("Loaded")
            loading = false
        }
        .gesture(DragGesture().targetedToEntity(rotater).onChanged{ value in
            let angle = sqrt(pow(value.translation.width, 2) + pow(value.translation.height, 2))
            rotation = Angle(degrees: Double(angle)) * 0.5
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
            rotater.orientation = quaternion
            rotater.transform.translation = SIMD3<Float>(0, 1.6, 0)
        })
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                
                Task {
                    if (loading) {
                        return
                    }
                    
                    let viewMatrix = await visionProPose.getTransform()!
                    let modelViewMatrix = rotater.transform.matrix * viewMatrix
                    
                    let viewVector: simd_float4 = matrix_multiply(simd_float4(0, 0, -1, 0), modelViewMatrix.inverse)
                    
                    zPositiveEntities.entity.isEnabled = false
                    zNegativeEntities.entity.isEnabled = false
                    xPositiveEntities.entity.isEnabled = false
                    xNegativeEntities.entity.isEnabled = false
                    yPositiveEntities.entity.isEnabled = false
                    yNegativeEntities.entity.isEnabled = false
                    
                    print(allEntities.transform.matrix)
//                    print(viewMatrix)
//                    print(modelViewMatrix)
//                    print(viewVector)
                    print()
                    
                    if (viewVector.z.magnitude > viewVector.x.magnitude && viewVector.z.magnitude > viewVector.y.magnitude) {
                        if (viewVector.z > 0) {
                            print("z positive")
                            setEntities(sliderValue: sliderValue, axisList: &zPositiveEntities)
                        } else {
                            print("z negative")
                            setEntities(sliderValue: sliderValue, axisList: &zNegativeEntities)
                        }
                    }
                    else if (viewVector.x.magnitude > viewVector.y.magnitude && viewVector.x.magnitude > viewVector.z.magnitude) {
                        if (viewVector.x > 0) {
                            print("x positive")
                            setEntities(sliderValue: sliderValue, axisList: &xPositiveEntities)
                        } else {
                            print("x negative")
                            setEntities(sliderValue: sliderValue, axisList: &xNegativeEntities)
                        }
                    }
                    else {
                        if (viewVector.y > 0) {
                            print("y Positive")
                            setEntities(sliderValue: sliderValue, axisList: &yPositiveEntities)
                        } else {
                            print("y Negative")
                            setEntities(sliderValue: sliderValue, axisList: &yNegativeEntities)
                        }
                    }
                }
            }
        }
    }
}
