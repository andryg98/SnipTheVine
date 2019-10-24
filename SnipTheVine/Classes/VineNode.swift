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

import UIKit
import SpriteKit

// VineNode acts as a container for a collection of nodes that represents the vine segments

class VineNode: SKNode {
  private let length: Int
  private let anchorPoint: CGPoint
  private var vineSegments: [SKNode] = []
  
  init(length: Int, anchorPoint: CGPoint, name: String) {
    self.length = length
    self.anchorPoint = anchorPoint
    
    super.init()
    
    self.name = name
  }
  
  /*
   Because SKNode implements NSCoding, it inherits the required initializer init(coder:).
   That means our non-optional properties has to be initialized also here.
   */
  required init?(coder aDecoder: NSCoder) {
    length = aDecoder.decodeInteger(forKey: "length")
    anchorPoint = aDecoder.decodeCGPoint(forKey: "anchorPoint")
    
    super.init(coder: aDecoder)
  }
  
  func addToScene(_ scene: SKScene) {
    // Add vine to the scene
    zPosition = Layer.vine
    scene.addChild(self)
    
    // Create vine holder - like a nail for the vine to hang from
    let vineHolder = SKSpriteNode(imageNamed: ImageName.vineHolder)
    vineHolder.position = anchorPoint
    vineHolder.zPosition = 1
    
    addChild(vineHolder)
    
    vineHolder.physicsBody = SKPhysicsBody(circleOfRadius: vineHolder.size.width / 2)
    vineHolder.physicsBody?.isDynamic = false
    vineHolder.physicsBody?.categoryBitMask = PhysicsCategory.vineHolder
    vineHolder.physicsBody?.collisionBitMask = 0
    
    // Add each of the vine parts - each segment is a sprite with its own physics body
    for i in 0..<length {
      let vineSegment = SKSpriteNode(imageNamed: ImageName.vineTexture)
      let offset = vineSegment.size.height * CGFloat(i + 1)
      vineSegment.position = CGPoint(x: anchorPoint.x, y: anchorPoint.y - offset)
      vineSegment.name = name
      
      vineSegments.append(vineSegment)
      addChild(vineSegment)
      
      vineSegment.physicsBody = SKPhysicsBody(rectangleOf: vineSegment.size)
      vineSegment.physicsBody?.categoryBitMask = PhysicsCategory.vine
      vineSegment.physicsBody?.collisionBitMask = PhysicsCategory.vineHolder
    }
    
    // Set up joint for the vine holder
    let joint = SKPhysicsJointPin.joint(
      withBodyA: vineHolder.physicsBody!,
      bodyB: vineSegments[0].physicsBody!,
      anchor: CGPoint(x: vineHolder.frame.midX, y: vineHolder.frame.midY))
    
    scene.physicsWorld.add(joint)
    
    // Set up joint between vine parts
    for i in 1..<length {
      let nodeA = vineSegments[i - 1]
      let nodeB = vineSegments[i]
      let joint = SKPhysicsJointPin.joint(
        withBodyA: nodeA.physicsBody!,
        bodyB: nodeB.physicsBody!,
        anchor: CGPoint(x: nodeA.frame.midX, y: nodeA.frame.midY))
      
      scene.physicsWorld.add(joint)
    }
  }
  
  func attachToPrize(_ prize: SKSpriteNode) {
    // Align last segment of vine with prize
    let lastNode = vineSegments.last!
    lastNode.position = CGPoint(x: prize.position.x, y: prize.position.y + prize.size.height * 0.1)
    
    // Set up connecting joint
    let joint = SKPhysicsJointPin.joint(withBodyA: lastNode.physicsBody!, bodyB: prize.physicsBody!, anchor: lastNode.position)
    
    prize.scene?.physicsWorld.add(joint)
  }
}
