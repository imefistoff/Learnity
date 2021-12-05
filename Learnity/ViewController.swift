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
  let shipScene = SCNScene(named: "art.scnassets/ship.scn")!
  let solarScene = SCNScene(named: "art.scnassets/solar_system.scn")!
  let geometryScene = SCNScene(named: "art.scnassets/geometry.scn")!
  var scenes = [SCNScene]()
  var indexCurrentScene = 0
  
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
    
    scenes = [geometryScene, solarScene, shipScene]
    
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
    }
  }
  
  func removeOldObjectsFromScene(){
    for object in sceneViewLeft.scene.rootNode.childNodes {
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
    if frameCounter % predictEvery == 0 {
      guard let keypointsMultiArray = try? handObservation?.keypointsMultiArray() else { fatalError()}
      do {
        checkMoving(handObservation)
        let handPosePrediction = try gestureModel.prediction(poses: keypointsMultiArray)
        let confidence = handPosePrediction.labelProbabilities[handPosePrediction.label]!
        if isWaitingForGesture && confidence > 0.5 {
          gestureManager.setGestureType(handPosePrediction.label)
        } else {
            // TODO: check if we actually need this state update
            //          gestureManager.setGestureType(GestureType.nothing.rawValue)
        }
      }catch{
        print("Prediction error: \(error)")
      }
    }
  }
  
  private func checkMoving(_ handObservation: VNHumanHandPoseObservation?) {
    guard let handObservation = handObservation else {
      return
    }
    
    let landmarkConfidenceTreshold : Float = 0.2
    let fingerMovingThreshold : CGFloat = 0.05
    let indexFingerName = VNHumanHandPoseObservation.JointName.indexTip
    
    if let indexFingerPoint = try? handObservation.recognizedPoint(indexFingerName),
       indexFingerPoint.confidence > landmarkConfidenceTreshold {
      let normalizedLocation = indexFingerPoint.location
      let absXdiff = abs(previousFingerTipPosition.x - normalizedLocation.x)
      let absYdiff = abs(previousFingerTipPosition.y - normalizedLocation.y)
      let movingDelta = max(absXdiff, absYdiff)
      
      if movingDelta >= fingerMovingThreshold{
        disableGestureRecognition(for: 0.5)
      }
  
      previousFingerTipPosition = normalizedLocation
    }
    else {
      previousFingerTipPosition = CGPoint(x: -1, y: -1)
    }
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
    let externalLayerTransparency = currentObjects[self.indexFocusedObject].geometry?.firstMaterial?.transparency
    if externalLayerTransparency == 1 {
      disableGestureRecognition(for: 3)
      expandLayersAnimation()
      self.currentObjects[self.indexFocusedObject].geometry?.firstMaterial?.transparency = 0
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
    let externalLayerTransparency = currentObjects[self.indexFocusedObject].geometry?.firstMaterial?.transparency
    let nextLayerForRemove = layers.reversed().first { node in
      return node.isHidden
    }
    if let nextLayerForRemove = nextLayerForRemove {
      nextLayerForRemove.isHidden = false
    }else if externalLayerTransparency == 0{
      disableGestureRecognition(for: 3)
      unionLayersAnimation()
      DispatchQueue.main.asyncAfter(deadline: .now() + 2){
        self.currentObjects[self.indexFocusedObject].geometry?.firstMaterial?.transparency = 1
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
}

protocol SoundRecognitionDelegate {
  func snapDetected()
}

