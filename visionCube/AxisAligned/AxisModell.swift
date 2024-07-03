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
    var rotater = Entity()
    
    var clipBoxX = Entity()
    var clipBoxY = Entity()
    var clipBoxZ = Entity()
    
    var lastX: Float = -0.55
    var lastY: Float = -0.55
    var lastZ: Float = -0.55
    
    var axises: [axisList] = Array()
    
    var root: Entity?
    
    var axisLoaded = false
    var oversampling = START_OVERSAMPLING
    
    var loadedVolume: String
    
    init(loadedVolume: String) {
        self.loadedVolume = loadedVolume
        resetClipPlanes()
    }
    
    @MainActor
    func enableAxis(axisName: String) {
        for axis in axises {
            if (axis.axisName == axisName) {
                axis.listEntity.isEnabled = true
            } else {
                axis.listEntity.isEnabled = false
            }
        }
    }
    
    func updateAllAxis(volumeModell: VolumeModell) async {
        if !axisLoaded {
            return
        }
        for i in 0...axises.count-1 {
            updatMaterials(axisList: &axises[i], volumeModell: volumeModell)
            await updateAxis(axisList: &axises[i])
        }
    }
    
    fileprivate func updatMaterials(axisList: inout axisList, volumeModell: VolumeModell) {
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
    
    @MainActor
    func addEntities(root: Entity, axisList: inout axisList) {
        for i in 0...axisList.materialEntity.count - 1 {
            axisList.listEntity.addChild(axisList.materialEntity[i].entity)
        }
        root.addChild(axisList.listEntity)
    }
    
    func resetClipPlanes() {
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
    func createEntityList(dataset: QVis, loadedVolume: String) async {
        self.loadedVolume = loadedVolume
        
        axises.removeAll()
        
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "zPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "zNegative"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "xPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "xNegative"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "yPositive"))
        axises.append(axisList(listEntity: Entity(), materialEntity: [], axisName: "yNegative"))
        
        let axisRenderer: AxisRenderer = AxisRenderer(dataset: dataset)
        for i in 0...axises.count-1 {
            axises[i].materialEntity = await axisRenderer.createEntities(axis: axises[i].axisName, oversampling: oversampling)
            addEntities(root: root!, axisList: &axises[i])
        }
    }
    
    @MainActor
    func loadAllEntities() async {
        let scene = try! await Entity(named: "Plane", in: realityKitContentBundle)
        
        if (root == nil) {
            root = scene.findEntity(named: "root")!
        }
        root!.children.removeAll();
        
        rotater = scene.findEntity(named: "Rotater")!
        rotater.components.set(InputTargetComponent())
        rotater.generateCollisionShapes(recursive: false)
        root!.addChild(rotater)
        
        clipBoxX = scene.findEntity(named: "clipBoxX")!
        clipBoxY = scene.findEntity(named: "clipBoxY")!
        clipBoxZ = scene.findEntity(named: "clipBoxZ")!
        resetClipPlanes()
        
        root!.addChild(clipBoxX)
        root!.addChild(clipBoxY)
        root!.addChild(clipBoxZ)
    }
}
