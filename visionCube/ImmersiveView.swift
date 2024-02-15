import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
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
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
