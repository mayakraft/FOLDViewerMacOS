//
//  PreviewViewController.swift
//  FOLDPreview
//
//  Created by Robby on 3/24/21.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
  
  var metalView: MetalView?
  var renderer: Renderer?
  var cumulativeTranslation: NSPoint = .zero

  override var nibName: NSNib.Name? {
    return NSNib.Name("PreviewViewController")
  }

  override func viewWillLayout() {
    super.viewWillLayout()
    metalView?.frame = self.view.bounds
  }

  @objc func touchMoved(target: NSPanGestureRecognizer) {
    guard let metalView = self.metalView else { return }
    let translate = target.translation(in: metalView)
    let cumulative = NSPoint(x: cumulativeTranslation.x + translate.x,
                             y: cumulativeTranslation.y + translate.y)
    metalView.touchDelegate?.didDrag(x: Float(cumulative.x), y: Float(cumulative.y))
    switch target.state {
      case .ended: cumulativeTranslation = cumulative
      case .cancelled: cumulativeTranslation = cumulative
      default: break
    }
  }

  override func loadView() {
    super.loadView()
    let panGesture = NSPanGestureRecognizer(target: self, action: #selector(touchMoved))
    self.view.addGestureRecognizer(panGesture)
  }

  /*
   * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
   *
  func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
      // Perform any setup necessary in order to prepare the view.
      
      // Call the completion handler so Quick Look knows that the preview is fully loaded.
      // Quick Look will display a loading spinner while the completion handler is not called.
      handler(nil)
  }
   */

  func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
    // only create renderer and metal view if they don't yet exist
    if self.renderer == nil { self.renderer = Renderer() }
    guard let renderer = self.renderer else { return }
    if self.metalView == nil {
      self.metalView = MetalView()
      self.view.addSubview(self.metalView!)
      renderer.mtkView = self.metalView!
    }

    // load the file contents, do not proceed if there is an error
    guard let data = FileManager.default.contents(atPath: url.path) else {
      return handler(NSError(domain: NSCocoaErrorDomain,
                             code: NSFileReadUnknownError,
                             userInfo: nil))
    }
    
    do { renderer.loadFOLD(try JSONDecoder().decode(FOLDFormat.self, from: data)) }
    catch let error { return handler(error) }
    
    handler(nil)
  }
}
