//
//  PolySpatialFPSView.swift
//  PolySpatialRealityKit
//
//  Created by Joe Jones on 9/16/22.
//

import SwiftUI

struct PolySpatialFPSView: View {

    @EnvironmentObject var stats: PolySpatialStatistics

    var body: some View {
        let label = "FPS: \(stats.currentFps)"
        Text(label)
    }
}

struct PolySpatialFPSView_Previews: PreviewProvider {
    static var previews: some View {
        PolySpatialFPSView()
    }
}
