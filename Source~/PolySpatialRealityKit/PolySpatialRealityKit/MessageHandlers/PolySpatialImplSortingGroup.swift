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
        _ entity: PolySpatialEntity,
        _ sortingGroupInfo: UnsafeMutablePointer<PolySpatialSortingGroupData>?) {
        let info = sortingGroupInfo!.pointee

        if (!info.members.isEmpty) {
            // Always create new sort group - sort groups cannot be modified.
            if (customSortGroup[entity] != nil) {
                CleanUpSortingGroups(entity)
            }

            let sortGroup: ModelSortGroup = .init(depthPass: info.depthPass.rk())

            for member in info.members {
                guard let rendererEntity = entity.viewSubgraph.entities[member.renderer] else {
                    continue
                }

                setSortingGroupRecursively(entity,
                                           rendererEntity,
                                           sortGroup,
                                           member.sortOrder,
                                           member.shouldApplyDescendant,
                                           true)
            }
        }
    }

    func destroySortingGroup(_ entity : PolySpatialEntity) {
        CleanUpSortingGroups(entity)
    }

    func setSortingGroupRecursively(
        _ sortGroupEntity: PolySpatialEntity,
        _ currentEntity: PolySpatialEntity,
        _ sortGroup: ModelSortGroup,
        _ sortOrder: Int32,
        _ shouldRecurse: Bool,
        _ isAncestor: Bool) {

        currentEntity.setRendererSortingGroup(sortGroupEntity, sortGroup, sortOrder, shouldRecurse, isAncestor)

        if (!shouldRecurse) {
            return
        }

        for child in currentEntity.children {
            let pslEntity = child as! PolySpatialEntity
            // Backing entities mirror their owner's sort group, which may differ when the owner is a separate member.
            if pslEntity.isBackingEntity {
                continue
            }
            setSortingGroupRecursively(sortGroupEntity, pslEntity, sortGroup, sortOrder, shouldRecurse, false)
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

    func CleanUpSortingGroups(_ sortGroupEntity: PolySpatialEntity) {
        if let cachedMembers = customSortGroup[sortGroupEntity] {
            for member in cachedMembers {
                member.clearRendererSortingGroup()
            }
        }

        customSortGroup.removeValue(forKey: sortGroupEntity)
    }
}
