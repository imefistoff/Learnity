//
//  ViewController.swift
//  Learnity
//
//  Created by Maxim Sargarovschi on 25.10.2021.
//

import UIKit
import SceneKit
import ARKit

class ViewController: UIViewController, ARSCNViewDelegate {
  
  @IBOutlet var leftScene: ARSCNView!
  @IBOutlet weak var rightScene: ARSCNView!
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Set the view's delegate
    leftScene.delegate = self
    
    // Show statistics such as fps and timing information
    leftScene.showsStatistics = true
    rightScene.showsStatistics = true
    // Create a new scene
    let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    // Set the scene to the view
    leftScene.scene = scene
    rightScene.scene = scene
    
    //getupdate
    leftScene.isPlaying = true
    rightScene.isPlaying = true
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    
    // Run the view's session
    leftScene.session.run(configuration)
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause the view's session
    leftScene.session.pause()
  }
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      self.updateFrame()
    }
  }
  
  func updateFrame() {
    
    // Clone pointOfView for Second View
    let pointOfView : SCNNode = (leftScene.pointOfView?.clone())!
    
    // Determine Adjusted Position for Right Eye
    let orientation : SCNQuaternion = pointOfView.orientation
    let orientationQuaternion : GLKQuaternion = GLKQuaternionMake(orientation.x, orientation.y, orientation.z, orientation.w)
    let eyePos : GLKVector3 = GLKVector3Make(1.0, 0.0, 0.0)
    let rotatedEyePos : GLKVector3 = GLKQuaternionRotateVector3(orientationQuaternion, eyePos)
    let rotatedEyePosSCNV : SCNVector3 = SCNVector3Make(rotatedEyePos.x, rotatedEyePos.y, rotatedEyePos.z)
    
    let mag : Float = 0.066 // This is the value for the distance between two pupils (in metres). The Interpupilary Distance (IPD).
    pointOfView.position.x += rotatedEyePosSCNV.x * mag
    pointOfView.position.y += rotatedEyePosSCNV.y * mag
    pointOfView.position.z += rotatedEyePosSCNV.z * mag
    
    rightScene.pointOfView = pointOfView
    
  }
  
  // MARK: - ARSCNViewDelegate
  
  /*
   // Override to create and configure nodes for anchors added to the view's session.
   func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
   let node = SCNNode()
   
   return node
   }
   */
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    // Present an error message to the user
    
  }
  
  func sessionWasInterrupted(_ session: ARSession) {
    // Inform the user that the session has been interrupted, for example, by presenting an overlay
    
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    // Reset tracking and/or remove existing anchors if consistent tracking is required
    
  }
}
