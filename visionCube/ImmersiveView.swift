import SwiftUI
import RealityKit
import RealityKitContent
import ARKit

struct ImmersiveView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    
    
    let session = ARKitSession()
    let worldInfo = WorldTrackingProvider()

    var body: some View {
        RealityView { content in
            let allAxis = await sharedRenderer.renderer.getEntities()
            allAxis.forEach { oneAxis in
                for entity in oneAxis {
                    entity.transform.translation += SIMD3<Float>(0, 2, -2)
                    content.add(entity)
                }
            }
        }
//        .task {
//            do {
//                try await session.run([worldInfo])
//                let deviceAnchor = worldInfo.queryDeviceAnchor(atTimestamp: CACurrentMediaTime())
//                let anchor = WorldAnchor(originFromAnchorTransform: deviceAnchor!.originFromAnchorTransform)
//                try await worldInfo.addAnchor(anchor)
//                
//                for await update in worldInfo.anchorUpdates {
//                    switch update.event {
//                    case .added, .updated:
//                        // Update the app's understanding of this world anchor.
//                        
//                        print("Anchor position updated.")
//                    case .removed:
//                        // Remove content related to this anchor.
//                        print("Anchor position now unknown.")
//                    }
//                }
//            } catch {
//                
//            }
//            
//        }
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
