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
  private init() {
    GesturesPresenter.shared.setGesturesList(for: flowState)
  }
  
  //MARK: Variables
  var delegate : ViewController?
  var flowState : FlowState = .view {
    didSet{
      GesturesPresenter.shared.setGesturesList(for: flowState)
      delegate?.gestureTableView.reloadData()
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
          delegate.isAxesHudVisible = !delegate.isAxesHudVisible
        }
      case .notes:
        print("notes")
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
          delegate.isAxesHudVisible = !delegate.isAxesHudVisible
        }
      case .notes:
        print("notes")
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
          delegate.isAxesHudVisible = !delegate.isAxesHudVisible
        }
      case .notes:
        print("notes")
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
      case .notes:
        print("notes")
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
      case .notes:
        print("notes")
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
      case .notes:
        print("notes")
    }
  }
  
  private func handleGestureFingerSnap() {
    print("toggle hud")
  }
  
  private func handleGesturePalm() {
    //palm will be used only for action for stopping modifications
    if flowState != .action {
      print("go to notes mode")
    } else {
      print("exit notes mode")
    }
  }
}
