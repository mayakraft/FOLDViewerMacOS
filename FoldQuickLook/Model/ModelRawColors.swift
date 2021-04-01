//
//  ModelRawColors.swift
//  FoldQuickLook
//
//  Created by Robby on 4/1/21.
//

import Foundation
import MetalKit

// make a mesh by providing the raw data:
// vertices and faces, as an array of floats and ints
// this is hard-coded to use mesh triangles (not tri-strips)
// but it can be easily extended to lines/strips/...
class ModelRawColors: Model {
  var vertexBuffer: MTLBuffer!
  var triangleBuffer: MTLBuffer!
  var trianglesCount: Int = 0

  // get the bounding box by iterating over all the vertices
  // this assumes that there are no normals/colors mixed in
  override var boundingBox: MDLAxisAlignedBoundingBox {
    get {
      let vertices = vertexBuffer.contents().assumingMemoryBound(to: Float32.self)
      let verticesLength = vertexBuffer.length / MemoryLayout<Float32>.size
      var mins = vector_float3(repeating: Float.infinity)
      var maxs = vector_float3(repeating: -Float.infinity)
      for i in 0..<(verticesLength / 6) {
        // three dimensions, hardcoded in a vertex/normal strided array
        for d in 0..<3 {
          if vertices[i*6+d] < mins[d] { mins[d] = vertices[i*6+d] }
          if vertices[i*6+d] > maxs[d] { maxs[d] = vertices[i*6+d] }
        }
      }
//      print("bounding box \(maxs), \(mins)")
      return MDLAxisAlignedBoundingBox(maxBounds: maxs, minBounds: mins)
    }
  }

  init(device: MTLDevice, vertices: [Float32], triangles: [UInt16], colors: [Float32]) {
    super.init(device: device)
    loadArrays(vertices: vertices, triangles: triangles, colors: colors)
  }

  internal func loadArrays(vertices: [Float32], triangles: [UInt16], colors: [Float32]) {
//    let verticesPointer = UnsafeMutablePointer<Float32>.allocate(capacity: vertices.count)
    let trianglesPointer = UnsafeMutablePointer<UInt16>.allocate(capacity: triangles.count)
    let pointer = UnsafeMutablePointer<Float32>.allocate(capacity: vertices.count * 2)
    for i in 0..<(vertices.count/3) {
      pointer[i*6 + 0] = vertices[i*3 + 0]
      pointer[i*6 + 1] = vertices[i*3 + 1]
      pointer[i*6 + 2] = vertices[i*3 + 2]
      pointer[i*6 + 3] = colors[i*3 + 0]
      pointer[i*6 + 4] = colors[i*3 + 1]
      pointer[i*6 + 5] = colors[i*3 + 2]
    }
//    vertices.enumerated().forEach { verticesPointer[$0.offset] = $0.element }
    triangles.enumerated().forEach { trianglesPointer[$0.offset] = $0.element }
    vertexBuffer = device.makeBuffer(bytes: pointer,
//                                     length: MemoryLayout<Float32>.size * vertices.count,
                                     length: MemoryLayout<Float32>.size * vertices.count * 2,
                                     options: [])
    triangleBuffer = device.makeBuffer(bytes: trianglesPointer,
                                       length: MemoryLayout<UInt16>.size * triangles.count,
                                       options: [])
    trianglesCount = triangles.count / 3
    vertexDescriptor = MTLVertexDescriptor()
    vertexDescriptor.attributes[0].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[0].bufferIndex = 0
    vertexDescriptor.attributes[0].offset = 0
    vertexDescriptor.attributes[1].format = MTLVertexFormat.float3
    vertexDescriptor.attributes[1].bufferIndex = 0
    vertexDescriptor.attributes[1].offset = MemoryLayout<Float32>.size * 3
//    vertexDescriptor.layouts[0].stride = MemoryLayout<Float32>.size * 3
    vertexDescriptor.layouts[0].stride = MemoryLayout<Float32>.size * 6
  }

  override func draw(commandEncoder: MTLRenderCommandEncoder) {
    commandEncoder.setVertexBuffer(vertexBuffer, offset: 0, index: 0)
    commandEncoder.drawIndexedPrimitives(type: MTLPrimitiveType.triangle,
                                         indexCount: trianglesCount * 3,
                                         indexType: MTLIndexType.uint16,
                                         indexBuffer: triangleBuffer,
                                         indexBufferOffset: 0)
  }
}
