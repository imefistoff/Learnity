//
//  ViewController.swift
//  Learnity
//
//  Created by Maxim Sargarovschi on 25.10.2021.
//

import UIKit
import SceneKit
import ARKit
import SceneKit.ModelIO

class ViewController: UIViewController, ARSCNViewDelegate {
  
  @IBOutlet weak var sceneViewLeft: ARSCNView!
  @IBOutlet weak var sceneViewRight: ARSCNView!
  @IBOutlet weak var debugView: UIView!
  
  

  let scene = SCNScene(named: "art.scnassets/ship.scn")!
  var avion : SCNNode?
  var earth : SCNNode?
  let _CAMERA_IS_ON_LEFT_EYE = true
  let interpupilaryDistance : Float = 0.066 // This is the value for the distance between two pupils (in metres). The Interpupilary Distance (IPD).
  
  
  // DEBUG MODE VARIABLES
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var xSwitch: UISwitch!
  @IBOutlet weak var ySwitch: UISwitch!
  @IBOutlet weak var zSwitch: UISwitch!
  let isDebug = false
  var selectedTransformationType = GeometricTransformationTypes.translation
  
  
  override func viewDidLoad() {
    super.viewDidLoad()
    self.debugView.isHidden = !isDebug
    
    UIApplication.shared.isIdleTimerDisabled = true
    
    // Create a new scene
    let scene = SCNScene(named: "art.scnassets/ship.scn")!
    
    sceneViewLeft.scene = scene
    sceneViewLeft.isPlaying = true
    
    sceneViewRight.scene = scene
    sceneViewRight.isPlaying = true
    
    avion = scene.rootNode.childNode(withName: "ship", recursively: false)
    avion?.centerPivot()
    avion?.position = SCNVector3(0,0,-1.5)
    
    earth = scene.rootNode.childNode(withName: "earth", recursively: false)
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    // Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    configuration.frameSemantics.insert(.personSegmentationWithDepth)
    configuration.planeDetection = [.horizontal, .vertical]
    
    sceneViewLeft.session.run(configuration)
    sceneViewRight.session = sceneViewLeft.session
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    // Pause the view's session
    sceneViewLeft.session.pause()
  }
  
  @IBAction func selectedTypeChanged(_ sender: UISegmentedControl) {
    selectedTransformationType = GeometricTransformationTypes(rawValue: sender.selectedSegmentIndex) ?? GeometricTransformationTypes.translation
  }
  
  @IBAction func tapPlus(_ sender: Any) {
    switch selectedTransformationType {
      case .translation : translate(0.3)
      case .rotation : rotate(5)
    case .scale : scale(1.25)
    }
  }
  
  @IBAction func tapMinus(_ sender: Any) {
    switch selectedTransformationType {
      case .translation : translate(-0.3)
      case .rotation : rotate(-5)
    case .scale : scale(0.75)
    }
  }
  
  func rotate(_ step: CGFloat){
    guard let avion = avion else {
      return
    }
    
    let rotateAction = SCNAction.rotate(by: step,
                                        around: SCNVector3(xSwitch.isOn ? 1 : 0,
                                                           ySwitch.isOn ? 1 : 0,
                                                           zSwitch.isOn ? 1 : 0),
                                        duration: 2)
    avion.runAction(rotateAction)
  }
  
  func scale(_ step: CGFloat){
    guard let avion = avion else {
      return
    }
    
    let scaleAction = SCNAction.scale(by: step, duration: 2)
    avion.runAction(scaleAction)
  }
  
  func translate(_ step: Float) {
    guard let avion = avion else {
      return
    }
    
    let translateAction = SCNAction.move(by: SCNVector3(xSwitch.isOn ? step: 0,
                                                        ySwitch.isOn ? step : 0,
                                                        zSwitch.isOn ? step : 0), duration: 2)
    avion.runAction(translateAction)
  }
  
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      self.updateFrame()
    }
  }
  
  func updateFrame() {
    
        let pointOfView : SCNNode = (sceneViewLeft.pointOfView?.clone())!
    
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
    
        sceneViewRight.pointOfView = pointOfView
      
  }
  // MARK: - ARSCNViewDelegate
  
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

