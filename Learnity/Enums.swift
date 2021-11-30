//
//  Enums.swift
//  Learnity
//
//  Created by Madalina on 14.11.2021.
//

import Foundation
import CoreText
import UIKit
import AVFoundation

enum GeometricTransformationTypes: Int {
  case translation = 0
  case rotation
  case scale
}

enum Axes {
  case x, y, z
}

enum MovingState: String {
  case up
  case down
  case nothing
}

enum GestureType: String {
  case one = "One"
  case two = "Two"
  case three = "Three"
  case thumbUp = "ThumbsUp"
  case thumbDown = "ThumbsDown"
  case pinch = "Pinch"
  case background = "Background"
  case swipe = "Swipe"
  case fingerSnap = "FingerSnap"
  case palm = "Palm"
  case nothing = "Nothing"
  
  func getImage() -> UIImage {
    return UIImage(named: self.rawValue) ?? UIImage(named: "One")!
  }
}

enum FlowState: String {
  case view
  case focus
  case edit
  case action
  case notes
}
