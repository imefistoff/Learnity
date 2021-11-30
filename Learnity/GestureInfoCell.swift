//
//  GestureInfoCell.swift
//  Learnity
//
//  Created by Madalina on 27.11.2021.
//

import UIKit

class GestureInfoCell: UITableViewCell {

  @IBOutlet weak var gestureImg: UIImageView!
  @IBOutlet weak var gestureLbl: UILabel!
  
  override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

  func setGesture(gesture: GestureData) {
    gestureImg.image = gesture.gesture.getImage()
    gestureLbl.text = gesture.label
  }

}
