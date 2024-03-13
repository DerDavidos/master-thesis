import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

@Observable
class AxisModell {
    var loading: Bool = true

    var axises: [axisList] = Array()
    var zPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    var zNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    var xPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    var xNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    var yPositiveEntities: axisList = axisList(entity: Entity(), materialEntity: [])
    var yNegativeEntities: axisList = axisList(entity: Entity(), materialEntity: [])

    var clipBoxX = Entity()
    var clipBoxY = Entity()
    var clipBoxZ = Entity()
    var root: Entity?
    var rotater = Entity()

    var transferValue: Float = 0

    var X: Float = 0
    var Y: Float = 0
    var Z: Float = 0

    var clipBoxXEnabled = false
    var clipBoxYEnabled = false
    var clipBoxZEnabled = false
    
    func updateAllAxis() {
        if (loading) {
            return
        }
        print("updating")
        updateAxis(axisList: &zNegativeEntities)
        updateAxis(axisList: &zPositiveEntities)
        updateAxis(axisList: &xNegativeEntities)
        updateAxis(axisList: &xPositiveEntities)
        updateAxis(axisList: &yNegativeEntities)
        updateAxis(axisList: &yPositiveEntities)
        print("updated")
    }
    
    func updateAxis(axisList: inout axisList) {
        loading = true
        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStep", value: MaterialParameters.Value.float(transferValue))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(X))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(Y))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(Z))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: 1, height: 1),
                materials: [axisList.materialEntity[i].material]
            ))
        }
        loading = false
    }
    
    func addEntities(root: Entity, axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            axisList.entity.addChild(axisList.materialEntity[i].entity)
        }
        root.addChild(axisList.entity)
        axises.append(axisList)
    }

    func setClipPlane() {
            clipBoxX.isEnabled = clipBoxXEnabled
            clipBoxY.isEnabled = clipBoxYEnabled
            clipBoxZ.isEnabled = clipBoxZEnabled
    }
    
    func reset() {
        root!.findEntity(named: "Rotater")!.transform.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 0, 0))
        clipBoxZ.position.z = -0.55
        clipBoxX.position.x = -0.55
        clipBoxY.position.y = -0.55
        X = 0
        Y = 0
        Z = 0
        clipBoxX.isEnabled = false
        clipBoxY.isEnabled = false
        clipBoxZ.isEnabled = false
        transferValue = 0
        updateAllAxis()
    }
}
