import SwiftUI
import RealityKit
import RealityKitContent

struct ImmersiveView: View {
    var body: some View {
        RealityView { content in
                let entities = await createEntities()
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
