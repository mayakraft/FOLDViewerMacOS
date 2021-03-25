//
//  Renderer.swift
//  MeshViewer
//
//  Created by Robby on 3/2/21.
//

import Foundation
import MetalKit
import ModelIO
import simd

struct Uniforms {
  var modelViewMatrix: float4x4
  var projectionMatrix: float4x4
}

class Renderer: NSObject, MTKViewDelegate {
  let device: MTLDevice!
  let commandQueue: MTLCommandQueue
  var depthStencilState: MTLDepthStencilState!
  var renderPipeline: MTLRenderPipelineState?
  var camera: Camera!
  var extraBuffer: UnsafeMutablePointer<Float32>?

  var model: Model!
  
  func loadFOLD (_ foldFile: FOLDFormat) {
    guard let mtkView = self.mtkView else { return }
    let fold = foldFile.triangulate()

//    print("loaded \(fold.is3D() ? "3D" : "2D") FOLD, vertices: \(fold.vertices_coords?.count ?? 0), edges: \(fold.edges_vertices?.count ?? 0), faces: \(fold.faces_vertices?.count ?? 0)")
//    print(fold.asOBJ())
    
    if fold.is3D() {
      self.model = ModelMesh(
        device: self.device,
        vertices: flattenVerticesCoords(fold).0,
        triangles: flattenFacesVertices(fold).0)
    } else {
//      let cp = edgesVerticesWithFaces(fold)
//      print("edges/vertices \(cp.0)")
//      print("new faces \(cp.1)")
//      self.model = ModelCP(device: self.device, vertices: cp.0, triangles: cp.1)
      let edges_triangles = makeEdgeValleyTriangles(fold, surfaceNormal: simd_float3(0, 0, 1), strokeWidth: 0.005)
      print("edge triangles \(edges_triangles)")
      self.model = ModelRaw(device: self.device, vertices: edges_triangles.0, triangles: edges_triangles.1)
    }
    // after a model is successfully loaded
    // build a pipeline using the mesh
//    self.buildPipeline(view: mtkView, vertexDescriptor: self.model.vertexDescriptor)
    self.buildPipeline(is3D: fold.is3D(), view: mtkView, vertexDescriptor: self.model.vertexDescriptor)
    // set the camera zoom to fit the model
    self.camera.modelBounds = self.model.boundingBox
    
//    let mx = self.camera.modelBounds.maxBounds
//    let min = self.camera.modelBounds.minBounds
//    let strokeWidth: Float = max(mx.x - min.x, mx.y - min.y, mx.z - min.z) / 50.0
//    _ = makeEdgeValleyTriangles(fold, surfaceNormal: simd_float3(0, 0, 1), strokeWidth: strokeWidth)

  }
  
  func loadExampleFile () {
//    let resource = Bundle.main.url(forResource: "huffman", withExtension: "fold")!
    let resource = Bundle.main.url(forResource: "crane", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simple", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simpler", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simple-4", withExtension: "fold")!
    guard let data = FileManager.default.contents(atPath: resource.path) else { return }
    do {
      let fold = try JSONDecoder().decode(FOLDFormat.self, from: data)
      loadFOLD(fold)
    } catch let error {
      print(error)
    }
  }

  // must set mtkView
  var mtkView: MTKGestureView? {
    didSet {
      if let mtkView = self.mtkView {
        mtkView.preferredFramesPerSecond = 60
        mtkView.enableSetNeedsDisplay = true
        mtkView.device = self.device
        mtkView.framebufferOnly = false
        mtkView.clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 0)
        mtkView.drawableSize = mtkView.frame.size
        mtkView.enableSetNeedsDisplay = true
        mtkView.isPaused = false
        mtkView.colorPixelFormat = .bgra8Unorm_srgb
        mtkView.depthStencilPixelFormat = .depth32Float
        
        mtkView.delegate = self
        
        camera = Camera(view: mtkView)
        
        loadExampleFile()
      }
    }
  }
  
  override init() {
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!

    let depthDesecriptor = MTLDepthStencilDescriptor()
    depthDesecriptor.depthCompareFunction = .lessEqual
    depthDesecriptor.isDepthWriteEnabled = true
    self.depthStencilState = device.makeDepthStencilState(descriptor: depthDesecriptor)

    super.init()
  }

  func buildPipeline(is3D: Bool, view: MTKView, vertexDescriptor: MTLVertexDescriptor) {
    guard let library = device.makeDefaultLibrary() else { fatalError("make library") }
    let pipelineDescriptor = MTLRenderPipelineDescriptor()
    pipelineDescriptor.vertexFunction = is3D
      ? library.makeFunction(name: "vertex_mesh")
      : library.makeFunction(name: "vertex_cp")
    pipelineDescriptor.fragmentFunction = is3D
      ? library.makeFunction(name: "fragment_mesh")
      : library.makeFunction(name: "fragment_cp")
    pipelineDescriptor.colorAttachments[0].pixelFormat = view.colorPixelFormat
    pipelineDescriptor.depthAttachmentPixelFormat = view.depthStencilPixelFormat
    // vertexDescriptor comes from the mesh
    pipelineDescriptor.vertexDescriptor = vertexDescriptor
    do {
      renderPipeline = try device.makeRenderPipelineState(descriptor: pipelineDescriptor)
    } catch let error { fatalError("MTLRenderPipelineDescriptor \(error)") }
  }

  func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}

  func draw(in view: MTKView) {
    guard let drawable = view.currentDrawable,
          let renderPipeline = self.renderPipeline,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          let renderPassDescriptor = view.currentRenderPassDescriptor,
          let commandEncoder = commandBuffer.makeRenderCommandEncoder(descriptor: renderPassDescriptor)
      else { return }

    commandEncoder.setDepthStencilState(depthStencilState)
    var uniforms = Uniforms(modelViewMatrix: camera.modelView,
                            projectionMatrix: camera.projection)
    commandEncoder.setVertexBytes(&uniforms, length: MemoryLayout<Uniforms>.size, index: 1)
    commandEncoder.setRenderPipelineState(renderPipeline)
    model.draw(commandEncoder: commandEncoder)
    commandEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }
  
  
  func makeEdgeValleyTriangles (_ fold: FOLDFormat, surfaceNormal: simd_float3, strokeWidth: Float) -> ([Float32], [UInt16]) {
    guard let vertices_coords_nd = fold.vertices_coords else { return ([], []) }
    guard let edges_vertices = fold.edges_vertices else { return ([], []) }
    // hardcode vertices to be 3d. and convert to simd3 type
    let vertices_coords = vertices_coords_nd.map { (vertex) -> simd_float3 in
      simd_float3([0, 1, 2].map { vertex.indices.contains($0) ? Float(vertex[$0]) : 0.0 })
    }
    let edges_vertices_coords = edges_vertices.map { edge_vertices -> [simd_float3] in
      edge_vertices.map { vertices_coords[$0] }
    }
    let edges_vector = edges_vertices_coords.map { $0[1] - $0[0] }
    let edges_cross = edges_vector
      .map { normalize(cross($0, surfaceNormal)) * strokeWidth }
    let thick_edges: [Float32] = edges_vertices_coords
      .map { [$0[0], $0[0], $0[1], $0[1]] }
      .enumerated()
      .map { (i:Int, e:[simd_float3]) -> [simd_float3] in ([
        e[0] + edges_cross[i],
        e[1] - edges_cross[i],
        e[2] + edges_cross[i],
        e[3] - edges_cross[i]
      ])}
      .reduce([]) { $0 + $1 }
      .map { v -> [Float32] in ([v.x, v.y, v.z]) }
      .reduce([]) { $0 + $1 }
    let triangles = edges_vertices
      .enumerated()
      .map({ (i: Int, _) -> [UInt16] in
        [0, 1, 2, 2, 1, 3].map { UInt16($0 + i * 4) }
      }).reduce([]) { $0 + $1 }
//    print("thick_edges \(thick_edges), triangles \(triangles)")
    return (thick_edges, triangles)
  }
  
  func flattenVerticesCoords(_ fold: FOLDFormat) -> ([Float32], Int) {
    guard let vertices_coords = fold.vertices_coords else { return ([], 0) }
    let vertices = vertices_coords.map { (vertex) -> [Float32] in
      [0, 1, 2].map { i -> Float32 in vertex.indices.contains(i) ? Float32(vertex[i]) : 0.0 }
    }.reduce([]) { $0 + $1 }
    return (vertices, 3)
  }
  
  func flattenFacesVertices(_ fold: FOLDFormat) -> ([UInt16], [Int]) {
    guard let faces_vertices = fold.faces_vertices else { return ([], []) }
    return (
      faces_vertices.flatMap { $0 }.map { UInt16($0) },
      faces_vertices.map { $0.count }
    )
  }

  func edgesVerticesWithFaces(_ fold: FOLDFormat) -> ([Float32], [UInt16]) {
    guard let vertices_coords_nd = fold.vertices_coords else { return ([], []) }
    guard let edges_vertices_unsorted = fold.edges_vertices else { return ([], []) }
    guard let faces_vertices = fold.faces_vertices else { return ([], []) }
    // force vertices_coords to be 3D.
    let vertices_coords = vertices_coords_nd.map { (vertex) -> [Float32] in
      [0, 1, 2].map { i -> Float32 in vertex.indices.contains(i) ? Float32(vertex[i]) : 0.0 }
    }
    // sort edges_vertices so that at least every vertex is represented in the first position
    // weird, i know. but we need this because of the way we are passing these arrays to the
    // shader, and we need to reference a vertex in the faces by the first position in an edge.
    var seen_vertices: [Bool] = Array.init(repeating: false, count: vertices_coords.count)
    let edges_vertices:[[Int]] = edges_vertices_unsorted.map { edge -> [Int] in
      let flip_edge = seen_vertices[edge[0]] && !seen_vertices[edge[1]]
      seen_vertices[edge[ flip_edge ? 1 : 0 ]] = true
      return flip_edge ? [edge[1], edge[0]] : edge
    }
    var new_vertices_indices:[Int] = Array.init(repeating: -1, count: vertices_coords.count)
    edges_vertices.enumerated().forEach { (i, edge) in
      new_vertices_indices[edge[0]] = i
    }
//    print("new_vertices_indices \(new_vertices_indices)")
    let edges_vertices_coords = edges_vertices.map { edge_vertices -> [[Float32]] in
      edge_vertices.map { vertices_coords[$0] }
    }
    let edges_vertices_coords_flat: [Float32] = edges_vertices_coords
      .reduce([]) { $0 + $1 }
      .reduce([]) { $0 + $1 }

    let faces_vertices_flat = faces_vertices.flatMap { $0 }
      .map { new_vertices_indices[$0] }
      .map { UInt16($0) }

    return (edges_vertices_coords_flat, faces_vertices_flat)
  }
  
}
