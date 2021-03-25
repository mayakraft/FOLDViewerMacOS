//
//  ViewController.swift
//  FoldQuickLook
//
//  Created by Robby on 3/24/21.
//

import Cocoa
import Metal
import MetalKit

class ViewController: NSViewController {
  
  var renderer: Renderer!
  var metalView: MetalView!
  
  override func viewWillLayout() {
    super.viewWillLayout()
    metalView.frame = self.view.bounds
//    print("View bounds \(self.view.bounds)")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    renderer = Renderer()
    metalView = MetalView()
    renderer.mtkView = metalView
    self.view.addSubview(metalView)
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }

}

