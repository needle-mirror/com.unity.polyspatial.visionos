//
//  PolySpatialResourcesView.swift
//  PolySpatialRealityKit
//
//  Created by Joe Jones on 10/10/22.
//

import SwiftUI

struct PolySpatialResourcesView: View {
    @EnvironmentObject var stats: PolySpatialStatistics

    let kb = 1024
    let sizeNames = ["", "KB", "MB", "GB", "TB"]

    func formatMemory(from: Int) -> String {
        var remainder = from
        var sizeIndex = 0
        while remainder > kb {
            sizeIndex += 1
            remainder /= kb
        }
        return "\(remainder)\(sizeNames[sizeIndex])"
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Textures: \(stats.textureCount) ")
                Text("Estimated Memory: \(formatMemory(from: stats.estimatedTextureMemory))")
            }
            HStack {
                Text("Meshes: \(stats.meshCount)")
                Text("Estimated Memory: \(formatMemory(from: stats.estimatedMeshMemory))")
            }
            Text("Materials: \(stats.materialCount)")
        }
    }
}

struct PolySpatialResourcesView_Previews: PreviewProvider {
    static var previews: some View {
        PolySpatialResourcesView()
    }
}
