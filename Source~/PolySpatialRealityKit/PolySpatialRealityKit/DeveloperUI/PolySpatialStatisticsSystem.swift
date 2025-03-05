//
//  PolySpatialStatisticsSystem.swift
//  PolySpatialRealityKit
//
//  Created by Joe Jones on 9/16/22.
//

import Foundation
import RealityKit

class PolySpatialStatisticsSystem: System {
    required init(scene: Scene) {
    }

    func update(context: SceneUpdateContext) {
        if PolySpatialStatistics.shared.displayOverlay {
            PolySpatialStatistics.shared.updateStatistics()
        }
    }
}
