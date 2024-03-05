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
        guard let deviceAnchor = worldTracking.queryDeviceAnchor(atTimestamp: CACurrentMediaTime()) else {
            return nil
        }
        return deviceAnchor.originFromAnchorTransform
    }
}
