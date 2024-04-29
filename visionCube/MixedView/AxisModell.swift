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
    
    func updateAllAxis() {
        if ((!volumeModell.axisLoaded) || !volumeModell.axisView) {
            return
        }
        Task {
            volumeModell.loading = true
            await updateAxis(axisList: &zNegativeEntities)
            await updateAxis(axisList: &zPositiveEntities)
            await updateAxis(axisList: &xNegativeEntities)
            await updateAxis(axisList: &xPositiveEntities)
            await updateAxis(axisList: &yNegativeEntities)
            await updateAxis(axisList: &yPositiveEntities)
            volumeModell.loading = false
        }
    }
    
    @MainActor
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
    
    @MainActor
    func reset(selectedVolume: String) async {
        volumeModell.axisLoaded = false
        volumeModell.reset(selectedVolume: selectedVolume)
        await loadAllEntities()
        
        clipBoxZ.position.z = -0.55
        clipBoxX.position.x = -0.55
        clipBoxY.position.y = -0.55
        clipBoxXEnabled = false
        clipBoxYEnabled = false
        clipBoxZEnabled = false
        setClipPlanes()
        volumeModell.updateTransformation(.identity)
        
        volumeModell.axisLoaded = true
        updateAllAxis()
    }
    
    @MainActor
    func loadAllEntities() async {
        volumeModell.loading = true
        let scene = try! await Entity(named: "Plane", in: realityKitContentBundle)

        if (volumeModell.root == nil) {
            volumeModell.root = scene.findEntity(named: "root")!
        }
        volumeModell.root!.children.removeAll();
        
        rotater =  scene.findEntity(named: "Rotater")!
        rotater.components.set(InputTargetComponent())
        rotater.generateCollisionShapes(recursive: false)
        volumeModell.root!.addChild(rotater)

        clipBoxX = scene.findEntity(named: "clipBoxX")!
        clipBoxY = scene.findEntity(named: "clipBoxY")!
        clipBoxZ = scene.findEntity(named: "clipBoxZ")!
        setClipPlanes()
        
        volumeModell.root!.addChild(clipBoxX)
        volumeModell.root!.addChild(clipBoxY)
        volumeModell.root!.addChild(clipBoxZ)

         zPositiveEntities = axisList(entity: Entity(), materialEntity: [])
         zNegativeEntities = axisList(entity: Entity(), materialEntity: [])
         xPositiveEntities = axisList(entity: Entity(), materialEntity: [])
         xNegativeEntities = axisList(entity: Entity(), materialEntity: [])
         yPositiveEntities = axisList(entity: Entity(), materialEntity: [])
         yNegativeEntities = axisList(entity: Entity(), materialEntity: [])
        
        let axisRenderer: AxisRenderer = AxisRenderer(dataset: volumeModell.dataset)
        zPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "zPositive")
        addEntities(root: volumeModell.root!, axisList: &zPositiveEntities)
        zNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "zNegative")
        addEntities(root: volumeModell.root!, axisList: &zNegativeEntities)
        xPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "xPositive")
        addEntities(root: volumeModell.root!, axisList: &xPositiveEntities)

        xNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "xNegative")
        addEntities(root: volumeModell.root!, axisList: &xNegativeEntities)
        yPositiveEntities.materialEntity = await axisRenderer.createEntities(axis: "yPositive")
        addEntities(root: volumeModell.root!, axisList: &yPositiveEntities)
        yNegativeEntities.materialEntity = await axisRenderer.createEntities(axis: "yNegative")
        addEntities(root: volumeModell.root!, axisList: &yNegativeEntities)
        
        volumeModell.root!.transform.translation = START_TRANSLATION
        
        volumeModell.updateTransformation(.identity)
        volumeModell.loading = false
    }
}
