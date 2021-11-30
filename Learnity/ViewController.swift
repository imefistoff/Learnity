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
  @IBOutlet weak var gestureTableView: UITableView!
  
  @IBOutlet weak var predictionLabel: UILabel!
  @IBOutlet weak var predictionLabel2: UILabel!
  
  var currentObjects = [SCNNode]()
  var initialObjectsClones = [SCNNode]()
  var indexFocusedObject = -1
  
  //MARK: Prediction variables
  var model : Pose6AndBackground!
  let predictEvery = 3
  var frameCounter = -1
  
  //MARK: Follow gesture variables
  var isWaitingForGesture = true
  let predictGestureMovingEvery = 9
  var previousFingerTipPosition = CGPoint(x: -1, y: -1)
  var movingState = MovingState.nothing {
    willSet{
      handleChangeMovingState(newValue)
    }
  }
  var movingTreshold = CGFloat(50)
  
  //MARK: Logic management
  let gestureManager = ControlManager.shared
  
  //MARK: Scenes
  let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
  let earthScene = SCNScene(named: "art.scnassets/earth.scn")!
  let geometryScene = SCNScene(named: "art.scnassets/geometry.scn")!
  var scenes = [SCNScene]()
  var indexCurrentScene = 0
  
  //MARK:  DEBUG MODE VARIABLES
  @IBOutlet weak var leftSceneContainer: UIView!
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var xSwitch: UISwitch!
  @IBOutlet weak var ySwitch: UISwitch!
  @IBOutlet weak var zSwitch: UISwitch!
  let isDebug = true
  var selectedTransformationType = GeometricTransformationTypes.translation
  
  override func viewDidLoad() {
    super.viewDidLoad()
    gestureTableView.delegate = self
    gestureTableView.dataSource = self
    gestureManager.delegate = self
    
    do {
      model = try Pose6AndBackground(configuration: MLModelConfiguration())
    } catch {
      fatalError("Cannot get CoreML model for gesture. Investigate please.")
    }
    
    self.debugView.isHidden = !isDebug
    
    scenes = [geometryScene, earthScene, shipScene]
    
    UIApplication.shared.isIdleTimerDisabled = true
    
    sceneViewLeft.delegate = self
    sceneViewLeft.session.delegate = self
    sceneViewLeft.isPlaying = true
    sceneViewRight.isPlaying = true
    
    let mainScene = SCNScene(named: "art.scnassets/main.scn")!
    sceneViewLeft.scene = mainScene
    sceneViewRight.scene = mainScene
    
    collectAllObjects(from: getNextScene())
    insertNewObjectsIntoScene()
    
    if let camera = sceneViewLeft.pointOfView?.camera {
      camera.fieldOfView = CGFloat(138)
    }
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
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
  
  @IBAction func saveChangesForCurrentObject(_ sender: Any) {
    if indexFocusedObject != -1
    {
      initialObjectsClones[indexFocusedObject]  =  currentObjects[indexFocusedObject].clone()
    }
  }
  
  @IBAction func discardChangesForCurrentObject(_ sender: Any) {
    if indexFocusedObject != -1
    {
      let initialScaleValue = CGFloat(initialObjectsClones[indexFocusedObject].scale.x)
      currentObjects[indexFocusedObject].runAction(SCNAction.scale(to: initialScaleValue, duration: 2))
      moveObjectInFrontOfCamera()
    }
  }
  
  @IBAction func loadNextScene(_ sender: Any) {
    indexCurrentScene += 1
    resetSceneInitialData()
    removeOldObjectsFromScene()
    let nextScene = getNextScene()
    collectAllObjects(from: nextScene)
    insertNewObjectsIntoScene()
  }
  
  @IBAction func focusNextObject(_ sender: Any) {
    let prevIndexFocusedObject = indexFocusedObject
    if indexFocusedObject < 0 || indexFocusedObject >= currentObjects.count - 1 {
      indexFocusedObject = 0
    } else {
      indexFocusedObject += 1
    }
    
    //return object to its initial position
    if prevIndexFocusedObject != -1 {
      let initialScaleValue = CGFloat(initialObjectsClones[indexFocusedObject].scale.x)
      currentObjects[indexFocusedObject].runAction(SCNAction.scale(to: initialScaleValue, duration: 2))
      translateAndRotateObjectAction(startObject: currentObjects[prevIndexFocusedObject], finalObject: initialObjectsClones[prevIndexFocusedObject], isReturningToInitialPosition: true)
    }
    
    // TODO: add this line after merge in focusOnNextObject 
    GesturesPresenter.shared.focusedObject = currentObjects[indexFocusedObject]
    
    moveObjectInFrontOfCamera()
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
  
  func insertNewObjectsIntoScene(){
    for object in currentObjects {
      sceneViewLeft.scene.rootNode.addChildNode(object)
    }
  }
  
  func removeOldObjectsFromScene(){
    for object in sceneViewLeft.scene.rootNode.childNodes {
      object.removeFromParentNode()
    }
  }
  
  func getNextScene() -> SCNScene {
    if indexCurrentScene > scenes.count - 1 {
      indexCurrentScene = 0
    }
    return scenes[indexCurrentScene]
  }
  
  func resetSceneInitialData() {
    indexFocusedObject = -1
    currentObjects.removeAll()
    initialObjectsClones.removeAll()
  }
  
  func collectAllObjects(from scene: SCNScene) {
    for object in scene.rootNode.childNodes {
      if object.name != nil {
        object.centerPivot()
        currentObjects.append(object.clone())
        initialObjectsClones.append(object.clone())
      }
    }
  }
  
  func moveObjectInFrontOfCamera() {
    if let pov = sceneViewLeft.pointOfView {
      let nextObjectToFocus = currentObjects[indexFocusedObject]
      translateAndRotateObjectAction(startObject: nextObjectToFocus, finalObject: pov, isReturningToInitialPosition: false)
    }
  }
  
  func translateAndRotateObjectAction(startObject: SCNNode, finalObject: SCNNode, isReturningToInitialPosition: Bool) {
    //calculate final rotation
    let finalObjRotation = finalObject.rotation
    let rotateAction = SCNAction.rotate(toAxisAngle: finalObjRotation,
                                        duration: 1)
    
    //calculate final position
    let finalObjTransform = finalObject.transform
    let finalObjOrientation = SCNVector3(-finalObjTransform.m31, -finalObjTransform.m32, -finalObjTransform.m33)
    let finalObjLocation = SCNVector3(finalObjTransform.m41, finalObjTransform.m42, finalObjTransform.m43)
    let finalObjPosition = (finalObjOrientation * (isReturningToInitialPosition ? 0 : 2)) + finalObjLocation
    
    let translateAction = SCNAction.move(to: finalObjPosition, duration: 2)
    
    let focusAction = SCNAction.group([rotateAction, translateAction])
    startObject.runAction(focusAction)
  }
  
  func rotate(_ step: CGFloat){
    if indexFocusedObject != -1 {
      let rotateAction = SCNAction.rotate(by: step,
                                          around: SCNVector3(xSwitch.isOn ? 1 : 0,
                                                             ySwitch.isOn ? 1 : 0,
                                                             zSwitch.isOn ? 1 : 0),
                                          duration: 0.3)
      currentObjects[indexFocusedObject].runAction(rotateAction)
    }
  }
  
  func scale(_ step: CGFloat){
    if indexFocusedObject != -1 {
      let scaleAction = SCNAction.scale(by: step, duration: 2)
      currentObjects[indexFocusedObject].runAction(scaleAction)
    }
  }
  
  func translate(_ step: Float) {
    if indexFocusedObject != -1 {
      let translateAction = SCNAction.move(by: SCNVector3(xSwitch.isOn ? step: 0,
                                                          ySwitch.isOn ? step : 0,
                                                          zSwitch.isOn ? step : 0), duration: 2)
      currentObjects[indexFocusedObject].runAction(translateAction)
    }
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
    if !isWaitingForGesture { return }
    
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
      //Aici intra cand nu este mana in cadru
      return
    }
    let handObservation = handPoses.first
    if frameCounter % predictEvery == 0 {
      guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError()}
      do {
        let handPosePrediction = try model.prediction(poses: keypointsMultiArray)
        let confidence = handPosePrediction.labelProbabilities[handPosePrediction.label]!
        if confidence > 0.5 {
          updatePredictionLabels(with: "\(handPosePrediction.label) \(confidence)")
          gestureManager.setGestureType(handPosePrediction.label)
        } else {
          // TODO: check if we actually need this state update
//          gestureManager.setGestureType(GestureType.nothing.rawValue)
        }
      }catch{
        print("Prediction error: \(error)")
      }
      
      ///monitoring Finger Index TIP position on screen (up/down only)
      //checkMoving(handObservation)
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
        indexFingerTipLocation = CGPoint(x: normalizedLocation.x * width, y: normalizedLocation.y * height)
        
        if isPreviousFingerTipPositionNotSet() {
          previousFingerTipPosition = indexFingerTipLocation!
        } else {
          let delta = previousFingerTipPosition.y - indexFingerTipLocation!.y
          if abs(delta) >= movingTreshold{
            movingState = delta > 0 ? .up : .down
            previousFingerTipPosition = indexFingerTipLocation!
          } else {
            movingState = .nothing
          }
        }
      } else {
        indexFingerTipLocation = nil
        previousFingerTipPosition = CGPoint(x: -1, y: -1)
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
      if !currentObjects.isEmpty && indexFocusedObject >= 0 {
        currentObjects[indexFocusedObject].removeAllActions()
      }
    }
  }
  
  func updatePredictionLabels(with message: String){
    let predictionAndMoving = message + " -> MoveState =\(movingState)"
    predictionLabel.text = predictionAndMoving
    predictionLabel2.text = predictionAndMoving
  }
}

extension ViewController : GestureRecognitionDelegate {
  func disableGestureRecognitionForShort(){
    isWaitingForGesture = false
    DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: {
      self.isWaitingForGesture = true
    })
  }
}

extension ViewController: UITableViewDelegate, UITableViewDataSource{
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return GesturesPresenter.shared.gesturesList.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "gestureInfo", for: indexPath) as! GestureInfoCell
    let currentGest = GesturesPresenter.shared.gesturesList[indexPath.row]
    
    cell.setGesture(gesture: currentGest)
    return cell
  }
  
  
}

protocol GestureRecognitionDelegate{
  func disableGestureRecognitionForShort()
}

