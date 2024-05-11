import Foundation
import SwiftUI
import RealityKit
import RealityKitContent
import ARKit
import Accelerate

struct axisList {
    var listEntity: Entity
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
    
    var lastX: Float = -0.55
    var lastY: Float = -0.55
    var lastZ: Float = -0.55
    
    var axises: [axisList] = Array()
    
    init(volumeModell: VolumeModell) {
        self.volumeModell = volumeModell
        resetClipPlanes()
    }
    
    @MainActor
    func enableAxis(axisName: String) {
//        print(axisName)
        for axis in axises {
            if (axis.axisName == axisName) {
                axis.listEntity.isEnabled = true
            } else {
                axis.listEntity.isEnabled = false
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
    fileprivate func updateAxis(axisList: inout axisList) async {
        for i in 0...axisList.materialEntity.count - 1 {
            axisList.materialEntity[i].entity.components.set(ModelComponent(
                mesh: .generatePlane(width: axisList.materialEntity[i].width, height: axisList.materialEntity[i].height),
                materials: [axisList.materialEntity[i].material]
            ))
        }
    }
    
    func addEntities(root: Entity, axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            axisList.listEntity.addChild(axisList.materialEntity[i].entity)
        }
        root.addChild(axisList.listEntity)
        axises.append(axisList)
    }

    fileprivate func resetClipPlanes() {
        print("reset")
        clipBoxZ.position.z = -0.55
        clipBoxX.position.x = -0.55
        clipBoxY.position.y = -0.55
        clipBoxX.isEnabled = false
        clipBoxY.isEnabled = false
        clipBoxZ.isEnabled = false
        lastX = -0.55
        lastY = -0.55
        lastZ = -0.55
    }
    
    @MainActor
    func reset(selectedVolume: String) async {
        volumeModell.axisLoaded = false
        volumeModell.reset(selectedVolume: selectedVolume)
        
        await loadAllEntities()
        
        volumeModell.updateTransformation(.identity)
        
        volumeModell.axisLoaded = true
        updateAllAxis()
    }
    
    @MainActor
    func createEntityList() async {
        axises.removeAll()
        
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "zPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "zNegative"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "xPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "xNegative"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "yPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "yNegative"))
        
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

        rotater = scene.findEntity(named: "Rotater")!
        rotater.components.set(InputTargetComponent())
        rotater.generateCollisionShapes(recursive: false)
        volumeModell.root!.addChild(rotater)

        clipBoxX = scene.findEntity(named: "clipBoxX")!
        clipBoxY = scene.findEntity(named: "clipBoxY")!
        clipBoxZ = scene.findEntity(named: "clipBoxZ")!
        resetClipPlanes()
        
        volumeModell.root!.addChild(clipBoxX)
        volumeModell.root!.addChild(clipBoxY)
        volumeModell.root!.addChild(clipBoxZ)
        
        await createEntityList()

        volumeModell.root!.transform.translation = START_TRANSLATION
        
        volumeModell.updateTransformation(.identity)
        volumeModell.loading = false
    }
}
