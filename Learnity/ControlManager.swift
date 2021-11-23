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
        print("focus next")
      case .focus:
        print("do nothing")
      case .edit:
        print("select translation mode")
      case .action:
        print("toggle x axe")
    }
  }
  
  private func handleGestureTwo() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        print("do nothing")
      case .edit:
        print("select rotation mode")
      case .action:
        print("toggle y axe")
    }
  }
  
  private func handleGestureThree() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        print("do nothing")
      case .edit:
        print("select scale mode")
      case .action:
        print("toggle z axe")
    }
  }
  
  private func handleGestureThumbUp() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        print("confirm object and enter Edit flow")
      case .edit:
        print("save object changes and return to Focus flow with current object selected")
      case .action:
        print("increase value")
    }
  }
  
  private func handleGestureThumbDown() {
    switch flowState {
      case .view:
        print("do nothing")
      case .focus:
        print("unfocus and return to View flow")
      case .edit:
        print("discard changes")
      case .action:
        print("decrease value")
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
        print("go to next scene")
      case .focus:
        print("go to next object")
      case .edit:
        print("remove layer")
      case .action:
        print("do nothing")
    }
  }
  
  private func handleGestureFingerSnap() {
    print("toggle hud")
  }
  
  private func handleGesturePalm() {
    if flowState == .action {
      print("save actions and go back to Edit flow")
    } else {
      print("do nothing")
    }
  }
}
