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
    var clipBoxXEnabled = false
    var clipBoxYEnabled = false
    var clipBoxZEnabled = false
    
    var root: Entity?
    var rotater = Entity()
    var transferValue: Float = 0
    var rotation: Angle = .zero

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
        let X = max(-0.5, min(clipBoxX.position.x, 0.5)) + 0.5
        let Y = max(-0.5, min(clipBoxY.position.y, 0.5)) + 0.5
        let Z = max(-0.5, min(clipBoxZ.position.z, 0.5)) + 0.5
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
        clipBoxXEnabled = false
        clipBoxYEnabled = false
        clipBoxZEnabled = false
        clipBoxX.isEnabled = false
        clipBoxY.isEnabled = false
        clipBoxZ.isEnabled = false
        transferValue = 0
        rotation = .zero
        
        rotate(X: 1, Y: 1)
        updateAllAxis()
    }
    
    func rotate(X: CGFloat, Y: CGFloat) {
        let angle = sqrt(pow(Y, 2) + pow(X, 2))
        rotation += Angle(degrees: Double(angle)) * 0.025
        let axisX = X / CGFloat(angle)
        let axisY = Y / CGFloat(angle)
        let rotationAxis = (x: axisX, y: axisY, z: 0)
        let quaternion = simd_quatf(
            angle: Float(rotation.radians),
            axis: SIMD3<Float>(x: Float(rotationAxis.x), y: Float(rotationAxis.y), z: Float(rotationAxis.z))
        )
        root!.orientation = quaternion
        root!.transform.translation = SIMD3<Float>(0, 1.6, -1.5)
    }
    
    @MainActor
    func loadAllEntities() async {
        let scene = try! await Entity(named: "Plane", in: realityKitContentBundle)
        
        root = scene.findEntity(named: "root")!
        
        rotater =  scene.findEntity(named: "Rotater")!
        rotater.components.set(InputTargetComponent())
        rotater.generateCollisionShapes(recursive: false)
        root!.addChild(rotater)

        clipBoxX =  scene.findEntity(named: "clipBoxX")!
        clipBoxX.isEnabled = false
        clipBoxY = scene.findEntity(named: "clipBoxY")!
        clipBoxY.isEnabled = false
        clipBoxZ = scene.findEntity(named: "clipBoxZ")!
        clipBoxZ.isEnabled = false
        root!.addChild(clipBoxX)
        root!.addChild(clipBoxY)
        root!.addChild(clipBoxZ)

        let axisRenderer: AxisRenderer = AxisRenderer()
        zPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "zPositive")
        addEntities(root: root!, axisList: &zPositiveEntities)
        zNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "zNegative")
        addEntities(root: root!, axisList: &zNegativeEntities)
        xPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "xPositive")
        addEntities(root: root!, axisList: &xPositiveEntities)

        xNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "xNegative")
        addEntities(root: root!, axisList: &xNegativeEntities)
        yPositiveEntities.materialEntity = await axisRenderer.getEntities(axis: "yPositive")
        addEntities(root: root!, axisList: &yPositiveEntities)
        yNegativeEntities.materialEntity = await axisRenderer.getEntities(axis: "yNegative")
        addEntities(root: root!, axisList: &yNegativeEntities)

        root!.transform.translation = SIMD3<Float>(0, 1.6, -1.5)
    }
}
