import SwiftUI
import RealityKit

struct PolySpatialDebugHierarchyView: View {
    struct Node: Hashable, Identifiable, CustomStringConvertible {
        let id = UUID()
        let name: String
        let position: simd_float3
        let orientation: simd_float3
        let scale: simd_float3
        let entity: Entity

        var children: [Node]? {
            get {
                var children: [Node] = []

                for childEntity in entity.children {
                    children.append(Node(entity: childEntity))
                }
                return children
            }
        }

        init(entity: Entity) {
            self.name = entity.name
            self.position = entity.position
            self.orientation = entity.orientation.eulerAngles()
            self.scale = entity.scale
            self.entity = entity
        }

        var description: String {
            switch children {
            case nil:
                return "\(name)"
            case .some(let children):
                return children.isEmpty ? "-\(name)" : "+\(name)"
            }
        }
    }

    @State var roots: [Node] = []

    public init() {

    }

    public var body: some View {
        HStack(alignment: .top) {
            Button(self.roots.isEmpty ? "Dump Hierachy" : "Update Hierarchy") {
                for viewSubGraph in PolySpatialRealityKit.instance.viewSubGraphs {
                    if let viewSubGraph = viewSubGraph {
                        self.roots.append(Node(entity: viewSubGraph.root))
                    }
                }
            }.padding(5)
            Button("Clear Hierarchy") {
                self.roots = []
            }.padding(5)
        }
        Spacer()
        if !roots.isEmpty {
            List {
                ForEach(roots) { root in
                    OutlineGroup(root, children: \.children) { node in
                        VStack(alignment: .leading) {
                            Text(node.name)
                            
                            let font  = Font.system(size: 10)
                            let pos = node.position
                            Text("X:\(pos.x, specifier: "%.2f") Y:\(pos.y, specifier: "%.2f") Z:\(pos.z, specifier: "%.2f")").font(font)
                            
                            let angles = node.orientation
                            Text("X:\(angles.x, specifier: "%.2f") Y:\(angles.y, specifier: "%.2f") Z:\(angles.z, specifier: "%.2f")").font(font)
                            
                            let s = node.scale
                            Text("X:\(s.x, specifier: "%.2f") Y:\(s.y, specifier: "%.2f") Z:\(s.z, specifier: "%.2f")").font(font)
                        }
                    }
                }
            }.padding()
                .frame(minWidth: 150, maxWidth: 300, alignment: .leading)
                .opacity(0.7)
        }
    }
}

struct PolySpatialHierarchyView_Previews: PreviewProvider {
    static var previews: some View {
        PolySpatialDebugHierarchyView()
    }
}
