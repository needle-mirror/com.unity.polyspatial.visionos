import Foundation
import RealityKit

extension PolySpatialSortingDepthPass {
    func rk() -> ModelSortGroup.DepthPass? {
        switch (self) {
            case .postPass: return .postPass
            case .prePass: return .prePass
            case .unseparated: return nil
        }
    }
}

extension PolySpatialRealityKit {
    func createOrUpdateSortingGroup(
        _ id: PolySpatialInstanceID,
        _ sortingGroupInfo: UnsafeMutablePointer<PolySpatialSortingGroupData>?) {
        let info = sortingGroupInfo!.pointee

        if (info.hasMembers) {
            // Always create new sort group - sort groups cannot be modified.
            if (customSortGroup[id] != nil) {
                CleanUpSortingGroups(id)
            }

            let sortGroup: ModelSortGroup = .init(depthPass: info.depthPass.rk())
            
            for member in info.membersAsBuffer! {
                // TODO LXR-1776: Need to fix up remapper on PolySpatialIDRemapper, then we can remove this hack.
                let remappedMember = PolySpatialInstanceID(id: member.renderer.id, hostId: id.hostId, hostVolumeIndex: id.hostVolumeIndex)
                guard let rendererEntity = TryGetEntity(remappedMember) else {
                    continue
                }

                setSortingGroupRecursively(id,
                                           rendererEntity,
                                           sortGroup,
                                           member.sortOrder,
                                           member.shouldApplyDescendant,
                                           true)
            }
        }
    }
    
    func destroySortingGroup(_ id : PolySpatialInstanceID) {
        CleanUpSortingGroups(id)
    }

    func setSortingGroupRecursively(
        _ sortGroupEntityId: PolySpatialInstanceID,
        _ currentEntity: PolySpatialEntity,
        _ sortGroup: ModelSortGroup,
        _ sortOrder: Int32,
        _ shouldRecurse: Bool,
        _ isAncestor: Bool) {

        currentEntity.setRendererSortingGroup(sortGroupEntityId, sortGroup, sortOrder, shouldRecurse, isAncestor)

        if (!shouldRecurse) {
            return
        }

        for child in currentEntity.children {
            let pslEntity = child as! PolySpatialEntity
            setSortingGroupRecursively(sortGroupEntityId, pslEntity, sortGroup, sortOrder, shouldRecurse, false)
        }
    }

    func clearInheritedSortingGroupRecursively(_ currentEntity: PolySpatialEntity) {
        guard let sortGroupInfo = currentEntity.components[PolySpatialComponents.ModelSortGroupInfo.self],
            sortGroupInfo.overrideAppliesToDescendants,
            !sortGroupInfo.overrideIsAncestor else {
            return
        }
        currentEntity.clearRendererSortingGroup()

        for child in currentEntity.children {
            let pslEntity = child as! PolySpatialEntity
            clearInheritedSortingGroupRecursively(pslEntity)
        }
    }

    func CleanUpSortingGroups(_ id: PolySpatialInstanceID) {
        if let cachedMembers = customSortGroup[id] {
            for member in cachedMembers {
                guard let memberEntity = TryGetEntity(member) else {
                    continue
                }

                memberEntity.clearRendererSortingGroup()
            }
        }

        customSortGroup.removeValue(forKey: id)
    }
}
