import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct axisList {
    var entity: Entity
    var materialEntity: [MaterialEntity]

}

@Observable
class AxisModell {
    var volumeModell: VolumeModell

    var root: Entity?
    
    var rotater = Entity()
    
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
    
    func updateTransformation(_ value: AffineTransform3D) {
        if root == nil {
            return
        }
        root!.orientation = simd_quatf(volumeModell.rotation.rotated(by: value.rotation!))
        
        root!.transform.translation.x = Float((volumeModell.translation.x + value.translation.x) / 1000)
        root!.transform.translation.y = Float((volumeModell.translation.y + value.translation.y) / -1000)
        root!.transform.translation.z = Float((volumeModell.translation.z + value.translation.z) / 1000)
        
//        var scale: Float = Float(value.scale.width * value.scale.height * value.scale.depth)
//        if scale > 1 { scale = (scale - 1) * 0.05 + 1 }
//        scale *= Float(volumeModell.scale)
//        root!.scale = SIMD3<Float>(scale, scale, scale)
    }
    
    func updateAllAxis() {
        if ((!volumeModell.axisLoaded) || !volumeModell.axisView) {
            return
        }
        volumeModell.loading = true
        print("updating")
        updateAxis(axisList: &zNegativeEntities)
        updateAxis(axisList: &zPositiveEntities)
        updateAxis(axisList: &xNegativeEntities)
        updateAxis(axisList: &xPositiveEntities)
        updateAxis(axisList: &yNegativeEntities)
        updateAxis(axisList: &yPositiveEntities)
        print("updated")
        volumeModell.loading = false
    }
    
    fileprivate func updateAxis(axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStepStart", value: MaterialParameters.Value.float(volumeModell.smoothStepStart))
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStepShift", value: MaterialParameters.Value.float(volumeModell.smoothStepShift))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(volumeModell.XClip))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(volumeModell.YClip))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(volumeModell.ZClip))
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: axisList.materialEntity[i].width, height: axisList.materialEntity[i].height),
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

    func setClipPlanes() {
        clipBoxX.isEnabled = clipBoxXEnabled
        clipBoxY.isEnabled = clipBoxYEnabled
        clipBoxZ.isEnabled = clipBoxZEnabled
    }
    
    func reset() {
        volumeModell.reset()
        
        clipBoxZ.position.z = -0.55
        clipBoxX.position.x = -0.55
        clipBoxY.position.y = -0.55
        clipBoxXEnabled = false
        clipBoxYEnabled = false
        clipBoxZEnabled = false
        setClipPlanes()
        
        updateTransformation(.identity)
        updateAllAxis()
    }
    
    @MainActor
    func loadAllEntities() async {
        volumeModell.loading = true
        let scene = try! await Entity(named: "Plane", in: realityKitContentBundle)
        
        root = scene.findEntity(named: "root")!
        
        rotater =  scene.findEntity(named: "Rotater")!
        rotater.components.set(InputTargetComponent())
        rotater.generateCollisionShapes(recursive: false)
        root!.addChild(rotater)

        clipBoxX = scene.findEntity(named: "clipBoxX")!
        clipBoxY = scene.findEntity(named: "clipBoxY")!
        clipBoxZ = scene.findEntity(named: "clipBoxZ")!
        setClipPlanes()
        
        root!.addChild(clipBoxX)
        root!.addChild(clipBoxY)
        root!.addChild(clipBoxZ)

        let axisRenderer: AxisRenderer = AxisRenderer(dataset: volumeModell.dataset)
        zPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "zPositive")
        addEntities(root: root!, axisList: &zPositiveEntities)
        zNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "zNegative")
        addEntities(root: root!, axisList: &zNegativeEntities)
        xPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "xPositive")
        addEntities(root: root!, axisList: &xPositiveEntities)

        xNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "xNegative")
        addEntities(root: root!, axisList: &xNegativeEntities)
        yPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "yPositive")
        addEntities(root: root!, axisList: &yPositiveEntities)
        yNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "yNegative")
        addEntities(root: root!, axisList: &yNegativeEntities)
        
        updateTransformation(.identity)
        volumeModell.loading = false
    }
}
