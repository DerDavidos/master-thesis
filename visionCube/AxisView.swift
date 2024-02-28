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
    @State private var sliderValue: Float = 0
    
    @State var clipPlane = Entity()
    @State var clipBox = Entity()
    @State var clipRotation: Angle = .zero
    
    var drag: some Gesture {
            DragGesture()
                .onChanged { _ in
                    print("draging")
                    isDragging = true
                    rotation.degrees += 5.0
                }
                .onEnded { _ in
                    isDragging = false
                }
        }
    
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
        
//        RealityView {content in
//            if let scene = try? await Entity(named: "Plane", in: realityKitContentBundle) {
//                clipPlane = scene.findEntity(named: "Plane")!
//                clipBox = scene.findEntity(named: "Cube")!
//                clipPlane.components.set(InputTargetComponent())
//                clipPlane.generateCollisionShapes(recursive: false)
//                clipBox.transform.translation = SIMD3<Float>(-0.5, 1.3, 0)
//                content.add(clipBox)
//                content.add(clipPlane)
//            }
//        }
//        .gesture(DragGesture().targetedToAnyEntity().onChanged{ scene in
//            clipRotation.degrees += 0.5
//            
//            let m1 = Transform(pitch: Float(clipRotation.radians)).matrix
//            let m2 = Transform(yaw: Float(clipRotation.radians)).matrix
//            
//            clipPlane.transform.matrix = matrix_multiply(m1, m2)
//            clipBox.transform.matrix = matrix_multiply(m1, m2)
//            clipBox.transform.translation = SIMD3<Float>(0, 1.3, 0)
//        })

        RealityView {content in
            zPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "zPositive")
            addEntities(allEntities: allEntities, axisList: zPositiveEntities)
            zNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "zNegative")
            addEntities(allEntities: allEntities, axisList: zNegativeEntities)
            xPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "xPositive")
            addEntities(allEntities: allEntities, axisList: xPositiveEntities)
            xNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "xNegative")
            addEntities(allEntities: allEntities, axisList: xNegativeEntities)
            yPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "yPositive")
            addEntities(allEntities: allEntities, axisList: yPositiveEntities)
            yNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "yNegative")
            addEntities(allEntities: allEntities, axisList: yNegativeEntities)
            
            content.add(allEntities)
            print("Loaded")
        }
//        .rotation3DEffect(.degrees(rotation.degrees), axis: (x: 0.0, y: 1.0, z: 0.0))
//        .rotation3DEffect(.degrees(rotation.degrees), axis: (x: 0.0, y: 0.0, z: 1.0))
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
//                    rotation.degrees += 0.5
                    
                    let m1 = Transform(pitch: Float(rotation.radians)).matrix
                    let m2 = Transform(yaw: Float(rotation.radians)).matrix
                    
                    allEntities.transform.matrix = matrix_multiply(m1, m2)
                    allEntities.transform.translation += SIMD3<Float>(0, 1.6, 0)
                }
            }

            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                
                Task {
                    if (yNegativeEntities.entity.children.isEmpty) {
                        return
                    }
                    
                    let viewMatrix = await visionProPose.getTransform()!
                    let modelViewMatrix = viewMatrix * allEntities.transform.matrix
                    let viewVector: simd_float4 = simd_mul(modelViewMatrix.inverse, simd_float4(0, 0, -1, 0))
                    
                    zPositiveEntities.entity.isEnabled = false
                    zNegativeEntities.entity.isEnabled = false
                    xPositiveEntities.entity.isEnabled = false
                    xNegativeEntities.entity.isEnabled = false
                    yPositiveEntities.entity.isEnabled = false
                    yNegativeEntities.entity.isEnabled = false
                    
//                    print(viewVector)
                    
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
                        print(viewVector.y)
                        if (viewVector.y > 0 && viewVector.z < 0) {
                            print("y Positive")
                            setEntities(sliderValue: sliderValue, axisList: &yPositiveEntities)
                        } else if(viewVector.y < 0 && viewVector.z < 0) {
                            print("y Negative")
                            setEntities(sliderValue: sliderValue, axisList: &yNegativeEntities)
                        } else if(viewVector.y > 0 && viewVector.z > 0) {
                            print("y Negative")
                            setEntities(sliderValue: sliderValue, axisList: &yNegativeEntities)
                        } else {
                            print("y Positive")
                            setEntities(sliderValue: sliderValue, axisList: &yPositiveEntities)
                        }
                    }
                }
            }
        }
    }
}
