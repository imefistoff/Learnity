//
//  GesturesPresenter.swift
//  Learnity
//
//  Created by Madalina on 29.11.2021.
//

import Foundation
import SceneKit

class GesturesPresenter {
  static let shared = GesturesPresenter()
  private init() {}
  
  var gesturesList : [GestureData] = []
  var focusedObject : SCNNode!
  
  func setGesturesList(for flowState: FlowState) {
    switch flowState {
      case .view:
        gesturesList = [
          GestureData(gesture: GestureType.one, label: "Focus first object"),
          GestureData(gesture: GestureType.swipe, label: "Change view")
        ]
      case .focus:
        gesturesList = [
          GestureData(gesture: GestureType.swipe, label: "Focus next object"),
          GestureData(gesture: GestureType.thumbDown, label: "Unfocus object"),
          GestureData(gesture: GestureType.thumbUp, label: "Select object")
        ]
      case .edit:
        gesturesList = [
          GestureData(gesture: GestureType.one, label: "Translate"),
          GestureData(gesture: GestureType.two, label: "Rotate"),
          GestureData(gesture: GestureType.three, label: "Scale"),
          GestureData(gesture: GestureType.thumbUp, label: "Save changes"),
          GestureData(gesture: GestureType.thumbDown, label: "Discard changes")
        ]
        if focusedObject.isLayered {
          gesturesList.append(GestureData(gesture: GestureType.swipe, label: "Remove layer"))
        }
      case .action:
        gesturesList = [
          GestureData(gesture: GestureType.one, label: "Select axe X"),
          GestureData(gesture: GestureType.two, label: "Select axe Y"),
          GestureData(gesture: GestureType.three, label: "Select axe Z"),
          GestureData(gesture: GestureType.thumbUp, label: "Increase"),
          GestureData(gesture: GestureType.thumbDown, label: "Decrease"),
          GestureData(gesture: GestureType.swipe, label: "Done")
        ]
      case .notes:
        print("ciao")
    }
  }
}
