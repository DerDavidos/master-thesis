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
    
    var body: some View {
        let axis0Entities = Entity()
        let axis1Entities = Entity()
        let axis2Entities = Entity()
        
        RealityView { _ in
            
            Task {
                await visionProPose.runArSession()
            }
            
        }
        
        RealityView {content in
            for entity in await sharedRenderer.renderer.getEntities(axisNumber: 0) {
                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                axis0Entities.addChild(entity)
            }
            content.add(axis0Entities)
            
            for entity in await sharedRenderer.renderer.getEntities(axisNumber: 1) {
                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                axis1Entities.addChild(entity)
            }
            content.add(axis1Entities)
            
            for entity in await sharedRenderer.renderer.getEntities(axisNumber: 2) {
                entity.transform.translation += SIMD3<Float>(0, 2, -0.5)
                axis2Entities.addChild(entity)
            }
            content.add(axis2Entities)
            print("Loaded")
        }.onAppear {
            Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task {
                    let mtx = await visionProPose.getTransform()
                    let angles = mtx!.eulerAngles
                    pitch = angles.x
                    yaw = angles.y

                    axis0Entities.isEnabled = false
                    axis1Entities.isEnabled = false
                    axis2Entities.isEnabled = false

                    
                    if (pitch <= -0.5 || pitch >= 0.5) {
                        axis2Entities.isEnabled = true
                    } else if ((yaw >= -0.75 && yaw <= 0.75) ||  yaw >= 2.25 ||  yaw <= -2.25) {
                        axis0Entities.isEnabled = true
                    } else {
                        axis1Entities.isEnabled = true
                    }
                }
            }
        }
    }
    
}
