/// Copyright (c) 2019 Razeware LLC
/// 
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
/// 
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
/// 
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
/// 
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import SpriteKit
import AVFoundation

class GameScene: SKScene {
  private var isLevelOver = false
  private var didCutVine = false
  
  private var sliceSoundAction: SKAction!
  private var splashSoundAction: SKAction!
  private var nomNomSoundAction: SKAction!
  
  private var particles: SKEmitterNode?
  private var crocodile: SKSpriteNode!
  private var prize: SKSpriteNode!
  
  private static var backgroundMusicPlayer: AVAudioPlayer!
  
  override func didMove(to view: SKView) {
    setUpPhysics()
    setUpScenery()
    setUpPrize()
    setUpVines()
    setUpCrocodile()
    setUpAudio()
  }
  
  //MARK: - Level setup
  
  private func setUpPhysics() {
    /*
     Every SKScene has a physics world associated.
     Because we want to modify some of its values and use its methods, we need to set ourselves as delegate.
     Gravity is set as the standard earth gravity.
     TODO: Change gravity values and see how it behaves.
     */
    physicsWorld.contactDelegate = self
    physicsWorld.gravity = CGVector(dx: 0.0, dy: -9.8)
    physicsWorld.speed = 1.0
  }
  
  private func setUpScenery() {
    let background = SKSpriteNode(imageNamed: ImageName.background)
    background.anchorPoint = CGPoint(x: 0, y: 0)
    background.position = CGPoint(x: 0, y: 0)
    background.zPosition = Layer.background
    background.size = CGSize(width: size.width, height: size.height)
    addChild(background)
    
    let water = SKSpriteNode(imageNamed: ImageName.water)
    water.anchorPoint = CGPoint(x: 0, y: 0)
    water.position = CGPoint(x: 0, y: 0)
    water.zPosition = Layer.foreground
    water.size = CGSize(width: size.width, height: size.height * 0.2139)
    addChild(water)
  }
  
  private func setUpPrize() {
    prize = SKSpriteNode(imageNamed: ImageName.prize)
    prize.position = CGPoint(x: size.width * 0.5, y: size.height * 0.7)
    prize.zPosition = Layer.prize
    // Prize's hitbox is treated as a circle
    prize.physicsBody = SKPhysicsBody(circleOfRadius: prize.size.height / 2)
    prize.physicsBody?.categoryBitMask = PhysicsCategory.prize
    prize.physicsBody?.collisionBitMask = 0
    // Density of the object, expressed in kilograms per square meter
    prize.physicsBody?.density = 0.5
    
    addChild(prize)
    
    // Notice that here isDynamic is not set to false. Prize node has to move around, following the laws of physics. isDynamic is automatically set to true
  }
  
  //MARK: - Vine methods
  
  /*
   A single vine bends, so we need to implement each vine as an array of segments with flexible joints, similar to a chain.
   Each vine has three significant attributes:
   - anchorPoint: A CGPoint indicating where the end of the vine connects to the tree
   - length: An Int representing the number of segments in the vine
   - name: A String used to identify which vine a given segment belongs to
   
   Game logic has to be independent from level data. A good way to do this is by storing it in a data file with a property list or JSON.
   */
  
  private func setUpVines() {
    let decoder = PropertyListDecoder()
    guard
      let dataFile = Bundle.main.url(forResource: GameConfiguration.vineDataFile, withExtension: nil),
      let data = try? Data(contentsOf: dataFile),
      let vines = try? decoder.decode([VineData].self, from: data)
      else { return }
    
    // Add vines
    for (i, vineData) in vines.enumerated() {
      let anchorPoint = CGPoint(x: vineData.relAnchorPoint.x * size.width, y: vineData.relAnchorPoint.y * size.height)
      let vine = VineNode(length: vineData.length, anchorPoint: anchorPoint, name: "\(i)")
      
      // Add to scene
      vine.addToScene(self)
      
      // Connect the other end of the vine to the prize
      vine.attachToPrize(prize)
      
    }
  }
  
  //MARK: - Croc methods
  
  private func setUpCrocodile() {
    crocodile = SKSpriteNode(imageNamed: ImageName.crocMouthClosed)
    crocodile.position = CGPoint(x: size.width * 0.75, y: size.height * 0.312)
    // zPosition allows to position nodes one in front of another, giving them more relevance inside the scene
    crocodile.zPosition = Layer.crocodile
    crocodile.physicsBody = SKPhysicsBody(
      texture: SKTexture(imageNamed: ImageName.crocMask),
      size: crocodile.size)
    // Giving a category to the node, we can manage contact later on
    crocodile.physicsBody?.categoryBitMask = PhysicsCategory.crocodile
    // Crocodile doesn't  bounce off any other bodies
    crocodile.physicsBody?.collisionBitMask = 0
    // We are interested only in contact with prizes
    crocodile.physicsBody?.contactTestBitMask = PhysicsCategory.prize
    // The physic body ignores forces applied to it (basically, it doesn't move if a collision happens)
    crocodile.physicsBody?.isDynamic = false
    
    addChild(crocodile)
    
    animateCrocodile()
  }
  
  private func animateCrocodile() {
    // Generate a sequence of open-close mouth with a random duration, then it executes the animation.
    let duration = Double.random(in: 2...4)
    let open = SKAction.setTexture(SKTexture(imageNamed: ImageName.crocMouthOpen))
    let wait = SKAction.wait(forDuration: duration)
    let close = SKAction.setTexture(SKTexture(imageNamed: ImageName.crocMouthClosed))
    let sequence = SKAction.sequence([wait, open, wait, close])
    
    crocodile.run(.repeatForever(sequence))
  }
  
  /*
   Gives the impression that the crocodile is chewing the prize
   */
  private func runNomNomAnimation(withDelay delay: TimeInterval) {
    crocodile.removeAllActions()
    
    let closeMouth = SKAction.setTexture(SKTexture(imageNamed: ImageName.crocMouthClosed))
    let wait = SKAction.wait(forDuration: delay)
    let openMouth = SKAction.setTexture(SKTexture(imageNamed: ImageName.crocMouthOpen))
    let sequence = SKAction.sequence([closeMouth, wait, openMouth, wait, closeMouth])
    
    crocodile.run(sequence)
  }
  
  //MARK: - Touch handling

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    didCutVine = false
  }
  
  /*
   It gets the current and previous positions of each touch.
   It loops through all of the bodes in the scene that lie between those two points, using the method enumerateBodies() from SKScene
   For each body encountered, it calls checkIfVineCut().
   */
  override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
    for touch in touches {
      let startPoint = touch.location(in: self)
      let endPoint = touch.previousLocation(in: self)
      
      // Check if vine cut
      scene?.physicsWorld.enumerateBodies(alongRayStart: startPoint, end: endPoint, using: { (body, _, _, _) in
        self.checkIfVineCut(withBody: body)
      })
      
      // Produce some nice particles
      showMoveParticles(touchPosition: startPoint)
    }
  }
  
  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    particles?.removeFromParent()
    particles = nil
  }
  
  private func showMoveParticles(touchPosition: CGPoint) {
    if particles == nil {
      particles = SKEmitterNode(fileNamed: Scene.particles)
      particles!.zPosition = 1
      particles!.targetNode = self
      addChild(particles!)
    }
    particles!.position = touchPosition
  }
  
  //MARK: - Game logic
  
  /*
   Checks if the node that's connected to the physics body has a name.
   Remove the node from the scene - it also removes its physicsBody and destroys any joints connected to it.
   It enumerates through all nodes in the scene whose name matches the name of the node that you swiped. The only ones that matches the name are deleted, using a fadeOut animation.
   */
  private func checkIfVineCut(withBody body: SKPhysicsBody) {
    if didCutVine && !GameConfiguration.canCutMultipleVinesAtOnce {
      return
    }
    
    
    let node = body.node!
    
    // If it has a name, it must be a vine node
    if let name = node.name {
      // Snip the vine - remove from scene
      node.removeFromParent()
      
      didCutVine = true
      
      // Fase out all nodes matching name
      enumerateChildNodes(withName: name) { (node, _) in
        let fadeAway = SKAction.fadeOut(withDuration: 0.25)
        let removeNode = SKAction.removeFromParent()
        let sequence = SKAction.sequence([fadeAway, removeNode])
        node.run(sequence)
      }
      
      crocodile.removeAllActions()
      crocodile.texture = SKTexture(imageNamed: ImageName.crocMouthOpen)
      animateCrocodile()
    }
  }
  
  private func switchToNewGame(withTransition transition: SKTransition) {
    let delay = SKAction.wait(forDuration: 1)
    let sceneChange = SKAction.run {
      let scene = GameScene(size: self.size)
      self.view?.presentScene(scene, transition: transition)
    }
    
    run(.sequence([delay, sceneChange]))
  }
  
  //MARK: - Audio
  
  private func setUpAudio() {
    // If music player is not already set
    if GameScene.backgroundMusicPlayer == nil {
      let backgroundMusicURL = Bundle.main.url(forResource: SoundFile.backgroundMusic, withExtension: nil)
      
      do {
        let theme = try AVAudioPlayer(contentsOf: backgroundMusicURL!)
        GameScene.backgroundMusicPlayer = theme
      } catch {
        // File could not be loaded
      }
      
      GameScene.backgroundMusicPlayer.numberOfLoops = -1
    }
    
    if !GameScene.backgroundMusicPlayer.isPlaying {
      GameScene.backgroundMusicPlayer.play()
    }
    
    sliceSoundAction = .playSoundFileNamed(SoundFile.slice, waitForCompletion: false)
    splashSoundAction = .playSoundFileNamed(SoundFile.splash, waitForCompletion: false)
    nomNomSoundAction = .playSoundFileNamed(SoundFile.nomNom, waitForCompletion: false)
  }
}

extension GameScene: SKPhysicsContactDelegate {
  override func update(_ currentTime: TimeInterval) {
    if isLevelOver { return }
    /*
     Instead of creating a node for the water and detect collision, use the position and check if the position is less or equal 0
     */
    if prize.position.y <= 0 {
      run(splashSoundAction)
      isLevelOver = true
      switchToNewGame(withTransition: .fade(withDuration: 1.0))
    }
    
  }
  
  /*
   Checks if the two intersecting bodies belong to the crocodile and the prize.
   */
  func didBegin(_ contact: SKPhysicsContact) {
    if isLevelOver { return }
    
    if (contact.bodyA.node == crocodile && contact.bodyB.node == prize)
      || (contact.bodyA.node == prize && contact.bodyB.node == crocodile) {
      
      // Run crocodile animation
      runNomNomAnimation(withDelay: 0.15)
      run(nomNomSoundAction)
      
      // Shrink the pineapple away
      let shrink = SKAction.scale(to: 0, duration: 0.88)
      let removeNode = SKAction.removeFromParent()
      let sequence = SKAction.sequence([shrink, removeNode])
      prize.run(sequence)
      
      // Transition to next level
      isLevelOver = true
      switchToNewGame(withTransition: .doorway(withDuration: 1.0))
    }
  }
}

