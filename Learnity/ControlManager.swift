//
//  GestureManager.swift
//  Learnity
//
//  Created by Maxim Sargarovschi on 23.11.2021.
//

import Foundation

class ControlManager {
  //Singletone
  static let shared = ControlManager()
  private init() {}
  
  //MARK: Variables
  var delegate : ViewController?
  var flowState : FlowState = .view {
    didSet{
      handleFlowStateChange()
    }
  }
  var gestureType: GestureType = .nothing {
    didSet{
      print(gestureType.rawValue)
      handleDetectedGesture()
    }
  }
  
  //MARK: Functions
  func setGestureType(_ type: String){
    let enumGestureType = GestureType(rawValue: type) ?? .nothing
    self.gestureType = enumGestureType
  }
  
  private func handleFlowStateChange(){
    switch flowState {
      case .view:
        print("Enter on View mode")
      case .edit:
        print("Enter on Edit mode")
      case .focus:
        print("Enter on Focus mode")
      case .action:
        print("Enter on Action mode")
    }
  }
  
  private func handleDetectedGesture(){
    if gestureType != .nothing && gestureType != .background {
      delegate?.disableGestureRecognitionForShort()
    }
    
    switch gestureType {
      case .one:
        handleGestureOne()
      case .two:
        handleGestureTwo()
      case .three:
        handleGestureThree()
      case .thumbUp:
        handleGestureThumbUp()
      case .thumbDown:
        handleGestureThumbDown()
      case .pinch:
        handleGesturePinch()
      case .background:
        handleGestureBackground()
      case .swipe:
        handleGestureSwipe()
      case .fingerSnap:
        handleGestureFingerSnap()
      case .palm:
        handleGesturePalm()
      case .nothing:
        break
    }
  }
  
  private func handleGestureOne() {
    switch flowState {
      case .view:
        //Focus on first focusable object in scene
        flowState = .focus
        delegate?.focusOnNextObject()
      case .focus:
        print("do nothing")
      case .edit:
        //Enter on Action(Translation) mode
        flowState = .action
        delegate?.selectedTransformationType = .translation
      case .action:
        //Toggle OX axe for edit
        if let delegate = delegate {
          delegate.isOxSelected = !delegate.isOxSelected
        }
    }
  }
  
  private func handleGestureTwo() {
    switch flowState {
      case .view,.focus:
        print("do nothing")
      case .edit:
        //Enter on Action(Rotation) mode
        flowState = .action
        delegate?.selectedTransformationType = .rotation
      case .action:
        //Toggle OY axe for edit
        if let delegate = delegate {
          delegate.isOySelected = !delegate.isOySelected
        }
    }
  }
  
  private func handleGestureThree() {
    switch flowState {
      case .view,.focus:
        print("do nothing")
      case .edit:
        //Enter on Action(Scale) mode
        flowState = .action
        delegate?.selectedTransformationType = .scale
      case .action:
        //Toggle OZ axe for edit
        if let delegate = delegate {
          delegate.isOzSelected = !delegate.isOzSelected
        }
    }
  }
  
  private func handleGestureThumbUp() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        flowState = .edit
      case .edit:
        delegate?.saveChanges()
        flowState = .focus
      case .action:
        delegate?.increaseTransformActionValue()
    }
  }
  
  private func handleGestureThumbDown() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        delegate?.unfocus()
        flowState = .view
      case .edit:
        delegate?.discardChanges()
        flowState = .focus
      case .action:
        delegate?.decreaseTransformActionValue()
    }
  }
  
  private func handleGesturePinch() {
    print("write on the whiteboard")
    // TODO: ne gandim la scenariul in care vrei sa stergi
  }
  
  private func handleGestureBackground() {
    print("do nothing")
  }
  
  private func handleGestureSwipe() {
    switch flowState {
      case .view:
        delegate?.loadNextScene()
      case .focus:
        delegate?.focusOnNextObject()
      case .edit:
        delegate?.removeUpperLayer()
      case .action:
        print("do nothing")
    }
  }
  
  private func handleGestureFingerSnap() {
    print("toggle hud")
  }
  
  private func handleGesturePalm() {
    //nu action da notes (Va fi adaugat de Mada)
    if flowState != .action {
      print("go to notes mode")
    } else {
      print("exit notes mode")
    }
  }
}
