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
    
    if fold.is3D() {
      self.model = ModelMesh(
        device: self.device,
        vertices: fold.flat_vertices_coords(),
        triangles: fold.flat_faces_vertices().0)
    } else {
//      self.model = ModelCP(device: self.device, vertices: cp.0, triangles: cp.1)
//      let mx = self.camera.modelBounds.maxBounds
//      let min = self.camera.modelBounds.minBounds
//      let strokeWidth: Float = max(mx.x - min.x, mx.y - min.y, mx.z - min.z) / 50.0
      let edges_triangles = fold.thick_edges(surfaceNormal: simd_float3(0, 0, 1), strokeWidth: 0.005)
      self.model = ModelRaw(device: self.device, vertices: edges_triangles.0, triangles: edges_triangles.1)
    }
    // after a model is successfully loaded
    // build a pipeline using the mesh
    self.buildPipeline(is3D: fold.is3D(), view: mtkView, vertexDescriptor: self.model.vertexDescriptor)
    // set the camera zoom to fit the model
    self.camera.modelBounds = self.model.boundingBox
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
        
        // transparent background
        mtkView.layer?.isOpaque = false
        mtkView.layer?.backgroundColor = CGColor.clear

        mtkView.delegate = self
        
        camera = Camera(view: mtkView)
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

}
