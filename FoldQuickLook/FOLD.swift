//
//  FOLD.swift
//  FoldImport
//
//  Created by Robby on 2/25/21.
//

import Foundation
import simd

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

  func asOBJ () -> String {
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
    let vecA = points[1] - points[0]
    let vecB = points[2] - points[0]
    let planeNormal = cross(vecA, vecB)
    // todo, as long as these 3 points were unique...
    // todo, test the magnitude of planNormal. if near zero pick different vectors
//    print("plane normal magnitude \(length(planeNormal))")
    let vectors = points.map { $0 - points[0] }
    // test all vectors except for the first one (which is a null vector)
    let subvectors = vectors[1..<vectors.count]
    let dots = subvectors.map { dot($0, planeNormal) }
    let coplanar = dots.map { $0 < 1e-6 }.reduce(true) { $0 && $1 }
    return !coplanar
  }
  
  func triangulate () -> FOLDFormat {
    let faces_vertices = self.faces_vertices ?? []
    let new_faces_vertices: [[Int]] = faces_vertices.flatMap { face -> [[Int]] in
      // convert to triangle strip
      let strip: [Int] = face.enumerated()
        .map { (i, _) -> Int in
          let zigzag = ceil(Double(i) / 2.0) * (i % 2 == 0 ? -1 : 1)
          return (Int(zigzag) + face.count) % face.count
        }.map { face[$0] }
      // convert triangle strip into triangles
      // (remember to alterate winding directions)
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

  /*
  func triangulate() -> FOLDFormat {
    guard let fold_vertices_coords = self.vertices_coords else { return self }
    guard let fold_faces_vertices = self.faces_vertices else { return self }

    let vertices_count: Int32 = Int32(fold_vertices_coords.count)
    let faces_count: Int32 = Int32(fold_faces_vertices.count)
    let flatVertices = flattenVerticesCoords(self)
    let flatFaces = flattenFacesVertices(self)

    let vertices_coords = flatVertices.0.map { Float($0) }
    let vertices_dimension: Int32 = Int32(flatVertices.1)
    let faces_vertices = flatFaces.0.map { Int32($0) }
    let faces_face_vertices_count = flatFaces.1.map { Int32($0) }
    let faces_vertices_count: Int32 = Int32(faces_vertices.count)

    let vertices_coords_pointer = UnsafeMutablePointer<Float>.allocate(capacity: vertices_coords.count)
    for i in 0..<vertices_coords.count {
      vertices_coords_pointer.advanced(by: i).pointee = vertices_coords[i]
    }
    let faces_face_vertices_count_pointer = UnsafeMutablePointer<Int32>.allocate(capacity: faces_face_vertices_count.count)
    for i in 0..<faces_face_vertices_count.count {
      faces_face_vertices_count_pointer.advanced(by: i).pointee = faces_face_vertices_count[i]
    }
    let faces_vertices_pointer = UnsafeMutablePointer<Int32>.allocate(capacity: faces_vertices.count)
    for i in 0..<faces_vertices.count {
      faces_vertices_pointer.advanced(by: i).pointee = faces_vertices[i]
    }

//    print("vertices_coords_pointer", vertices_coords_pointer)
//    print("vertices_count", vertices_count)
//    print("vertices_dimension", vertices_dimension)
//    print("faces_vertices_pointer", faces_vertices_pointer)
//    print("faces_count", faces_count)
//    print("faces_vertices_count", faces_vertices_count)
//    print("faces_face_vertices_count_pointer", faces_face_vertices_count_pointer)

//    var return_triangle_count: Int32 = 0
//    var return_triangle_array: UnsafeMutablePointer<Int32>
//    var return_triangle_array: Int32 = 0
        
    let mesh: TessData = triangulate_mesh(
      vertices_coords_pointer,
      vertices_count,
      vertices_dimension,
      faces_vertices_pointer,
      faces_count,
      faces_vertices_count,
      faces_face_vertices_count_pointer)
    
//    print(mesh)
    
    let new_vertices_coords = Array<[Double]>(repeating: [],
                                             count: Int(mesh.vertex_array_count))
      .enumerated()
      .map {[
        Double(mesh.vertex_array[$0.offset * 3 + 0]),
        Double(mesh.vertex_array[$0.offset * 3 + 1]),
        Double(mesh.vertex_array[$0.offset * 3 + 2])
      ]}
    
    let new_faces_vertices = Array<[Int]>(repeating: [],
                                             count: Int(mesh.triangle_array_count))
      .enumerated()
      .map {[
        Int(mesh.triangle_array[$0.offset * 3 + 0]),
        Int(mesh.triangle_array[$0.offset * 3 + 1]),
        Int(mesh.triangle_array[$0.offset * 3 + 2])
      ]}
//    print("new_vertices_coords", new_vertices_coords)
//    print("new_faces_vertices", new_faces_vertices)

    return FOLDFormat(vertices_coords: new_vertices_coords,
                      vertices_vertices: nil,
                      vertices_edges: nil,
                      vertices_faces: nil,
                      edges_vertices: nil,
                      edges_assignment: nil,
                      edges_foldAngle: nil,
                      edges_edges: nil,
                      edges_faces: nil,
                      faces_vertices: new_faces_vertices,
                      faces_edges: nil,
                      faces_faces: nil)

//    let tris = UnsafeMutableBufferPointer<Int32>(start: return_triangle_array, count: Int(return_triangle_count))
//    let tris = return_triangle_array
//    var triangles:[[Int]] = [];
//    for i in 0..<return_triangle_count {
//      triangles.append([0, 1, 2].map { Int(tris[Int(i) * 3 + $0]) })
//    }
//
////    print("final triangles", triangles)
////    free(return_triangle_array)
//
//    return FOLDFormat(vertices_coords: self.vertices_coords,
//                      vertices_vertices: self.vertices_vertices,
//                      vertices_edges: self.vertices_edges,
//                      vertices_faces: nil,
//                      edges_vertices: self.edges_vertices,
//                      edges_assignment: self.edges_assignment,
//                      edges_foldAngle: self.edges_foldAngle,
//                      edges_edges: self.edges_edges,
//                      edges_faces: self.edges_faces,
//                      faces_vertices: triangles,
//                      faces_edges: nil,
//                      faces_faces: nil)
  }
 
 */

}
