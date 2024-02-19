import SwiftUI
import RealityKit
import RealityKitContent

import ARKit

class VisionProPositon {
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()

    func runArSession() async {
        do {
            try await session.run([worldTracking])
        } catch {
            print("Error starting AR session: \(error)")
        }
    }

    func getTransform() async -> simd_float4x4? {
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: 0) else {
            return nil
        }
        return deviceAnchor.originFromAnchorTransform
    }
}

extension simd_float4x4 {
    var eulerAngles: simd_float3 {
        return simd_float3(
            x: asin(-self[2][1]),
            y: atan2(self[2][0], self[2][2]),
            z: atan2(self[0][1], self[1][1])
        )
    }
}
