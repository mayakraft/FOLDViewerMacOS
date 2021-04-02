//
//  FOLD.swift
//  FoldImport
//
//  Created by Robby on 2/25/21.
//

import Foundation
import simd

// make these not global variables
let colorMountain = simd_float3(0.8, 0.1, 0.05)
let colorValley = simd_float3(0.05, 0.1, 0.5)
let colorFlat = simd_float3(0.6, 0.6, 0.6)
let colorBoundary = simd_float3(0.0, 0.0, 0.0)
let colorUndefined = simd_float3(0.0, 0.0, 0.0)

let colorMap: [String: simd_float3] = [
  "M": colorMountain,
  "m": colorMountain,
  "V": colorValley,
  "v": colorValley,
  "F": colorFlat,
  "f": colorFlat,
  "B": colorBoundary,
  "b": colorBoundary,
  "U": colorUndefined,
  "u": colorUndefined
]

struct FOLDFormat: Decodable {
  let vertices_coords: [[Double]]?
  let vertices_vertices: [[Int]]?
  let vertices_edges: [[Int]]?
  let vertices_faces: [[Int]]?
  let edges_vertices: [[Int]]?
  let edges_assignment: [String]?
  let edges_foldAngle: [Double?]?
  let edges_edges: [[Int?]]?
  let edges_faces: [[Int?]]?
  let faces_vertices: [[Int]]?
  let faces_edges: [[Int]]?
  let faces_faces: [[Int]]?
}

// analysis section
extension FOLDFormat {
  // get the bounding box by iterating over all the vertices
  // this assumes that there are no normals/colors mixed in
  func boundingBox () -> (simd_float3, simd_float3) {
    var mins = Array(repeating: Double.infinity, count: 3)
    var maxs = Array(repeating: -Double.infinity, count: 3)
    self.vertices_coords?.forEach({ vertex in
      vertex.enumerated().forEach { (i, n) in
        if n < mins[i] { mins[i] = n }
        if n > maxs[i] { maxs[i] = n }
      }
    })
    let min = simd_float3(mins.map { $0 == Double.infinity ? 0.0 : $0 }.map { Float($0) })
    let max = simd_float3(maxs.map { $0 == -Double.infinity ? 0.0 : $0 }.map { Float($0) })
    return (min, max)
  }

  func surfaceNormal () -> simd_float3 {
    let vertices_coords = self.vertices_coords ?? []
    // if there are fewer than 3 vertices, or those three vertices are 2D, return +Z normal
    if vertices_coords.count < 3 { return simd_float3(0, 0, 1) }
    if vertices_coords[0].count < 3 || vertices_coords[1].count < 3 || vertices_coords[2].count < 3 {
      return simd_float3(0, 0, 1)
    }
    let points = [0, 1, 2]
      .map { vertices_coords[$0] }
      .map({ vertex -> [Float] in vertex.map { Float($0) } })
      .map { simd_float3($0[0], $0[1], $0[2]) }
    return normalize(cross(points[1] - points[0], points[2] - points[0]))
  }

  func is3D () -> Bool {
    let vertices_coords = self.vertices_coords ?? []
    if vertices_coords.count < 4 { return false }
    // before we cross product on all the 3D points, make sure the points
    // are even 3D to begin with.
    let isAny2D = vertices_coords.map { $0.count < 3 }.reduce(false) { $0 || $1 }
    // or, we could assume the 3rd dimension is 0.0 and proceed anyway
    if isAny2D { return false }
    let points = vertices_coords
      .map({ vertex -> [Float] in vertex.map { Float($0) } })
      .map { simd_float3($0[0], $0[1], $0[2]) }
    let planeNormal = cross(points[1] - points[0], points[2] - points[0])
    // todo, as long as these 3 points were unique...
    // todo, test the magnitude of planNormal. if near zero pick different vectors
    let vectors = points.map { $0 - points[0] }
    // test all vectors except for the first one (which is a null vector)
    // this evalutes coplanarity. negate it to answer "is this 3d?"
    return !vectors[1..<vectors.count]
      .map { dot($0, planeNormal) }
      .map { $0 < 1e-6 }
      .reduce(true) { $0 && $1 }
  }
  
  // this forces vertices into 3D
  func vertices_coords3D() -> [[Double]] {
    guard let vertices_coords = self.vertices_coords else { return [] }
    return vertices_coords.map { (vertex) -> [Double] in
      [0, 1, 2].map { i -> Double in vertex.indices.contains(i) ? vertex[i] : 0.0 }
    }
  }

  
  func facesSignedArea () -> [Double] {
    let vertices_coords = self.vertices_coords3D()
    let faces_vertices = self.faces_vertices ?? []
    let facePoints = faces_vertices.map { face -> [[Double]] in face.map { vertices_coords[$0] } }
    
    // todo: need to re-organize these to be able to process 3D coords
    var faces:[Double] = []
    for f in 0..<facePoints.count {
      var face:[Double] = []
      for i in 0..<facePoints[f].count {
        let j = (i + 1) % facePoints[f].count
        let ptA = facePoints[f][i]
        let ptB = facePoints[f][j]
        face.append(ptA[0] * ptB[1] - ptA[1] * ptB[0])
      }
      faces.append(face.reduce(0) { $0 + $1 })
    }
    return faces
  }
  
  // todo: this triangulate solution solves convex polygons only
  // need a solution for non-convex
  func triangulate () -> FOLDFormat {
    let faces_vertices = self.faces_vertices ?? []
    let new_faces_vertices: [[Int]] = faces_vertices.flatMap { face -> [[Int]] in
      // convert polygon to triangle strip
      let strip: [Int] = face
        .enumerated()
        .map { (i, _) -> Int in
          // make array 0, 1, -1, 2, -2, 3... map it to vertex indices
          let zigzag = ceil(Double(i) / 2.0) * (i % 2 == 0 ? -1 : 1)
          return (Int(zigzag) + face.count) % face.count
        }.map { face[$0] }
      // convert triangle strip into triangles
      return Array.init(repeating: 0, count: face.count - 2)
        .enumerated()
        .map { (i, _) -> [Int] in
          let triangle = [i, (i+1) % strip.count, (i+2) % strip.count].map { strip[$0] }
          return i % 2 == 0 ? triangle : triangle.reversed()
        }
    }

    return FOLDFormat(vertices_coords: self.vertices_coords,
                      vertices_vertices: self.vertices_vertices,
                      vertices_edges: self.vertices_edges,
                      vertices_faces: self.vertices_faces,
                      edges_vertices: self.edges_vertices,
                      edges_assignment: self.edges_assignment,
                      edges_foldAngle: self.edges_foldAngle,
                      edges_edges: self.edges_edges,
                      edges_faces: self.edges_faces,
                      faces_vertices: new_faces_vertices,
                      faces_edges: nil,
                      faces_faces: nil)
  }
}

extension FOLDFormat {
  
  func gpuCPTriangles (surfaceNormal: simd_float3, strokeWidth: Float) -> ([Float32], [UInt16], [Float32]) {
    let paperVertices = self.gpuVerticesCoords()
    let paperFaces = self.gpuFacesVertices().0
    let paperOffset: UInt16 = UInt16(paperVertices.count / 3)
    let paperColors: [Float32] = paperVertices.map { _ in 1.0 }
    let (thickVertices, thickTriangles, colors) = self.gpuThickEdges(surfaceNormal: surfaceNormal, strokeWidth: strokeWidth)
    // offset by the vertices that make the paper
    let trianglesShifted = thickTriangles.map { $0 + paperOffset }
    // combine arrays
    let allVertices = paperVertices + thickVertices
    let allFaces = paperFaces + trianglesShifted
    let allColors = paperColors + colors
    return (allVertices, allFaces, allColors)
  }

  // returns 3 flat arrays: 1. vertices-coords, 2. faces, 3. vertices-colors
  func gpuThickEdges (surfaceNormal: simd_float3, strokeWidth: Float) -> ([Float32], [UInt16], [Float32]) {
    guard let vertices_coords_nd = self.vertices_coords else { return ([], [], []) }
    guard let edges_vertices = self.edges_vertices else { return ([], [], []) }
    let edges_assignment: [String] = self.edges_assignment ?? []
    // hardcode vertices to be 3d. and convert to simd3 type
    let vertices_coords = vertices_coords_nd.map { (vertex) -> simd_float3 in
      simd_float3([0, 1, 2].map { vertex.indices.contains($0) ? Float(vertex[$0]) : 0.0 })
    }
    // the lines of the crease pattern
    let edges_vertices_coords = edges_vertices.map { edge_vertices -> [simd_float3] in
      edge_vertices.map { vertices_coords[$0] }
    }
    let edges_vector = edges_vertices_coords.map { $0[1] - $0[0] }
    let edges_cross = edges_vector
      .map { normalize(cross($0, surfaceNormal)) * strokeWidth }
    let thick_edges_vertices: [Float32] = edges_vertices_coords
      .enumerated()
      .map { (i:Int, e:[simd_float3]) -> [simd_float3] in ([
        e[0] + edges_cross[i],
        e[0] - edges_cross[i],
        e[1] + edges_cross[i],
        e[1] - edges_cross[i]
      ])}
      .reduce([]) { $0 + $1 }
      .map { v -> [Float32] in ([v.x, v.y, v.z]) }
      .reduce([]) { $0 + $1 }
    let triangles = edges_vertices
      .enumerated()
      .map({ (i: Int, _) -> [UInt16] in [0, 1, 2, 2, 1, 3]
        .map { UInt16($0 + i * 4) } })
      .reduce([]) { $0 + $1 }
    let assignments = edges_assignment.map { s -> simd_float3 in colorMap[s] ?? colorUndefined }
      .map { a -> [simd_float3] in [a, a, a, a] }
      .reduce([]) { $0 + $1 }
      .map { v -> [Float32] in ([v.x, v.y, v.z]) }
      .reduce([]) { $0 + $1 }
    return (thick_edges_vertices, triangles, assignments)
  }
  
  // this forces vertices into 3D
  func gpuVerticesCoords() -> [Float32] {
    return self.vertices_coords3D()
      .map { vertex -> [Float32] in vertex.map { Float32($0) } }
      .reduce([]) { $0 + $1 }
  }

  // this flattens the faces indices but makes no assumption about the
  // number of points in each face, so the second array is an array, one
  // index per face, how many points are in each face.
  func gpuFacesVertices() -> ([UInt16], [Int]) {
    guard let faces_vertices = self.faces_vertices else { return ([], []) }
    return (
      faces_vertices.flatMap { $0 }.map { UInt16($0) },
      faces_vertices.map { $0.count }
    )
  }

//  func edgesVerticesWithFaces() -> ([Float32], [UInt16]) {
//    guard let vertices_coords_nd = self.vertices_coords else { return ([], []) }
//    guard let edges_vertices_unsorted = self.edges_vertices else { return ([], []) }
//    guard let faces_vertices = self.faces_vertices else { return ([], []) }
//    // force vertices_coords to be 3D.
//    let vertices_coords = vertices_coords_nd.map { (vertex) -> [Float32] in
//      [0, 1, 2].map { i -> Float32 in vertex.indices.contains(i) ? Float32(vertex[i]) : 0.0 }
//    }
//    // sort edges_vertices so that at least every vertex is represented in the first position
//    // weird, i know. but we need this because of the way we are passing these arrays to the
//    // shader, and we need to reference a vertex in the faces by the first position in an edge.
//    var seen_vertices: [Bool] = Array.init(repeating: false, count: vertices_coords.count)
//    let edges_vertices:[[Int]] = edges_vertices_unsorted.map { edge -> [Int] in
//      let flip_edge = seen_vertices[edge[0]] && !seen_vertices[edge[1]]
//      seen_vertices[edge[ flip_edge ? 1 : 0 ]] = true
//      return flip_edge ? [edge[1], edge[0]] : edge
//    }
//    var new_vertices_indices:[Int] = Array.init(repeating: -1, count: vertices_coords.count)
//    edges_vertices.enumerated().forEach { (i, edge) in
//      new_vertices_indices[edge[0]] = i
//    }
////    print("new_vertices_indices \(new_vertices_indices)")
//    let edges_vertices_coords = edges_vertices.map { edge_vertices -> [[Float32]] in
//      edge_vertices.map { vertices_coords[$0] }
//    }
//    let edges_vertices_coords_flat: [Float32] = edges_vertices_coords
//      .reduce([]) { $0 + $1 }
//      .reduce([]) { $0 + $1 }
//
//    let faces_vertices_flat = faces_vertices.flatMap { $0 }
//      .map { new_vertices_indices[$0] }
//      .map { UInt16($0) }
//
//    return (edges_vertices_coords_flat, faces_vertices_flat)
//  }

  func obj () -> String {
    let vertices_coords = self.vertices_coords ?? []
    let faces_vertices = self.faces_vertices ?? []
    let vertices = vertices_coords.map { coords -> String in
      coords.map { n in
        String(n)
      }.reduce("v") { (a, b) in a + " " + b }
    }.reduce("") { (a, b) in a + "\n" + b }
    let faces = faces_vertices.map { face -> String in
      face.map { n in
        String(n)
      }.reduce("f") { (a, b) in a + " " + b }
    }.reduce("") { (a, b) in a + "\n" + b }
    return vertices + "\n" + faces
  }
}
