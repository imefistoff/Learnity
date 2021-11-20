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
  
  @IBOutlet weak var predictionLabel: UILabel!
  @IBOutlet weak var predictionLabel2: UILabel!
  
  private var overlayLayer = CAShapeLayer()
  private var pointsPath = UIBezierPath()
  
  
  let scene = SCNScene(named: "art.scnassets/ship.scn")!
  var avion : SCNNode?
  var earth : SCNNode?
  
  let interpupilaryDistance : Float = 0.066 // This is the value for the distance between two pupils (in metres). The Interpupilary Distance (IPD).
  
  //MARK: Prediction variables
  let predictEvery = 3
  var frameCounter = -1
  
  //MARK: Follow gesture variables
  let predictGestureMovingEvery = 9
  var previousFingerTipPosition = CGPoint(x: -1, y: -1)
  var movingState = MovingState.nothing {
    willSet{
      handleChangeMovingState(newValue)
    }
  }
  var movingTreshold = CGFloat(50)
  
  //MARK:  DEBUG MODE VARIABLES
  @IBOutlet weak var leftSceneContainer: UIView!
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
    sceneViewLeft.delegate = self
    sceneViewLeft.session.delegate = self
    sceneViewLeft.scene = scene
    sceneViewLeft.isPlaying = true
    
    sceneViewRight.scene = scene
    sceneViewRight.isPlaying = true
    
    avion = scene.rootNode.childNode(withName: "ship", recursively: false)
    avion?.centerPivot()
    avion?.position = SCNVector3(0,0,-1.5)
    
    earth = scene.rootNode.childNode(withName: "earth", recursively: false)
    
    if let camera = sceneViewLeft.pointOfView?.camera {
      camera.fieldOfView = CGFloat(138)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    ///add view for drawing
    addDrawingView()
    
    /// Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    configuration.frameSemantics.insert(.personSegmentationWithDepth)
    configuration.planeDetection = [.horizontal, .vertical]
    
    sceneViewLeft.session.run(configuration)
    sceneViewRight.session = sceneViewLeft.session
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    /// Pause the view's session
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
                                        duration: 0.3)
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
  
  func addDrawingView() {
    ///Use this view for drawing something for debuging (black dot on finger TIP foe example).
    let drawingViewLeft = UIView()
    drawingViewLeft.backgroundColor = .clear
    drawingViewLeft.translatesAutoresizingMaskIntoConstraints = false
    
    leftSceneContainer.addSubview(drawingViewLeft)
    
    drawingViewLeft.center = leftSceneContainer.center
    leftSceneContainer.addConstraint(NSLayoutConstraint(item: drawingViewLeft, attribute: .height, relatedBy: .equal, toItem: leftSceneContainer, attribute: .height, multiplier: 1, constant: 0))
    leftSceneContainer.addConstraint(NSLayoutConstraint(item: drawingViewLeft, attribute: .width, relatedBy: .equal, toItem: leftSceneContainer, attribute: .width, multiplier: 1, constant: 0))
    
    drawingViewLeft.layer.addSublayer(overlayLayer)
  }
  
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    DispatchQueue.main.async {
      self.updateFrame()
    }
  }
  
  func updateFrame() {
  }
  // MARK: - ARSCNViewDelegate
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    /// Present an error message to the user
    
  }
  
  func sessionWasInterrupted(_ session: ARSession) {
    /// Inform the user that the session has been interrupted, for example, by presenting an overlay
    
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    /// Reset tracking and/or remove existing anchors if consistent tracking is required
    
  }
}

extension ViewController: ARSessionDelegate{
  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    frameCounter += 1
    
    let pixelBuffer = frame.capturedImage
    let handPoseReques = VNDetectHumanHandPoseRequest()
    handPoseReques.maximumHandCount = 1
    handPoseReques.revision = VNDetectHumanHandPoseRequestRevision1
    
    let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
    do {
      try handler.perform([handPoseReques])
    } catch {
      assertionFailure("Human pose request failed: \(error)")
    }
    
    guard let handPoses = handPoseReques.results, !handPoses.isEmpty else {
      return
    }
    let handObservation = handPoses.first
    if frameCounter % predictEvery == 0 {
      let model = oneClassifier()
      guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError()}
      do {
        let handPosePrediction = try model.prediction(poses: keypointsMultiArray)
        let confidence = handPosePrediction.labelProbabilities[handPosePrediction.label]!
        if confidence > 0.5 {
          updatePredictionLabels(with: "\(handPosePrediction.label) \(confidence)")
        }
      }catch{
        print("Prediction error: \(error)")
      }
      
      ///monitoring Finger Index TIP position on screen (up/down only)
      checkMoving(handObservation)
    }
  }
  
  private func checkMoving(_ handObservation: VNHumanHandPoseObservation?) {
    guard let handObservation = handObservation else {
      return
    }

    if frameCounter % predictGestureMovingEvery == 0 {
      let landmarkConfidenceTreshold : Float = 0.2
      let indexFingerName = VNHumanHandPoseObservation.JointName.indexTip
      
      let width = sceneViewLeft.currentViewport.width
      let height = sceneViewLeft.currentViewport.height
      
      var indexFingerTipLocation : CGPoint?
      
      if let indexFingerPoint = try? handObservation.recognizedPoint(indexFingerName),
         indexFingerPoint.confidence > landmarkConfidenceTreshold {
        let normalizedLocation = indexFingerPoint.location
        ///locatia FingerTip in imaginea noastra (0.55 din latimea screem) coordonate corecte!!!
        indexFingerTipLocation = CGPoint(x: normalizedLocation.x * width, y: normalizedLocation.y * height)
        
        if isPreviousFingerTipPositionNotSet() {
          previousFingerTipPosition = indexFingerTipLocation!
        }else{
          let delta = previousFingerTipPosition.y - indexFingerTipLocation!.y
          if abs(delta) >= movingTreshold{
            movingState = delta > 0 ? .up : .down
            previousFingerTipPosition = indexFingerTipLocation!
          }else{
            movingState = .nothing
          }
        }
        ///uncomment to draw point for finger tip
        ///showPoints(indexFingerTipLocation!, color: .red)
      } else {
        indexFingerTipLocation = nil
        previousFingerTipPosition = CGPoint(x: -1, y: -1)
        ///uncomment to remove point for finger when not found
        ///showPoints(CGPoint(x:0, y:0), color: .clear)
      }
    }
  }
  
  private func isPreviousFingerTipPositionNotSet() -> Bool {
    return previousFingerTipPosition.x == -1
  }
  
  private func handleChangeMovingState(_ newValue : MovingState){
    switch newValue {
    case .up:
      rotate(0.25)
    case .down:
      rotate(-0.25)
    case .nothing:
      avion?.removeAllActions()
    }
  }
  
  func showPoints(_ point: CGPoint, color: UIColor) {
    ///render on sublayer dot for Index finger TIP
    overlayLayer.sublayers?.removeAll()
    let circleLayer = CAShapeLayer();
    circleLayer.path = UIBezierPath(ovalIn: CGRect(x: point.x, y: point.y, width: 15, height: 15)).cgPath;
    overlayLayer.addSublayer(circleLayer)
  }
  
  func updatePredictionLabels(with message: String){
    let predictionAndMoving = message + " -> MoveState =\(movingState)"
    predictionLabel.text = predictionAndMoving
    predictionLabel2.text = predictionAndMoving
  }
}

