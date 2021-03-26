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

  
  func loadExampleFile () {
//    let resource = Bundle.main.url(forResource: "huffman", withExtension: "fold")!
    let resource = Bundle.main.url(forResource: "crane", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simple", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simpler", withExtension: "fold")!
//    let resource = Bundle.main.url(forResource: "simple-4", withExtension: "fold")!
    guard let data = FileManager.default.contents(atPath: resource.path) else { return }
    do {
      let fold = try JSONDecoder().decode(FOLDFormat.self, from: data)
      renderer.loadFOLD(fold)
    } catch let error {
      print(error)
    }
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    renderer = Renderer()
    metalView = MetalView()
    renderer.mtkView = metalView

    if let vfxview = self.view as? NSVisualEffectView {
      vfxview.blendingMode = .behindWindow
      vfxview.isEmphasized = true
      vfxview.material = .underWindowBackground
    }

    self.view.addSubview(metalView)
 
//    loadExampleFile()
  }

  override var representedObject: Any? {
    didSet {
    // Update the view, if already loaded.
    }
  }

}

