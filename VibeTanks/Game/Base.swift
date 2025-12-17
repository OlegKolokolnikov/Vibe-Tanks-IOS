import SpriteKit

/// The base (cat) that players must protect
class Base: SKSpriteNode {

    private var isDestroyed: Bool = false
    private let baseSize: CGFloat = GameConstants.tileSize // Match tile size so it fits in protection
    private var catNode: SKNode?

    init(position: CGPoint) {
        super.init(texture: nil, color: .clear, size: CGSize(width: baseSize, height: baseSize))

        self.position = position
        self.zPosition = 5

        drawBase()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawBase() {
        removeAllChildren()

        if isDestroyed {
            // Draw destroyed base - sad scene
            let background = SKShapeNode(rectOf: CGSize(width: baseSize, height: baseSize))
            background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1)
            background.strokeColor = .clear
            addChild(background)

            // Broken pieces
            for _ in 0..<5 {
                let piece = SKShapeNode(rectOf: CGSize(width: CGFloat.random(in: 4...8), height: CGFloat.random(in: 4...8)))
                piece.position = CGPoint(x: CGFloat.random(in: -10...10), y: CGFloat.random(in: -10...10))
                piece.fillColor = SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1)
                piece.strokeColor = .clear
                piece.zRotation = CGFloat.random(in: 0...(.pi))
                addChild(piece)
            }
        } else {
            // Draw cute cat
            let cat = SKNode()
            catNode = cat

            // Background (cat bed/cushion)
            let cushion = SKShapeNode(ellipseOf: CGSize(width: baseSize * 0.9, height: baseSize * 0.7))
            cushion.fillColor = SKColor(red: 0.8, green: 0.6, blue: 0.7, alpha: 1) // Pink cushion
            cushion.strokeColor = SKColor(red: 0.6, green: 0.4, blue: 0.5, alpha: 1)
            cushion.lineWidth = 2
            cushion.position = CGPoint(x: 0, y: -2)
            cat.addChild(cushion)

            // Cat body (orange tabby)
            let catColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1)
            let darkCatColor = SKColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1)

            // Body
            let body = SKShapeNode(ellipseOf: CGSize(width: 18, height: 14))
            body.fillColor = catColor
            body.strokeColor = darkCatColor
            body.lineWidth = 1
            body.position = CGPoint(x: 0, y: -2)
            cat.addChild(body)

            // Head
            let head = SKShapeNode(circleOfRadius: 8)
            head.fillColor = catColor
            head.strokeColor = darkCatColor
            head.lineWidth = 1
            head.position = CGPoint(x: 0, y: 8)
            cat.addChild(head)

            // Ears
            let leftEar = SKShapeNode()
            let leftEarPath = CGMutablePath()
            leftEarPath.move(to: CGPoint(x: -6, y: 12))
            leftEarPath.addLine(to: CGPoint(x: -10, y: 20))
            leftEarPath.addLine(to: CGPoint(x: -2, y: 14))
            leftEarPath.closeSubpath()
            leftEar.path = leftEarPath
            leftEar.fillColor = catColor
            leftEar.strokeColor = darkCatColor
            leftEar.lineWidth = 1
            cat.addChild(leftEar)

            let rightEar = SKShapeNode()
            let rightEarPath = CGMutablePath()
            rightEarPath.move(to: CGPoint(x: 6, y: 12))
            rightEarPath.addLine(to: CGPoint(x: 10, y: 20))
            rightEarPath.addLine(to: CGPoint(x: 2, y: 14))
            rightEarPath.closeSubpath()
            rightEar.path = rightEarPath
            rightEar.fillColor = catColor
            rightEar.strokeColor = darkCatColor
            rightEar.lineWidth = 1
            cat.addChild(rightEar)

            // Inner ears (pink)
            let innerEarColor = SKColor(red: 1.0, green: 0.7, blue: 0.8, alpha: 1)
            let leftInnerEar = SKShapeNode()
            let leftInnerPath = CGMutablePath()
            leftInnerPath.move(to: CGPoint(x: -6, y: 13))
            leftInnerPath.addLine(to: CGPoint(x: -8, y: 18))
            leftInnerPath.addLine(to: CGPoint(x: -4, y: 14))
            leftInnerPath.closeSubpath()
            leftInnerEar.path = leftInnerPath
            leftInnerEar.fillColor = innerEarColor
            leftInnerEar.strokeColor = .clear
            cat.addChild(leftInnerEar)

            let rightInnerEar = SKShapeNode()
            let rightInnerPath = CGMutablePath()
            rightInnerPath.move(to: CGPoint(x: 6, y: 13))
            rightInnerPath.addLine(to: CGPoint(x: 8, y: 18))
            rightInnerPath.addLine(to: CGPoint(x: 4, y: 14))
            rightInnerPath.closeSubpath()
            rightInnerEar.path = rightInnerPath
            rightInnerEar.fillColor = innerEarColor
            rightInnerEar.strokeColor = .clear
            cat.addChild(rightInnerEar)

            // Eyes
            let leftEye = SKShapeNode(ellipseOf: CGSize(width: 4, height: 5))
            leftEye.fillColor = .green
            leftEye.strokeColor = .black
            leftEye.lineWidth = 0.5
            leftEye.position = CGPoint(x: -3, y: 9)
            cat.addChild(leftEye)

            let rightEye = SKShapeNode(ellipseOf: CGSize(width: 4, height: 5))
            rightEye.fillColor = .green
            rightEye.strokeColor = .black
            rightEye.lineWidth = 0.5
            rightEye.position = CGPoint(x: 3, y: 9)
            cat.addChild(rightEye)

            // Pupils
            let leftPupil = SKShapeNode(ellipseOf: CGSize(width: 2, height: 3))
            leftPupil.fillColor = .black
            leftPupil.strokeColor = .clear
            leftPupil.position = CGPoint(x: -3, y: 9)
            cat.addChild(leftPupil)

            let rightPupil = SKShapeNode(ellipseOf: CGSize(width: 2, height: 3))
            rightPupil.fillColor = .black
            rightPupil.strokeColor = .clear
            rightPupil.position = CGPoint(x: 3, y: 9)
            cat.addChild(rightPupil)

            // Nose
            let nose = SKShapeNode()
            let nosePath = CGMutablePath()
            nosePath.move(to: CGPoint(x: 0, y: 6))
            nosePath.addLine(to: CGPoint(x: -2, y: 4))
            nosePath.addLine(to: CGPoint(x: 2, y: 4))
            nosePath.closeSubpath()
            nose.path = nosePath
            nose.fillColor = SKColor(red: 1.0, green: 0.5, blue: 0.5, alpha: 1)
            nose.strokeColor = .clear
            cat.addChild(nose)

            // Whiskers
            let whiskerColor = SKColor.white
            for side in [-1.0, 1.0] {
                for i in 0..<3 {
                    let whisker = SKShapeNode()
                    let whiskerPath = CGMutablePath()
                    let startX = CGFloat(side) * 3
                    let endX = CGFloat(side) * 12
                    let yOffset = CGFloat(i - 1) * 2
                    whiskerPath.move(to: CGPoint(x: startX, y: 5 + yOffset))
                    whiskerPath.addLine(to: CGPoint(x: endX, y: 4 + yOffset + CGFloat(i - 1)))
                    whisker.path = whiskerPath
                    whisker.strokeColor = whiskerColor
                    whisker.lineWidth = 0.5
                    cat.addChild(whisker)
                }
            }

            // Stripes on body
            for i in 0..<3 {
                let stripe = SKShapeNode(rectOf: CGSize(width: 10, height: 2))
                stripe.fillColor = darkCatColor
                stripe.strokeColor = .clear
                stripe.position = CGPoint(x: 0, y: -2 + CGFloat(i - 1) * 4)
                stripe.zRotation = CGFloat.random(in: -0.2...0.2)
                cat.addChild(stripe)
            }

            // Tail (curled)
            let tail = SKShapeNode()
            let tailPath = CGMutablePath()
            tailPath.move(to: CGPoint(x: 8, y: -4))
            tailPath.addQuadCurve(to: CGPoint(x: 14, y: 2), control: CGPoint(x: 14, y: -6))
            tailPath.addQuadCurve(to: CGPoint(x: 12, y: 8), control: CGPoint(x: 18, y: 4))
            tail.path = tailPath
            tail.strokeColor = catColor
            tail.lineWidth = 4
            tail.lineCap = .round
            cat.addChild(tail)

            addChild(cat)

            // Idle animation - gentle breathing
            let breatheIn = SKAction.scaleY(to: 1.05, duration: 1.5)
            let breatheOut = SKAction.scaleY(to: 0.95, duration: 1.5)
            let breathe = SKAction.sequence([breatheIn, breatheOut])
            cat.run(SKAction.repeatForever(breathe))
        }
    }

    /// Play victory animation - cat runs out and plays with toy
    func playVictoryAnimation(to targetPosition: CGPoint) {
        guard let cat = catNode, !isDestroyed else { return }

        // Stop idle animation
        cat.removeAllActions()
        cat.setScale(1.0)

        // Create a toy ball near the cat
        let toy = SKShapeNode(circleOfRadius: 6)
        toy.fillColor = .red
        toy.strokeColor = .white
        toy.lineWidth = 1
        toy.position = CGPoint(x: 30, y: 20)  // Start near the cat
        toy.zPosition = 1
        addChild(toy)

        // Cat jumps up excitedly
        let jumpUp = SKAction.moveBy(x: 0, y: 15, duration: 0.2)
        let jumpDown = SKAction.moveBy(x: 0, y: -15, duration: 0.15)

        // Paw swipe animation
        let pawLeft = SKAction.rotate(byAngle: 0.3, duration: 0.1)
        let pawRight = SKAction.rotate(byAngle: -0.6, duration: 0.1)
        let pawBack = SKAction.rotate(byAngle: 0.3, duration: 0.1)
        let pawSequence = SKAction.sequence([pawLeft, pawRight, pawBack])

        // Create a play cycle where cat chases toy back and forth
        let playCycle = SKAction.run { [weak cat, weak toy] in
            guard let cat = cat, let toy = toy else { return }

            // Random direction for toy to bounce
            let bounceX = CGFloat.random(in: -25...25)
            let bounceY = CGFloat.random(in: -15...15)

            // Keep toy within bounds
            let newX = max(-40, min(40, toy.position.x + bounceX))
            let newY = max(-10, min(30, toy.position.y + bounceY))

            // Toy bounces
            let toyMove = SKAction.move(to: CGPoint(x: newX, y: newY), duration: 0.3)
            toyMove.timingMode = .easeOut
            toy.run(toyMove)

            // Cat chases and paws at toy
            let catChase = SKAction.move(to: CGPoint(x: newX, y: newY - 10), duration: 0.35)
            catChase.timingMode = .easeOut
            cat.run(SKAction.sequence([catChase, pawSequence]))
        }

        // Initial jump, then play forever
        cat.run(SKAction.sequence([
            jumpUp,
            jumpDown,
            SKAction.wait(forDuration: 0.2)
        ])) { [weak cat] in
            guard let cat = cat else { return }
            // Start the play loop
            let playLoop = SKAction.sequence([
                playCycle,
                SKAction.wait(forDuration: 0.6)
            ])
            cat.run(SKAction.repeatForever(playLoop))
        }
    }

    func checkCollision(bulletPosition: CGPoint) -> Bool {
        guard !isDestroyed else { return false }

        let halfSize = baseSize / 2
        let dx = abs(bulletPosition.x - position.x)
        let dy = abs(bulletPosition.y - position.y)

        return dx < halfSize && dy < halfSize
    }

    func destroy() {
        isDestroyed = true
        drawBase()

        // Explosion effect
        let explosion = SKEmitterNode()
        explosion.particleColor = .orange
        explosion.particleBirthRate = 100
        explosion.particleLifetime = 0.5
        explosion.particleSpeed = 50
        explosion.particleSpeedRange = 30
        explosion.emissionAngleRange = .pi * 2
        explosion.position = .zero
        addChild(explosion)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { explosion.removeFromParent() }
        ]))
    }

    var alive: Bool {
        return !isDestroyed
    }
}
