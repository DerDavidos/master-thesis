import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

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
//                    rotation.degrees += 0.5
                    
                    let m1 = Transform(pitch: Float(rotation.radians)).matrix
                    let m2 = Transform(yaw: Float(rotation.radians)).matrix
                    
                    allEntities.transform.matrix = matrix_multiply(m1, m2)
                    allEntities.transform.translation = SIMD3<Float>(0, 2, -2)
                }
            }
            
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task {
                    let mtx = await visionProPose.getTransform()
                    let angles = mtx!.eulerAngles

                    pitch = angles.x + allEntities.transform.matrix.eulerAngles.x
                    yaw = angles.y + allEntities.transform.matrix.eulerAngles.y
                    
                    zPositiveEntities.isEnabled = false
                    zNegativeEntities.isEnabled = false
                    xPositiveEntities.isEnabled = false
                    xNegativeEntities.isEnabled = false
                    yPositiveEntities.isEnabled = false
                    yNegativeEntities.isEnabled = false
                    
                    if (pitch < -0.75 || pitch > 0.75) {
                        if (pitch > 0.75) {
                            yPositiveEntities.isEnabled = true
                        } else {
                            yNegativeEntities.isEnabled = true
                        }
                       
                    } else if ((yaw > -0.75 && yaw < 0.75) ||  yaw > 2.25 ||  yaw < -2.25) {
                        if (yaw > -0.75 && yaw < 0.75) {
                            zPositiveEntities.isEnabled = true
                        } else {
                            zNegativeEntities.isEnabled = true
                        }
                    } else {
                        if (yaw >= 0.75) {
                            xPositiveEntities.isEnabled = true
                        } else {
                            xNegativeEntities.isEnabled = true
                        }
                    }
                }
            }
        }
    }
}
