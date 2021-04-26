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

  var model: Model?
  
  // must set mtkView
  weak var mtkView: MTKGestureView? {
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
        
        if camera == nil { camera = Camera(view: mtkView) }
      }
    }
  }
  
  func loadFOLD (_ foldFile: FOLDFormat) {
    guard let mtkView = self.mtkView else { return }
    let fold = foldFile.triangulate()

//    print("loaded \(fold.is3D() ? "3D" : "2D") FOLD, vertices: \(fold.vertices_coords?.count ?? 0), edges: \(fold.edges_vertices?.count ?? 0), faces: \(fold.faces_vertices?.count ?? 0)")
    
    // is the model a 3D model (treat it as a mesh)
    if fold.is3D() {
      self.model = ModelMesh(
        device: self.device,
        vertices: fold.gpuVerticesCoords(),
        triangles: fold.gpuFacesVertices().0)
    } else {
      // is the model flat (treat it as a crease pattern)
      // determine stroke width based on model size
      let (mins, maxs) = fold.boundingBox()
      let surfaceNormal = fold.surfaceNormal()
      let strokeWidth: Float = max(maxs.x - mins.x, maxs.y - mins.y, maxs.z - mins.z) / 500.0
      let edges_triangles = fold.gpuCPTriangles(surfaceNormal: surfaceNormal, strokeWidth: strokeWidth)
      // determine orientation, align all flat crease patterns directly at camera
      let transform = simd_quaternion(simd_float3(0, 0, 1), surfaceNormal)
      camera.modelOrientation = transform
      self.model = ModelRawColors(device: self.device, vertices: edges_triangles.0, triangles: edges_triangles.1, colors: edges_triangles.2)
    }
    // after a model is successfully loaded
    // build a pipeline using the mesh
    self.buildPipeline(is3D: fold.is3D(), view: mtkView, vertexDescriptor: self.model!.vertexDescriptor)
    // set the camera zoom to fit the model
    self.camera.modelBounds = self.model!.boundingBox
    // hack to make 2D models fit the window better
    // we need to move this into 3D modelsl too, but radius should be calculated
    // taking into consideration the widening in the perspective projection
    if !fold.is3D() { self.camera.modelRadius *= 0.75 }
  }
  
  override init() {
    self.device = MTLCreateSystemDefaultDevice()!
    self.commandQueue = device.makeCommandQueue()!
    super.init()
  }
  
  func deallocMesh() {
    print("deallocating mesh")
    self.model?.cleanup()
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
    // depth is dependent on the model being 3D
    let depthDesecriptor = MTLDepthStencilDescriptor()
    depthDesecriptor.isDepthWriteEnabled = is3D
    depthDesecriptor.depthCompareFunction = .lessEqual
    self.depthStencilState = device.makeDepthStencilState(descriptor: depthDesecriptor)
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
    model?.draw(commandEncoder: commandEncoder)
    commandEncoder.endEncoding()
    commandBuffer.present(drawable)
    commandBuffer.commit()
  }

}
