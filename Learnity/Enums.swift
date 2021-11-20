//
//  Enums.swift
//  Learnity
//
//  Created by Madalina on 14.11.2021.
//

import Foundation

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
