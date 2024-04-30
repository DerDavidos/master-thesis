import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct axisList {
    var entity: Entity
    var materialEntity: [MaterialEntity]
    var axisName: String
}

@Observable
class AxisModell {
    var volumeModell: VolumeModell

    var rotater = Entity()
    
    var clipBoxX = Entity()
    var clipBoxY = Entity()
    var clipBoxZ = Entity()
    var clipBoxXEnabled = false
    var clipBoxYEnabled = false
    var clipBoxZEnabled = false
    
    var axises: [axisList] = Array()
    
    init(volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
    }
    
    @MainActor
    func enableAxis(axisName: String) {
        for axis in axises {
            if (axis.axisName == axisName) {
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
        
            for i in 0...axises.count-1 {
                updatMaterials(axisList: &axises[i])
                await updateAxis(axisList: &axises[i])
            }
       
            volumeModell.loading = false
        }
    }
    
    fileprivate func updatMaterials(axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStepStart", value: MaterialParameters.Value.float(volumeModell.smoothStepStart))
            try! axisList.materialEntity[i].material.setParameter(name: "smoothStepShift", value: MaterialParameters.Value.float(volumeModell.smoothStepShift))
            try! axisList.materialEntity[i].material.setParameter(name: "x", value: .float(volumeModell.XClip))
            try! axisList.materialEntity[i].material.setParameter(name: "y", value: .float(volumeModell.YClip))
            try! axisList.materialEntity[i].material.setParameter(name: "z", value: .float(volumeModell.ZClip))
        }
    }
    
    @MainActor
    fileprivate func updateAxis(axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
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
    func createEntityList() async {
        axises.removeAll()
        
        axises.append(axisList(entity: Entity(), materialEntity: [], axisName: "zPositive"))
        axises.append(axisList(entity: Entity(), materialEntity: [], axisName: "zNegative"))
        axises.append(axisList(entity: Entity(), materialEntity: [], axisName: "xPositive"))
        axises.append(axisList(entity: Entity(), materialEntity: [], axisName: "xNegative"))
        axises.append(axisList(entity: Entity(), materialEntity: [], axisName: "yPositive"))
        axises.append(  axisList(entity: Entity(), materialEntity: [], axisName: "yNegative"))
        
        let axisRenderer: AxisRenderer = AxisRenderer(dataset: volumeModell.dataset)
        for i in 0...axises.count-1 {
            axises[i].materialEntity = await axisRenderer.createEntities(axis: axises[i].axisName)
            addEntities(root: volumeModell.root!, axisList: &axises[i])
        }
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
        
        await createEntityList()

        volumeModell.root!.transform.translation = START_TRANSLATION
        
        volumeModell.updateTransformation(.identity)
        volumeModell.loading = false
    }
}
