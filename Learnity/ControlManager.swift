import Foundation
import UIKit

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
  
  var lastThreeGestures = [GestureType]() {
    didSet{
      if lastThreeGestures.count == 2 {
        if lastThreeGestures[0] != lastThreeGestures[1]{
          lastThreeGestures.removeFirst()
        }
      }
      if lastThreeGestures.count == 3 {
        if lastThreeGestures[0] == lastThreeGestures[1] && lastThreeGestures[1] == lastThreeGestures[2] {
          gestureType = lastThreeGestures[2]
        }
        lastThreeGestures.removeFirst(2)
      }
      print(lastThreeGestures)
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
    lastThreeGestures.append(enumGestureType)
  }
  
  private func handleDetectedGesture(){
    if flowState == .action && ( gestureType == .thumbUp || gestureType == .thumbDown ){
      delegate?.disableGestureRecognition(for: 0.2)
    } else if (gestureType != .nothing && gestureType != .background && gestureType != .pinch) || ( gestureType == .pinch && flowState != .notes) {
      delegate?.disableGestureRecognition(for: 2)
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
      case .swipeLeft, .swipeRight:
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
          if delegate.selectedTransformationType != .scale {
            delegate.isAxesHudVisible = !delegate.isAxesHudVisible
          }
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
          if delegate.selectedTransformationType != .scale {
            delegate.isAxesHudVisible = !delegate.isAxesHudVisible
          }
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
          if delegate.selectedTransformationType != .scale {
            delegate.isAxesHudVisible = !delegate.isAxesHudVisible
          }
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
        delegate?.saveNoticeChanges()
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
        delegate?.discardNoticeChanges()
        flowState = previousFlowState
    }
  }
  
  private func handleGesturePinch() {
    switch flowState {
      case .view, .focus, .edit, .action:
        // Left out until implementation is done
        flowState = .notes
        delegate?.drawingViews.forEach({ view in
          view.isHidden = false
        })
      case .notes:
        break
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
        handleLayeredSwipe()
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
    if flowState == .action {
      //Terminate current actioning mode (translate/rotate/scale)
      flowState = .edit
    }
    if flowState == .notes {
      delegate?.clearDrawingPath()
    }
  }
  
  private func handleLayeredSwipe(){
    switch gestureType {
      case .swipeRight:
        delegate?.revertRemovedLayer()
      case .swipeLeft:
        delegate?.removeUpperLayer()
      default:
        break
    }
  }
}
