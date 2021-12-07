import UIKit
import SceneKit
import ARKit
import SceneKit.ModelIO
import AVFAudio
import SoundAnalysis

class ViewController: UIViewController, ARSCNViewDelegate {
  
  @IBOutlet weak var sceneViewLeft: ARSCNView!
  @IBOutlet weak var sceneViewRight: ARSCNView!
  @IBOutlet weak var debugView: UIView!
  @IBOutlet weak var selectedAxesView: UIStackView!
  @IBOutlet weak var gestureTableView: UITableView!
  
  @IBOutlet weak var predictionLabel: UILabel!
  @IBOutlet weak var predictionLabel2: UILabel!
  
  var currentObjects = [SCNNode]()
  var initialObjectsClones = [SCNNode]()
  var indexFocusedObject = -1
  var layeredObject : SCNNode?
  var layers = [SCNNode]()
  
    //MARK: UI variables
  @IBOutlet weak var xHudSwitch: UISwitch!
  @IBOutlet weak var yHudSwitch: UISwitch!
  @IBOutlet weak var zHudSwitch: UISwitch!
  @IBOutlet weak var transformTypeLabel: UILabel!
  
  var isGesturesHudVisible = true
  var isAxesHudVisible = true {
    didSet {
      toggleUIVIew(for: selectedAxesView, isVisible: isAxesHudVisible)
        // TODO: move into a function
      if isAxesHudVisible {
        toggleUIVIew(for: gestureTableView, isVisible: false)
      }
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
        if self.isGesturesHudVisible {
          self.toggleUIVIew(for: self.gestureTableView, isVisible: true)
        }
        
        if self.isAxesHudVisible {
          self.isAxesHudVisible = false
        }
      })
    }
  }
  
    //MARK: Transformations variables
  var translationStep : Float = 0.1 // 0.1 meters
  var rotationStep : CGFloat = 0.1 // 0.1 radian => aprox 6 degree
  var scaleStep : CGFloat = 1.05 // +5% scale
  var negativeScaleStep : CGFloat = 0.95 // -5% scale
  
  var isOxSelected = false {
    didSet {
      toggleSwitch(for: xHudSwitch, isOn: isOxSelected)
    }
  }
  var isOySelected = false {
    didSet {
      toggleSwitch(for: yHudSwitch, isOn: isOySelected)
    }
  }
  var isOzSelected = false {
    didSet {
      toggleSwitch(for: zHudSwitch, isOn: isOzSelected)
    }
  }
  
    //MARK: Gesture prediction variables
  var gestureModel : FullModelTest!
  let predictEvery = 3
  var frameCounter = -1
  
  //MARK: Sound prediction variables
  var soundModel : SnapDetector!
  private let audioEngine: AVAudioEngine = AVAudioEngine()
  private let inputBus: AVAudioNodeBus = AVAudioNodeBus(0)
  private var inputFormat: AVAudioFormat!
  private var streamAnalyzer: SNAudioStreamAnalyzer!
  private let resultsObserver = SoundResultsObserver()
  private let analysisQueue = DispatchQueue(label: "com.learnity.soundPrediction")

  
    //MARK: Follow gesture variables
  var isWaitingForGesture = true
  let predictGestureMovingEvery = 9
  var predictGestureCounter = -1
  var previousFingerTipPosition = CGPoint(x: -1, y: -1)
  var disableGestureDetectionTimer : Timer?
  
    //MARK: Logic management
  let gestureManager = ControlManager.shared
  
    //MARK: Scenes
  let muscularScene = SCNScene(named: "art.scnassets/muscular_scene.scn")!
  let solarScene = SCNScene(named: "art.scnassets/solar_system.scn")!
  let geometryScene = SCNScene(named: "art.scnassets/geometry.scn")!
  var scenes = [SCNScene]()
  var indexCurrentScene = 0
  var explodeObject : SCNNode?
  var whiteboardObject : SCNNode?
  var whiteboardWritablePart : SCNNode?
  var whiteboardLenght : Float = 0
  var whiteboardHeight : Float = 0
  var centerPointOfObjects : SCNVector3?
  
  //MARK: Drawing stuff
  @IBOutlet var drawingViews: [UIView]!
  private let drawLeftOverlay = CAShapeLayer()
  private let drawRightOverlay = CAShapeLayer()
  private var drawPath = UIBezierPath()
  private var savedDrawPath = UIBezierPath().cgPath
  private var isFirstSegmentPath = true
  private var lastDrawPoint: CGPoint?
  
    //MARK:  DEBUG MODE VARIABLES
  @IBOutlet weak var leftSceneContainer: UIView!
  @IBOutlet weak var segmentedControl: UISegmentedControl!
  @IBOutlet weak var xSwitch: UISwitch!
  @IBOutlet weak var ySwitch: UISwitch!
  @IBOutlet weak var zSwitch: UISwitch!
  let isDebug = false
  var selectedTransformationType = GeometricTransformationTypes.translation {
    didSet {
      transformTypeLabel.text = selectedTransformationType.toString()
    }
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()
    gestureTableView.delegate = self
    gestureTableView.dataSource = self
    gestureManager.delegate = self
    
    setupSoundPrediciton()
    
    do {
      gestureModel = try FullModelTest(configuration: MLModelConfiguration())
    } catch {
      fatalError("Cannot get CoreML model for gesture. Investigate please.")
    }
    
    self.debugView.isHidden = !isDebug
    
    scenes = [muscularScene, geometryScene, solarScene]
    
    UIApplication.shared.isIdleTimerDisabled = true
    
    sceneViewLeft.delegate = self
    sceneViewLeft.session.delegate = self
    sceneViewLeft.isPlaying = true
    sceneViewRight.isPlaying = true
    
    let mainScene = SCNScene(named: "art.scnassets/main.scn")!
    sceneViewLeft.scene = mainScene
    sceneViewRight.scene = mainScene
    
    explodeObject = sceneViewLeft.scene.rootNode.childNode(withName: "Explode_object_permanent", recursively: false)
    if let explodeObject = explodeObject {
      explodeObject.centerPivot()
    }
    
    whiteboardObject = sceneViewLeft.scene.rootNode.childNode(withName: "Whiteboard_permanent", recursively: false)
    if let whiteboard = whiteboardObject {
      whiteboard.centerPivot()
      let translationAction = SCNAction.move(to: SCNVector3(1.5, -0.9, -2), duration: 5)
      whiteboard.runAction(translationAction)
      whiteboardWritablePart = whiteboard.childNode(withName: "Whiteboard_writable", recursively: false)
      
      var min = SCNVector3Zero
      var max = SCNVector3Zero
      whiteboardWritablePart!.__getBoundingBoxMin(&min, max: &max)
      
      whiteboardLenght = max.z - min.z
      whiteboardHeight = max.y - min.y
    }
    
    collectAllObjects(from: getNextScene())
    insertNewObjectsIntoScene()
    
    setupDrawingSublayers()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
      /// Create a session configuration
    let configuration = ARWorldTrackingConfiguration()
    configuration.frameSemantics.insert(.personSegmentationWithDepth)
    configuration.planeDetection = [.horizontal, .vertical]
    
    sceneViewLeft.preferredFramesPerSecond = 30
    sceneViewRight.preferredFramesPerSecond = 30
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
    if indexCurrentScene > scenes.count - 1 {
      indexCurrentScene = 0
    }else{
      indexCurrentScene += 1
    }
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
      case .translation : translate(by: 0.3)
      case .rotation : rotate(by: 5)
      case .scale : scale(by: 1.25)
    }
  }
  
  @IBAction func tapMinus(_ sender: Any) {
    switch selectedTransformationType {
      case .translation : translate(by: -0.3)
      case .rotation : rotate(by: -5)
      case .scale : scale(by: 0.75)
    }
  }
  
  func setupDrawingSublayers(){
    drawLeftOverlay.frame = view.layer.bounds
    drawLeftOverlay.lineWidth = 5
    drawLeftOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
    drawLeftOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
    drawLeftOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
    drawLeftOverlay.lineCap = .round
    
    drawRightOverlay.frame = view.layer.bounds
    drawRightOverlay.lineWidth = 5
    drawRightOverlay.backgroundColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0.5).cgColor
    drawRightOverlay.strokeColor = #colorLiteral(red: 0.6, green: 0.1, blue: 0.3, alpha: 1).cgColor
    drawRightOverlay.fillColor = #colorLiteral(red: 0.9999018312, green: 1, blue: 0.9998798966, alpha: 0).cgColor
    drawRightOverlay.lineCap = .round
    
    drawingViews[0].layer.addSublayer(drawLeftOverlay)
    drawingViews[1].layer.addSublayer(drawRightOverlay)
    
    drawingViews.forEach { view in
      view.isHidden = true
    }
  }
  
  func toggleUIVIew(for hud: UIView, isVisible: Bool) {
    UIView.animate(withDuration: 0.4) {
      hud.alpha = isVisible ? 1.0 : 0.0
    }
  }
  
  func toggleSwitch(for switchControl: UISwitch, isOn: Bool) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: {
      switchControl.setOn(isOn, animated: true)
    })
  }
  
  func setupSoundPrediciton() {
    resultsObserver.delegate = self
    inputFormat = audioEngine.inputNode.inputFormat(forBus: inputBus)
    
    do {
      soundModel = try SnapDetector(configuration: MLModelConfiguration())
    } catch {
      fatalError("Cannot get CoreML model for sound. Investigate please.")
    }
    
    do {
      try audioEngine.start()
      audioEngine.inputNode.installTap(onBus: inputBus,
                                       bufferSize: 8192,
                                       format: inputFormat, block: analyzeAudio(buffer:at:))
      
      streamAnalyzer = SNAudioStreamAnalyzer(format: inputFormat)
      
      let request = try SNClassifySoundRequest(mlModel: soundModel.model)
      
      try streamAnalyzer.add(request,
                             withObserver: resultsObserver)
      
      
    } catch {
      print("Unable to start AVAudioEngine: \(error.localizedDescription)")
    }
  }
  
  func analyzeAudio(buffer: AVAudioBuffer, at time: AVAudioTime) {
    analysisQueue.async {
      self.streamAnalyzer.analyze(buffer,
                                  atAudioFramePosition: time.sampleTime)
    }
  }
  
  func insertNewObjectsIntoScene(){
    for node in currentObjects {
      sceneViewLeft.scene.rootNode.addChildNode(node)
      node.scale = SCNVector3(0,0,0)
    }
    centerPointOfObjects = calculateMidPointOfObjects()
    disableGestureRecognition(for: 3.1)
    //explosion animation
    if let explodeObject = explodeObject,
      let centerPointOfObjects = centerPointOfObjects {
      explodeObject.position = centerPointOfObjects
      explodeObject.isHidden = false
      explodeObject.enumerateChildNodes { subnode, _ in
        subnode.animationPlayer(forKey: "transform")?.play()
      }
      
      DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
        explodeObject.isHidden = true
        explodeObject.enumerateChildNodes { subnode, _ in
          subnode.animationPlayer(forKey: "transform")?.stop()
        }
      }
    }
    
    
    //animate growing objects
    for objIndex in currentObjects.indices {
      let object = currentObjects[objIndex]
      //let initialScaleValue = initialObjectsClones[objIndex].scale
      let scaleValue = initialObjectsClones[objIndex].scale.x
      let growingAction = SCNAction.scale(to: CGFloat(scaleValue), duration: 3)
      object.runAction(growingAction)
    }
  }
  
  func calculateMidPointOfObjects() -> SCNVector3{
    var midPoint = SCNVector3(0.0, 0.0, 0.0)
    
    for object in currentObjects {
      midPoint += object.position
    }
    
    return midPoint / Float(currentObjects.count)
  }
  
  func removeOldObjectsFromScene(){
    for object in sceneViewLeft.scene.rootNode.childNodes {
      if object.isPermanent { continue }
      object.removeFromParentNode()
    }
  }
  
  func getNextScene() -> SCNScene {
    return scenes[indexCurrentScene]
  }
  
  func resetSceneInitialData() {
    indexFocusedObject = -1
    currentObjects.removeAll()
    initialObjectsClones.removeAll()
  }
  
  func collectAllObjects(from scene: SCNScene) {
    let allNodes = scene.rootNode.childNodes { object, _ in
      return true
    }
    for node in allNodes {
      if node.isFocusable {
        node.centerPivot()
        currentObjects.append(node.clone())
        initialObjectsClones.append(node.clone())
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
  
  func rotate(by step: CGFloat){
    if indexFocusedObject != -1 {
      let rotateAction = SCNAction.rotate(by: step,
                                          around: SCNVector3(isOxSelected ? 1 : 0,
                                                             isOySelected ? 1 : 0,
                                                             isOzSelected ? 1 : 0),
                                          duration: 0.3)
      currentObjects[indexFocusedObject].runAction(rotateAction)
    }
  }
  
  func scale(by step: CGFloat){
    if indexFocusedObject != -1 {
      let scaleAction = SCNAction.scale(by: step, duration: 2)
      currentObjects[indexFocusedObject].runAction(scaleAction)
    }
  }
  
  func translate(by step: Float) {
    if indexFocusedObject != -1 {
      let translateAction = SCNAction.move(by: SCNVector3(isOxSelected ? step: 0,
                                                          isOySelected ? step : 0,
                                                          isOzSelected ? step : 0), duration: 2)
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
    //if frameCounter % predictEvery == 0 {
      guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError()}
      do {
        checkMoving(handObservation)
        let handPosePrediction = try gestureModel.prediction(poses: keypointsMultiArray)
        let confidence = handPosePrediction.labelProbabilities[handPosePrediction.label]!
        print("\(handPosePrediction.label) with \(confidence)")
        if isWaitingForGesture && confidence > 0.55 {
          gestureManager.setGestureType(handPosePrediction.label)
        } else {
            // TODO: check if we actually need this state update
           //gestureManager.setGestureType(GestureType.nothing.rawValue)
        }
      }catch{
        print("Prediction error: \(error)")
      }
    //}
  }
  
  private func checkMoving(_ handObservation: VNHumanHandPoseObservation?) {
    guard let handObservation = handObservation else {
      return
    }
    
    let landmarkConfidenceTreshold : Float = 0.6
    let fingerMovingThreshold : CGFloat = 0.05
    let indexFingerName = VNHumanHandPoseObservation.JointName.indexTip
    let thumbFingerName = VNHumanHandPoseObservation.JointName.thumbTip
    
    if let indexFingerPoint = try? handObservation.recognizedPoint(indexFingerName),
       let thumbPoint = try? handObservation.recognizedPoint(thumbFingerName),
       thumbPoint.confidence > landmarkConfidenceTreshold,
       indexFingerPoint.confidence > landmarkConfidenceTreshold {
      let indexNormalizedLocation = indexFingerPoint.location
      let thumbNormalizedLocation = thumbPoint.location
      
      if gestureManager.flowState == .notes {
        
        let width = sceneViewLeft.frame.width
        let heigth = sceneViewLeft.frame.height
        
        let convertedIndex = CGPoint(x: indexNormalizedLocation.x * width, y: heigth - indexNormalizedLocation.y * heigth)
        let convertedThumb = CGPoint(x: thumbNormalizedLocation.x * width, y: heigth - thumbNormalizedLocation.y * heigth)
        
        let distance = convertedIndex.distance(from: convertedThumb)
        
        let midPoint = CGPoint.midPoint(p1: convertedIndex, p2: convertedThumb)
        if gestureManager.gestureType == .pinch && distance < 40{
          draw(on: midPoint, isLastPoint: false)
        }else{
          draw(on: midPoint, isLastPoint: true)
        }

      }
      
      let absXdiff = abs(previousFingerTipPosition.x - indexNormalizedLocation.x)
      let absYdiff = abs(previousFingerTipPosition.y - indexNormalizedLocation.y)
      let movingDelta = max(absXdiff, absYdiff)
      
      if movingDelta >= fingerMovingThreshold{
        disableGestureRecognition(for: 0.5)
      }
  
      previousFingerTipPosition = indexNormalizedLocation
    }
    else {
      previousFingerTipPosition = CGPoint(x: -1, y: -1)
    }
  }
  
  func draw(on point: CGPoint, isLastPoint: Bool){
    if isLastPoint {
      if let lastPoint = lastDrawPoint {
          // Add a straight line from the last midpoint to the end of the stroke.
        drawPath.addLine(to: lastPoint)
      }
        // We are done drawing, so reset the last draw point.
      lastDrawPoint = nil
    } else {
      if lastDrawPoint == nil {
          // This is the beginning of the stroke.
        drawPath.move(to: point)
        isFirstSegmentPath = true
      } else {
        let lastPoint = lastDrawPoint!
          // Get the midpoint between the last draw point and the new point.
        let midPoint = CGPoint.midPoint(p1: lastPoint, p2: point)
        if isFirstSegmentPath {
            // If it's the first segment of the stroke, draw a line to the midpoint.
          drawPath.addLine(to: midPoint)
          isFirstSegmentPath = false
        } else {
            // Otherwise, draw a curve to a midpoint using the last draw point as a control point.
          drawPath.addQuadCurve(to: midPoint, controlPoint: lastPoint)
        }
      }
        // Remember the last draw point for the next update pass.
      lastDrawPoint = point
    }
    
    drawLeftOverlay.path = drawPath.cgPath
    drawRightOverlay.path = drawPath.cgPath
  }
  
  private func isFingerTipPositionNotSet(_ tip: CGPoint) -> Bool {
    return tip.x == -1
  }
  
  func expandLayersAnimation() {
    for index in layers.indices {
      if index == 0 { continue }
      let layer = layers[index]
      layer.runAction(SCNAction.move(by: SCNVector3(0,0,1 - (Float(index) * 0.1)) * 100 * Float(index), duration: 2))
    }
  }
  
  func unionLayersAnimation() {
    for index in layers.indices {
      if index == 0 { continue }
      let layer = layers[index]
      layer.runAction(SCNAction.move(by: SCNVector3(0,0,1 - (Float(index) * 0.1)) * 100 * Float(index) * -1, duration: 2))
    }
  }
}

extension ViewController : GestureRecognitionDelegate {
  func disableGestureRecognition(for seconds : Double){
    isWaitingForGesture = false
    disableGestureDetectionTimer?.invalidate()
    disableGestureDetectionTimer = nil
    disableGestureDetectionTimer = Timer.scheduledTimer(withTimeInterval: seconds, repeats: false){
      _ in
      self.isWaitingForGesture = true
    }
  }
  
  func focusOnNextObject() {
    let prevIndexFocusedObject = indexFocusedObject
    
    let isLeft = gestureManager.gestureType == .swipeLeft
    if indexFocusedObject >= currentObjects.count - 1 && !isLeft {
      indexFocusedObject = 0
    }else if indexFocusedObject == 0 && isLeft {
      indexFocusedObject = currentObjects.count - 1
    } else if isLeft {
      indexFocusedObject -= 1
    } else {
      indexFocusedObject += 1
    }
    
      //return object to its initial position
    if prevIndexFocusedObject != -1 {
      let initialScaleValue = CGFloat(initialObjectsClones[indexFocusedObject].scale.x)
      currentObjects[indexFocusedObject].runAction(SCNAction.scale(to: initialScaleValue, duration: 2))
      translateAndRotateObjectAction(startObject: currentObjects[prevIndexFocusedObject], finalObject: initialObjectsClones[prevIndexFocusedObject], isReturningToInitialPosition: true)
    }
    
    GesturesPresenter.shared.focusedObject = currentObjects[indexFocusedObject]
    
    moveObjectInFrontOfCamera()
  }
  
  func saveChanges() {
    if indexFocusedObject != -1
    {
      initialObjectsClones[indexFocusedObject]  =  currentObjects[indexFocusedObject].clone()
    }
  }
  
  func discardChanges() {
    if indexFocusedObject != -1
    {
      let initialScaleValue = CGFloat(initialObjectsClones[indexFocusedObject].scale.x)
      currentObjects[indexFocusedObject].runAction(SCNAction.scale(to: initialScaleValue, duration: 2))
      moveObjectInFrontOfCamera()
    }
  }
  
  func increaseTransformActionValue() {
    switch selectedTransformationType {
      case .translation : translate(by: translationStep)
      case .rotation : rotate(by: rotationStep)
      case .scale : scale(by: scaleStep)
    }
  }
  
  func decreaseTransformActionValue() {
    switch selectedTransformationType {
      case .translation : translate(by: -translationStep)
      case .rotation : rotate(by: -rotationStep)
      case .scale : scale(by: negativeScaleStep)
    }
  }
  
  func unfocus() {
      //return object to its initial position
    if indexFocusedObject != -1 {
      let initialScaleValue = CGFloat(initialObjectsClones[indexFocusedObject].scale.x)
      currentObjects[indexFocusedObject].runAction(SCNAction.scale(to: initialScaleValue, duration: 2))
      translateAndRotateObjectAction(startObject: currentObjects[indexFocusedObject], finalObject: initialObjectsClones[indexFocusedObject], isReturningToInitialPosition: true)
    }
    
    indexFocusedObject = -1
  }
  
  func loadNextScene() {
    let isLeft = gestureManager.gestureType == .swipeLeft
    if indexCurrentScene >= scenes.count - 1 && !isLeft {
      indexCurrentScene = 0
    }else if indexCurrentScene == 0 && isLeft {
      indexCurrentScene = scenes.count - 1
    } else if isLeft {
      indexCurrentScene -= 1
    } else {
      indexCurrentScene += 1
    }
    resetSceneInitialData()
    removeOldObjectsFromScene()
    let nextScene = getNextScene()
    collectAllObjects(from: nextScene)
    insertNewObjectsIntoScene()
  }
  
  func removeUpperLayer() {
    var layerCase = LayerPresenterCase.other
    let focusedObject = currentObjects[self.indexFocusedObject]
    let externalLayerTransparency = focusedObject.geometry?.firstMaterial?.transparency
    if focusedObject.isExternalLayer && externalLayerTransparency == 1  {
      disableGestureRecognition(for: 3)
      expandLayersAnimation()
      focusedObject.geometry?.firstMaterial?.transparency = 0
    } else {
      let nextLayerForRemove = layers.first(where: { node in
        if layers.last! == node {
          layerCase = .last
          return false
        }
        return !node.isHidden
      })
      if let nextLayerForRemove = nextLayerForRemove {
        nextLayerForRemove.isHidden = true
        if layers[layers.count - 2].isHidden {
          layerCase = .last
        }
      }
    }
    GesturesPresenter.shared.updateGestureList(layerCase: layerCase)
  }
  
  func revertRemovedLayer() {
    var layerCase = LayerPresenterCase.other
    let focusedObject = currentObjects[self.indexFocusedObject]
    let externalLayerTransparency = focusedObject.geometry?.firstMaterial?.transparency
    let nextLayerForRemove = layers.reversed().first { node in
      return node.isHidden
    }
    if let nextLayerForRemove = nextLayerForRemove {
      nextLayerForRemove.isHidden = false
    }else if focusedObject.isExternalLayer && externalLayerTransparency == 0{
      disableGestureRecognition(for: 3)
      unionLayersAnimation()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2){
        focusedObject.geometry?.firstMaterial?.transparency = 1
      }
      layerCase = .first
    }
    GesturesPresenter.shared.updateGestureList(layerCase: layerCase)

  }
  
  func prepareLayeredNode(){
    layeredObject = currentObjects[indexFocusedObject].getLayeredSubNode
    
    if let finalObjTransform = sceneViewLeft.pointOfView?.transform, let layeredObject = layeredObject {
      let finalObjOrientation = SCNVector3(-finalObjTransform.m31, -finalObjTransform.m32, -finalObjTransform.m33)
      let finalObjLocation = SCNVector3(layeredObject.transform.m41, layeredObject.transform.m42, layeredObject.transform.m43)
      let finalObjPosition = finalObjOrientation + finalObjLocation
      layeredObject.position = finalObjPosition
    }
    
    layeredObject?.eulerAngles = SCNVector3Make(0, Float(Double.pi)/2, 0);
    
    
    guard let layeredObject = layeredObject else {
      print("Can't find layered object.")
      return
    }
    
    layers = layeredObject.childNodes(passingTest: { node, _ in
      return node.name != nil && node.name!.contains("slice$")
    })
    
    layers.sort { leftNode, rightNode in
      let leftNodeOrderInt = Int(leftNode.name!.split(separator: "$")[1])
      let rightNodeOrderInt = Int(rightNode.name!.split(separator: "$")[1])
      return  leftNodeOrderInt! < rightNodeOrderInt!
    }
  }
  
  func discardNoticeChanges() {
    hideDrawingOverlay()
    drawPath.cgPath = savedDrawPath
  }
  
  func saveNoticeChanges() {
    hideDrawingOverlay()
    savedDrawPath = drawPath.cgPath
    updateWhiteboard()
  }
  
  func clearDrawingPath() {
    drawPath = UIBezierPath()
  }

  
  private func updateWhiteboard() {
    drawingViews[0].isHidden = false
    let image = drawingViews[0].asImage().resizableImage(withCapInsets: .zero, resizingMode: .stretch)
    drawingViews[0].isHidden = true
    let overlayPlane = whiteboardWritablePart!.getOverlayPlane
    overlayPlane.geometry?.firstMaterial?.diffuse.contents = image.withHorizontallyFlippedOrientation()
  }
  
  private func hideDrawingOverlay() {
    drawingViews.forEach { view in
      view.isHidden = true
    }
  }
}

protocol GestureRecognitionDelegate{
  func disableGestureRecognition(for seconds: Double)
  func focusOnNextObject()
  func saveChanges()
  func discardChanges()
  func increaseTransformActionValue()
  func decreaseTransformActionValue()
  func unfocus()
  func loadNextScene()
  func removeUpperLayer()
  func prepareLayeredNode()
  func discardNoticeChanges()
  func saveNoticeChanges()
}

extension ViewController: UITableViewDelegate, UITableViewDataSource{
  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return GesturesPresenter.shared.gesturesList.count
  }
  
  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "gestureInfo", for: indexPath) as! GestureInfoCell
    let currentGest = GesturesPresenter.shared.gesturesList[indexPath.row]
    
    cell.setGesture(gesture: currentGest, index: indexPath.row)
    return cell
  }
}

extension ViewController: SoundRecognitionDelegate {
  func snapDetected() {
    resultsObserver.isWaitingForSnap = false
    DispatchQueue.main.sync {
      self.isGesturesHudVisible = !self.isGesturesHudVisible
      self.toggleUIVIew(for: self.gestureTableView, isVisible: self.isGesturesHudVisible)
    }
    
    DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: {
      self.resultsObserver.isWaitingForSnap = true
    })
  }
}

protocol SoundRecognitionDelegate {
  func snapDetected()
}

