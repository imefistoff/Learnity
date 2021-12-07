import Foundation
import SceneKit

extension SCNNode {
  var isFocusable : Bool {
    get {
      return self.name?.contains("focusable") ?? false
    }
  }
  
  var hasLayeredSubnode : Bool {
    get {
      var hasLayeredSubnode = false
      self.childNodes.forEach { subNode in
        if subNode.name != nil && subNode.name!.contains("layered") {
          hasLayeredSubnode = true
        }
      }
      return hasLayeredSubnode
    }
  }
  
  var getLayeredSubNode : SCNNode? {
    get {
      var layeredSubnode : SCNNode? = nil
      self.childNodes.forEach { subNode in
        if subNode.name != nil && subNode.name!.contains("layered") {
          layeredSubnode = subNode
        }
      }
      return layeredSubnode
    }
  }
  
  var isExternalLayer : Bool {
    return !(self.name != nil && self.name!.contains("notexternal"))
  }
  
  var isBasePivot : Bool {
    return self.name != nil && self.name!.contains("basePivot")
  }
  
  var isPermanent : Bool {
    return self.name != nil && self.name!.contains("permanent")
  }
  
  func centerPivot() {
    var min = SCNVector3Zero
    var max = SCNVector3Zero
    self.__getBoundingBoxMin(&min, max: &max)
    self.pivot = SCNMatrix4MakeTranslation(
      min.x + (max.x - min.x)/2,
      (isBasePivot ? -1 : +1) * min.y + (max.y - min.y)/2,
      min.z + (max.z - min.z)/2
    )
  }
  
  func centerPivotOnTopLeftCorner() {
    var min = SCNVector3Zero
    var max = SCNVector3Zero
    self.__getBoundingBoxMin(&min, max: &max)
    self.pivot = SCNMatrix4MakeTranslation(
      0,
      2.3,
      3.5
    )
    print(pivot)
  }
}

extension SCNVector3 {
  static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x - r.x, l.y - r.y, l.z - r.z)
  }
  
  static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
    return SCNVector3Make(l.x + r.x, l.y + r.y, l.z + r.z)
  }

  static func += ( l: inout SCNVector3, r: SCNVector3) {
    l = l + r
  }
  
  static func * (l: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(l.x * scalar, l.y * scalar, l.z * scalar)
  }
  
  static func / (l: SCNVector3, scalar: Float) -> SCNVector3 {
    return SCNVector3Make(l.x / scalar, l.y / scalar, l.z / scalar)
  }
}

