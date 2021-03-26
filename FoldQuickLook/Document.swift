//
//  Document.swift
//  FoldQuickLook
//
//  Created by Robby on 3/24/21.
//

import Cocoa

class Document: NSDocument {

  var fold: FOLDFormat?
  var viewController: ViewController!

  override init() {
    super.init()
    // Add your subclass-specific initialization here.
  }

  override class var autosavesInPlace: Bool {
    return true
  }

  override func makeWindowControllers() {
    let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
    let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
    self.addWindowController(windowController)

    if let contentViewController = windowController.contentViewController as? ViewController {
      self.viewController = contentViewController
      if let fold = self.fold {
        self.viewController.renderer.loadFOLD(fold)
      }
    }
  }

  override func data(ofType typeName: String) throws -> Data {
    // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
    // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
    throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
  }

  override func read(from data: Data, ofType typeName: String) throws {
    do {
      self.fold = try JSONDecoder().decode(FOLDFormat.self, from: data)
    } catch {
      throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
  }

}

