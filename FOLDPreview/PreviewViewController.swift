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
  
  override var nibName: NSNib.Name? {
    return NSNib.Name("PreviewViewController")
  }
  
  @objc func touchDown() {
    print("TOUCH DOWN YAY")
  }

  override func loadView() {
    super.loadView()
//    self.view.allowedTouchTypes = NSTouch.TouchTypeMask.direct
    // Do any additional setup after loading the view.
    
    let gesture = NSPressGestureRecognizer(target: self, action: #selector(touchDown))
    self.view.addGestureRecognizer(gesture)

//    UITapGestureRecognizer *singleFingerDTap = [[UITapGestureRecognizer alloc]
//                                            initWithTarget:self action:@selector(handleSingleDoubleTap:)];
//    singleFingerDTap.numberOfTapsRequired = 2;
//    [self.view addGestureRecognizer:singleFingerDTap];
//    [self.view setUserInteractionEnabled:YES];
//    [self.view setMultipleTouchEnabled:YES];
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
  
  override func viewWillLayout() {
    super.viewWillLayout()
    metalView?.frame = self.view.bounds
//    print("View bounds \(self.view.bounds)")
  }

  override func touchesBegan(with event: NSEvent) {
    print("super.touchesBegan(with: event)")
    super.touchesBegan(with: event)
  }
  
  override func touchesMoved(with event: NSEvent) {
    print("super.touchesMoved(with: event)")
    super.touchesMoved(with: event)
  }
  
  override func touchesEnded(with event: NSEvent) {
    print("super.touchesEnded(with: event)")
    super.touchesEnded(with: event)
  }
  
  override func touchesCancelled(with event: NSEvent) {
    print("super.touchesCancelled(with: event)")
    super.touchesCancelled(with: event)
  }
  
//  override func quickLook(with event: NSEvent) {
//    super.quickLook(with: event)
//    print("QUICK LOOK WITH EVENT")
//  }
//
//  override func quickLookPreviewItems(_ sender: Any?) {
//    super.quickLookPreviewItems(sender)
//    print("QUICK LOOK PREVIEW ITEMS")
//  }
//
  func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {

    // load the file contents, do not proceed if there is an error
    guard let data = FileManager.default.contents(atPath: url.path) else {
      return handler(NSError(domain: NSCocoaErrorDomain,
                             code: NSFileReadUnknownError,
                             userInfo: nil))
    }
    
    if self.renderer == nil { self.renderer = Renderer() }
    guard let renderer = self.renderer else { return }
    if self.metalView == nil {
      self.metalView = MetalView()
      self.view.addSubview(self.metalView!)
      renderer.mtkView = self.metalView!
    }

    // my particular file type is a JSON format.
    do {
      let fold: FOLDFormat = try JSONDecoder()
        .decode(FOLDFormat.self, from: data)

      // this is a custom NSView/UIView able to process our data format.
      // you can render a view using AppKit/UIKit, Quartz, or Metal
      renderer.loadFOLD(fold)

//        let foldView = FOLDView()
//        foldView.fold = fold
//        self.view.addSubview(foldView)

    // json parsing error, the file will not be previewed
    } catch let error {
      return handler(error)
    }

    handler(nil)
  }
}
