import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    
    @EnvironmentObject var sharedRenderer: SharedRenderer
    
    var body: some View {
        RealityView { content in
            let entities = await sharedRenderer.renderer.getEntities()
                for entity in entities {
                    entity.transform.translation += SIMD3<Float>(0, 2, -2)
                    content.add(entity)
                }
        }
    }
}

#Preview {
    ImmersiveView()
        .previewLayout(.sizeThatFits)
}
