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
  var previousFlowState : FlowState = .view
  var flowState : FlowState = .view {
    didSet{
      previousFlowState = oldValue
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
    if flowState == .action && ( gestureType == .thumbUp || gestureType == .thumbDown ){
      delegate?.disableGestureRecognitionForVeryShort()
    } else if gestureType != .nothing && gestureType != .background && ( flowState != .notes && gestureType != .pinch ) {
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
      case .notes, .focus:
        print("do nothing")
    }
  }
  
  private func handleGestureTwo() {
    switch flowState {
      case .view, .focus, .notes:
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
    }
  }
  
  private func handleGestureThree() {
    switch flowState {
      case .view, .focus, .notes:
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
        // TODO: Save changes
        flowState = previousFlowState
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
        // TODO: Discard changes
        flowState = previousFlowState
    }
  }
  
  private func handleGesturePinch() {
    switch flowState {
      case .view, .focus, .edit, .action:
        flowState = .notes
      case .notes:
        print("desenez ebati")
    }
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
    if flowState != .action {
      //Terminate current actioning mode (translate/rotate/scale)
      flowState = .edit
    }
  }
}
