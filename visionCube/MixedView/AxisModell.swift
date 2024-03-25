import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

@Observable
class AxisModell {
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

    var rotation: Rotation3D = .identity
    var volumeModell: VolumeModell
    
    var translation: Vector3D = Vector3D(x: 0, y: -1800, z: -2000)
    
    init(volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
    }
    
    @MainActor
    func enableAxis(entity: Entity) {
        for axis in axises {
            if (axis.entity == entity) {
                axis.entity.isEnabled = true
            } else {
                axis.entity.isEnabled = false
            }
        }
    }
    
    func updateAllAxis() {
        if (!volumeModell.axisLoaded) {
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
    
    fileprivate func updateAxis(axisList: inout axisList) {

        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStep", value: MaterialParameters.Value.float(volumeModell.transferValue))
            try! axisList.materialEntity[i].material.setParameter(name: "smoothWidth", value: MaterialParameters.Value.float(volumeModell.transferValue2))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(volumeModell.X))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(volumeModell.Y))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(volumeModell.Z))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: 1, height: 1),
                materials: [axisList.materialEntity[i].material]
            ))
        }
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
        volumeModell.reset()
        
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
        
        translation = Vector3D(x: 0, y: -1800, z: -2000)
        
        rotate(rotation: .identity)
        updateAllAxis()
    }
    
    func rotate(rotation: Rotation3D) {
        let quaternion = simd_quatf(
           rotation
        )
        root!.orientation = quaternion
        volumeModell.rotation = rotation
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
    }
}

