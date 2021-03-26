//
//  MetalView.swift
//  QuickLookFOLD
//
//  Created by Robby on 3/23/21.
//

import Foundation
import Metal
import MetalKit

class MetalView: MTKGestureView {
  var touchDown: NSPoint = .zero

  override func mouseDown(with event: NSEvent) {
//    print("mouseDown")
    super.mouseDown(with: event)
    touchDown = event.locationInWindow
    touchDelegate?.didPress()
  }

  override func mouseDragged(with event: NSEvent) {
//    print("mouseDragged")
    super.mouseDragged(with: event)
    touchDelegate?.didDrag(x: Float(event.locationInWindow.x - touchDown.x),
                           y: Float(event.locationInWindow.y - touchDown.y))
  }

}
