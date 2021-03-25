//
//  Document.swift
//  FoldQuickLook
//
//  Created by Robby on 3/24/21.
//

import Cocoa

class Document: NSDocument {

  override init() {
      super.init()
    // Add your subclass-specific initialization here.
  }

  override class var autosavesInPlace: Bool {
    return true
  }

  override func makeWindowControllers() {
    // Returns the Storyboard that contains your Document window.
    let storyboard = NSStoryboard(name: NSStoryboard.Name("Main"), bundle: nil)
    let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier("Document Window Controller")) as! NSWindowController
    self.addWindowController(windowController)
  }

  override func data(ofType typeName: String) throws -> Data {
    // Insert code here to write your document to data of the specified type, throwing an error in case of failure.
    // Alternatively, you could remove this method and override fileWrapper(ofType:), write(to:ofType:), or write(to:ofType:for:originalContentsURL:) instead.
    throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
  }

  override func read(from data: Data, ofType typeName: String) throws {
    // Insert code here to read your document from the given data of the specified type, throwing an error in case of failure.
    // Alternatively, you could remove this method and override read(from:ofType:) instead.
    // If you do, you should also override isEntireFileLoaded to return false if the contents are lazily loaded.

    // my particular file type is a JSON format.
    do {
      let _: FOLDFormat = try JSONDecoder()
        .decode(FOLDFormat.self, from: data)
//      print("loaded fold \(fold)")

      // this is a custom NSView/UIView able to process our data format.
      // you can render a view using AppKit/UIKit, Quartz, or Metal
//      renderer.loadFOLD(fold)

//        let foldView = FOLDView()
//        foldView.fold = fold
//        self.view.addSubview(foldView)
    // json parsing error, the file will not be previewed
    } catch {
      throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

  }


}

