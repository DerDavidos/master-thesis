import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct ImmersiveView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    let visionProPose = VisionProPositon()

    @State private var pitch: Float = 0.0
    @State private var yaw: Float = 0.0
    
    @State var rotation: Angle = .zero
    
    var body: some View {
        let allEntities = Entity()
        
        let zPositiveEntities = Entity()
        let zNegativeEntities = Entity()
        let xPositiveEntities = Entity()
        let xNegativeEntities = Entity()
        let yPositiveEntities = Entity()
        let yNegativeEntities = Entity()
        
        RealityView { _ in
            Task {
                await visionProPose.runArSession()
            }
        }
        
        RealityView {content in
            
            for entity in await sharedRenderer.renderer.getEntities(axis: "zPositive") {
                zPositiveEntities.addChild(entity)
            }
            allEntities.addChild(zPositiveEntities)
            for entity in await sharedRenderer.renderer.getEntities(axis: "zNegative") {
                zNegativeEntities.addChild(entity)
            }
            allEntities.addChild(zNegativeEntities)
        
            for entity in await sharedRenderer.renderer.getEntities(axis: "xPositive") {
                xPositiveEntities.addChild(entity)
            }
            allEntities.addChild(xPositiveEntities)
            for entity in await sharedRenderer.renderer.getEntities(axis: "xNegative") {
                xNegativeEntities.addChild(entity)
            }
            allEntities.addChild(xNegativeEntities)
            
            for entity in await sharedRenderer.renderer.getEntities(axis: "yPositive") {
                yPositiveEntities.addChild(entity)
            }
            allEntities.addChild(yPositiveEntities)
            for entity in await sharedRenderer.renderer.getEntities(axis: "yNegative") {
                yNegativeEntities.addChild(entity)
            }
            allEntities.addChild(yNegativeEntities)
            
            content.add(allEntities)
            print("Loaded")
        }
        .onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                Task {
                    rotation.degrees += 0.5
                    
                    let m1 = Transform(pitch: Float(rotation.radians)).matrix
                    let m2 = Transform(yaw: Float(rotation.radians)).matrix
                    
                    allEntities.transform.matrix = matrix_multiply(m1, m2)
                    allEntities.transform.translation += SIMD3<Float>(0, 1.6, 0)
                }
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task {
                    let viewMatrix = await visionProPose.getTransform()!
                     
                    var modelViewMatrix = allEntities.transform.matrix * viewMatrix
                    
                    let viewVec: simd_float4 = matrix_multiply(simd_float4(0, 0, 1, 0), modelViewMatrix)
//                    let viewVec: simd_float4 = simd_mul(modelViewMatrix, simd_float4(0, 0, 1, 0))
                    
                    zPositiveEntities.isEnabled = false
                    zNegativeEntities.isEnabled = false
                    xPositiveEntities.isEnabled = false
                    xNegativeEntities.isEnabled = false
                    yPositiveEntities.isEnabled = false
                    yNegativeEntities.isEnabled = false
                    
                    if (viewVec.z.magnitude > viewVec.x.magnitude && viewVec.z.magnitude > viewVec.y.magnitude) {
                        if (viewVec.z > 0) {
                            print("z positive")
                            zPositiveEntities.isEnabled = true
                        } else {
                            print("z negative")
                            zNegativeEntities.isEnabled = true
                        }
                    }
                    else if (viewVec.x.magnitude > viewVec.y.magnitude && viewVec.x.magnitude > viewVec.z.magnitude) {
                        if (viewVec.x > 0) {
                            print("x positive")
                            xPositiveEntities.isEnabled = true
                        } else {
                            print("x negative")
                            xNegativeEntities.isEnabled = true
                        }
                    }
                    else {
                        if (viewVec.y > 0) {
                            print("y Positive")
                            yPositiveEntities.isEnabled = true
                        } else {
                            print("y Negative")
                            yNegativeEntities.isEnabled = true
                        }
                    }
                }
            }
        }
    }
}
