import CompositorServices
import SwiftUI

class FullControls {
    var volumeModell: VolumeModell
    
    private var tmpTranslation: SIMD3<Float> = .zero
    private var tmpRotation: simd_quatf = .init(.identity)
    private var tmpDistance: Double = 0.0

    private var doubleEventIsRunning = false
    
    init(volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
    }
    
    func distanceBetweenVectors(v1: SIMD3<Double>, v2: SIMD3<Double>) -> Double {
        let deltaX = v2.x - v1.x
        let deltaY = v2.y - v1.y
        let deltaZ = v2.z - v1.z
        return sqrt(deltaX * deltaX + deltaY * deltaY + deltaZ * deltaZ)
    }

    fileprivate func handleScaling(_ events: SpatialEventCollection) {
        doubleEventIsRunning = true
        var v1: SIMD3<Double>?
        var v2: SIMD3<Double>?
        for event in events {
            switch event.phase {
            case .active:
                if v1 == nil {
                    v1 = event.inputDevicePose!.pose3D.position.vector
                } else {
                    v2 = event.inputDevicePose!.pose3D.position.vector
                }
                print(event.inputDevicePose!.pose3D.position)
            case .cancelled, .ended:
                volumeModell.lastTransform.scale = volumeModell.transform.scale
                tmpDistance = 0
            default:
                break
            }
        }
        if (v1 != nil && v2 != nil) {
            let distance = distanceBetweenVectors(v1: v1!, v2: v2!)
            if tmpDistance == 0.0 {
                tmpDistance = distance
            }
            volumeModell.transform.scale = SIMD3(repeating: volumeModell.lastTransform.scale.x * (Float(distance - tmpDistance) + 1))
        }
    }
    
    fileprivate func handleTranslationAndRotation(_ event: SpatialEventCollection.Event) {
        switch event.phase {
        case .active:
            // One hand from the scaling movement is still active
            if doubleEventIsRunning {
                return
            }
            if let pose = event.inputDevicePose {
                if tmpTranslation == .zero {
                    tmpTranslation = SIMD3<Float>(pose.pose3D.position.vector)
                    tmpRotation = simd_quatf(pose.pose3D.rotation)
                }
                
                volumeModell.transform.rotation = volumeModell.lastTransform.rotation * simd_quatf(pose.pose3D.rotation) * tmpRotation.inverse
                let translate = (SIMD3<Float>(pose.pose3D.position.vector) - tmpTranslation) * 2
                volumeModell.transform.translation = volumeModell.lastTransform.translation + translate
            }
        case .cancelled, .ended:
            volumeModell.lastTransform.translation = volumeModell.transform.translation
            volumeModell.lastTransform.rotation = volumeModell.transform.rotation
            tmpTranslation = .zero
            tmpRotation = .init(.identity)
            doubleEventIsRunning = false
        default:
            break
        }
    }
    
    func handleSpatialEvents(_ events: SpatialEventCollection) {
        if (events.count == 2) {
            handleScaling(events)
        } else {
            handleTranslationAndRotation(events.first!)
        }
    }
}
