//
//  Extensions.swift
//  Learnity
//
//  Created by Madalina on 14.11.2021.
//

import Foundation
import SceneKit


extension SCNNode {
  var isFocusable : Bool {
    get {
      return self.name?.contains("focusable") ?? false
    }
  }
  
  var isLayered : Bool {
    get {
      return self.name?.contains("layered") ?? false
    }
  }
  
  func centerPivot() {
    var min = SCNVector3Zero
    var max = SCNVector3Zero
    self.__getBoundingBoxMin(&min, max: &max)
    print("Min -> \(min.x) and max \(max.x)")
    self.pivot = SCNMatrix4MakeTranslation(
      min.x + (max.x - min.x)/2,
      min.y + (max.y - min.y)/2,
      min.z + (max.z - min.z)/2
    )
  }
}

extension SCNVector3 {
  static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
      return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
  }
  
  static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
      return SCNVector3Make(l.x + r.x, l.y + r.y, l.z + r.z)
  }
  
  static func * (l: SCNVector3, scalar: Float) -> SCNVector3 {
      return SCNVector3Make(l.x * scalar, l.y * scalar, l.z * scalar)
  }
}

