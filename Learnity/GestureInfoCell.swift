import UIKit

class GestureInfoCell: UITableViewCell {

  @IBOutlet weak var gestureImg: UIImageView!
  @IBOutlet weak var gestureLbl: UILabel!
  
  override func awakeFromNib() {
        super.awakeFromNib()
    }

  func setGesture(gesture: GestureData, index: Int) {
    gestureImg.image = gesture.gesture.getImage()
    gestureLbl.text = gesture.label
    
    if index == 0 {
      self.layer.cornerRadius = 20
      self.layer.cornerCurve = .continuous
      self.layer.maskedCorners = [.layerMaxXMinYCorner, .layerMinXMinYCorner]
    } else if index == GesturesPresenter.shared.gesturesList.count - 1 {
      self.layer.cornerRadius = 20
      self.layer.cornerCurve = .continuous
      self.layer.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
    } else {
      self.layer.cornerRadius = 0
    }
  }

}
