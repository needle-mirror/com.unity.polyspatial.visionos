//
//  PolySpatialStatisticsView.swift
//  PolySpatialRealityKit
//
//  Created by Joe Jones on 9/16/22.
//

import SwiftUI

struct PolySpatialStatisticsView: View {
    public init() {}
    public var body: some View {
        VStack(alignment: .leading) {
            PolySpatialFPSView().environmentObject(PolySpatialStatistics.shared).padding(5)
            PolySpatialResourcesView().environmentObject(PolySpatialStatistics.shared).padding(5)
        }
    }
}

struct PolySpatialStatisticsView_Previews: PreviewProvider {
    static var previews: some View {
        PolySpatialStatisticsView()
    }
}
