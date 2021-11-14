//
//  Extensions.swift
//  Learnity
//
//  Created by Madalina on 14.11.2021.
//

import Foundation
import SceneKit


extension SCNNode {
  func centerPivot() {
    var min = SCNVector3Zero
    var max = SCNVector3Zero
    self.__getBoundingBoxMin(&min, max: &max)
    self.pivot = SCNMatrix4MakeTranslation(
      min.x + (max.x - min.x)/2,
      min.y + (max.y - min.y)/2,
      min.z + (max.z - min.z)/2
    )
  }
}
