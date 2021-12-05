import Foundation
import SceneKit

class GesturesPresenter {
  static let shared = GesturesPresenter()
  private init() {}
  
  var gesturesList : [GestureData] = []
  var focusedObject : SCNNode! {
    didSet{
      ControlManager.shared.delegate?.prepareLayeredNode()
    }
  }
  
  func setGesturesList(for flowState: FlowState) {
    switch flowState {
      case .view:
        gesturesList = [
          GestureData(gesture: GestureType.one, label: "Focus first object"),
          GestureData(gesture: GestureType.swipeLeft, label: "Prev scene"),
          GestureData(gesture: GestureType.swipeRight, label: "Next scene")
        ]
      case .focus:
        gesturesList = [
          GestureData(gesture: GestureType.swipeLeft, label: "Focus prev object"),
          GestureData(gesture: GestureType.swipeRight, label: "Focus next object"),
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
        if focusedObject.hasLayeredSubnode {
          gesturesList.insert(GestureData(gesture: GestureType.swipeLeft, label: "Remove layer"), at: 3)
        }
      case .action:
        gesturesList = [
          GestureData(gesture: GestureType.thumbUp, label: "Increase"),
          GestureData(gesture: GestureType.thumbDown, label: "Decrease"),
          GestureData(gesture: GestureType.palm, label: "Done")
        ]
        if  ControlManager.shared.delegate?.selectedTransformationType != .scale {
          gesturesList.insert(contentsOf: [GestureData(gesture: GestureType.one, label: "Select axe X"),
                                           GestureData(gesture: GestureType.two, label: "Select axe Y"),
                                           GestureData(gesture: GestureType.three, label: "Select axe Z")], at: 0)
        }
      case .notes:
        gesturesList = [
          GestureData(gesture: GestureType.pinch, label: "Draw"),
          GestureData(gesture: GestureType.thumbUp, label: "Save changes"),
          GestureData(gesture: GestureType.thumbDown, label: "Discard changes"),
        ]
    }
  }
  
  func updateGestureList(layerCase: LayerPresenterCase){
    guard let delegate = ControlManager.shared.delegate else { return }
    gesturesList = [
      GestureData(gesture: GestureType.one, label: "Translate"),
      GestureData(gesture: GestureType.two, label: "Rotate"),
      GestureData(gesture: GestureType.three, label: "Scale"),
      GestureData(gesture: GestureType.swipeLeft, label: "Remove layer"),
      GestureData(gesture: GestureType.swipeRight, label: "Revert layer"),
      GestureData(gesture: GestureType.thumbUp, label: "Save changes"),
      GestureData(gesture: GestureType.thumbDown, label: "Discard changes")
    ]
    
    switch layerCase {
      case .first:
        gesturesList.remove(at: 4)
      case .last:
        gesturesList.remove(at: 3)
      case .other:
        break
    }
    
    delegate.gestureTableView.reloadData()
  }
}
