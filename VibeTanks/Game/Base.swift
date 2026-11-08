import SpriteKit

/// The base (cat or alien) that players must protect
class Base: SKSpriteNode {

    private var isDestroyed: Bool = false
    private let baseSize: CGFloat = GameConstants.tileSize // Match tile size so it fits in protection
    private var catNode: SKNode?
    private var isAlien: Bool = false

    /// Who sits at the base
    enum Resident {
        case cat
        case alien
        case woman(blond: Bool)  // Secret bonus stage (blond when the stage has a boss)
        case dog                 // Boss levels
    }
    private let resident: Resident

    init(position: CGPoint, resident: Resident = .cat) {
        self.resident = resident
        if case .alien = resident { self.isAlien = true }
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
        } else if isAlien {
            // Draw smiling alien visitor
            drawAlien()
        } else if case .woman(let blond) = resident {
            drawWoman(blond: blond)
        } else if case .dog = resident {
            drawDog()
        } else {
            // Draw cute cat - cushion is separate so cat can walk away from it

            // Background (cat bed/cushion) - added to Base directly, not to cat
            let cushion = SKShapeNode(ellipseOf: CGSize(width: baseSize * 0.9, height: baseSize * 0.7))
            cushion.fillColor = SKColor(red: 0.8, green: 0.6, blue: 0.7, alpha: 1) // Pink cushion
            cushion.strokeColor = SKColor(red: 0.6, green: 0.4, blue: 0.5, alpha: 1)
            cushion.lineWidth = 2
            cushion.position = CGPoint(x: 0, y: -2)
            cushion.name = "cushion"
            addChild(cushion)

            // Cat body (separate from cushion so it can animate independently)
            let cat = SKNode()
            catNode = cat

            // Cat body color: black for Gzhel, white for easy mode, orange tabby otherwise
            let catColor: SKColor
            let darkCatColor: SKColor
            if GameScene.isGzhelActive {
                // Black cat for Gzhel level
                catColor = SKColor(red: 0.15, green: 0.15, blue: 0.18, alpha: 1)
                darkCatColor = SKColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1)
            } else if GameScene.isEasyMode {
                // White cat for easy mode
                catColor = SKColor(red: 0.98, green: 0.98, blue: 0.98, alpha: 1)
                darkCatColor = SKColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
            } else {
                // Orange tabby (default)
                catColor = SKColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1)
                darkCatColor = SKColor(red: 0.8, green: 0.4, blue: 0.1, alpha: 1)
            }

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

            // Stripes on body (only for orange tabby, not white cat)
            if !GameScene.isEasyMode {
                for i in 0..<3 {
                    let stripe = SKShapeNode(rectOf: CGSize(width: 10, height: 2))
                    stripe.fillColor = darkCatColor
                    stripe.strokeColor = .clear
                    stripe.position = CGPoint(x: 0, y: -2 + CGFloat(i - 1) * 4)
                    stripe.zRotation = CGFloat.random(in: -0.2...0.2)
                    cat.addChild(stripe)
                }
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

    /// Play victory animation - cat plays with toy (batting it around)
    func playVictoryAnimation(to targetPosition: CGPoint) {
        guard let cat = catNode, !isDestroyed else { return }

        // Stop idle animation
        cat.removeAllActions()
        cat.setScale(1.0)

        // Move cat slightly forward from base
        cat.position = CGPoint(x: 25, y: 0)

        // Create a toy ball in front of the cat
        let toy = SKShapeNode(circleOfRadius: 5)
        toy.fillColor = .red
        toy.strokeColor = .yellow
        toy.lineWidth = 1
        toy.position = CGPoint(x: 45, y: -5)
        toy.zPosition = 2
        addChild(toy)

        // Cat watches toy (slight head tilt)
        let watchLeft = SKAction.rotate(toAngle: 0.15, duration: 0.3)
        let watchRight = SKAction.rotate(toAngle: -0.15, duration: 0.3)
        let watchCenter = SKAction.rotate(toAngle: 0, duration: 0.2)

        // Cat pounce/bat animation
        let crouch = SKAction.scaleY(to: 0.8, duration: 0.15)
        let pounce = SKAction.group([
            SKAction.scaleY(to: 1.1, duration: 0.1),
            SKAction.moveBy(x: 8, y: 3, duration: 0.1)
        ])
        let recover = SKAction.group([
            SKAction.scaleY(to: 1.0, duration: 0.15),
            SKAction.moveBy(x: -8, y: -3, duration: 0.15)
        ])

        // Toy bounce away when batted
        var toyGoingRight = true

        let batToy = SKAction.run { [weak toy] in
            guard let toy = toy else { return }

            // Alternate toy direction
            let direction: CGFloat = toyGoingRight ? 1 : -1
            toyGoingRight = !toyGoingRight

            // Toy flies away
            let flyAway = SKAction.moveBy(x: direction * 35, y: 8, duration: 0.2)
            flyAway.timingMode = .easeOut

            // Toy rolls back toward cat
            let rollBack = SKAction.moveBy(x: direction * -30, y: -8, duration: 0.6)
            rollBack.timingMode = .easeOut

            // Toy spins while moving
            let spin = SKAction.rotate(byAngle: direction * .pi * 3, duration: 0.8)

            toy.run(SKAction.group([
                SKAction.sequence([flyAway, rollBack]),
                spin
            ]))
        }

        // Play sequence: watch, crouch, pounce/bat, recover, repeat
        let playOnce = SKAction.sequence([
            watchLeft,
            SKAction.wait(forDuration: 0.3),
            watchCenter,
            crouch,
            SKAction.wait(forDuration: 0.1),
            pounce,
            batToy,
            recover,
            SKAction.wait(forDuration: 0.5),
            watchRight,
            SKAction.wait(forDuration: 0.3),
            watchCenter,
            crouch,
            SKAction.wait(forDuration: 0.1),
            pounce,
            batToy,
            recover,
            SKAction.wait(forDuration: 0.5)
        ])

        // Initial excited jump
        let jumpUp = SKAction.moveBy(x: 0, y: 10, duration: 0.15)
        let jumpDown = SKAction.moveBy(x: 0, y: -10, duration: 0.1)

        cat.run(SKAction.sequence([
            jumpUp,
            jumpDown,
            SKAction.wait(forDuration: 0.3),
            SKAction.repeatForever(playOnce)
        ]))
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

    // MARK: - Alien Drawing

    private func drawAlien() {
        // Alien colors
        let alienGreen = SKColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1)
        let alienDark = SKColor(red: 0.2, green: 0.6, blue: 0.2, alpha: 1)

        // Small spaceship pad (instead of cushion)
        let pad = SKShapeNode(ellipseOf: CGSize(width: baseSize * 0.8, height: baseSize * 0.4))
        pad.fillColor = SKColor(red: 0.3, green: 0.3, blue: 0.4, alpha: 1)
        pad.strokeColor = SKColor(red: 0.5, green: 0.5, blue: 0.6, alpha: 1)
        pad.lineWidth = 2
        pad.position = CGPoint(x: 0, y: -8)
        pad.name = "pad"
        addChild(pad)

        // Alien body
        let alien = SKNode()
        catNode = alien  // Reuse catNode for alien

        // Body (oval)
        let body = SKShapeNode(ellipseOf: CGSize(width: 14, height: 18))
        body.fillColor = alienGreen
        body.strokeColor = alienDark
        body.lineWidth = 1
        body.position = CGPoint(x: 0, y: 0)
        alien.addChild(body)

        // Big head
        let head = SKShapeNode(ellipseOf: CGSize(width: 20, height: 16))
        head.fillColor = alienGreen
        head.strokeColor = alienDark
        head.lineWidth = 1
        head.position = CGPoint(x: 0, y: 14)
        alien.addChild(head)

        // Big black eyes
        let leftEye = SKShapeNode(ellipseOf: CGSize(width: 8, height: 10))
        leftEye.fillColor = .black
        leftEye.strokeColor = .clear
        leftEye.position = CGPoint(x: -5, y: 14)
        alien.addChild(leftEye)

        let rightEye = SKShapeNode(ellipseOf: CGSize(width: 8, height: 10))
        rightEye.fillColor = .black
        rightEye.strokeColor = .clear
        rightEye.position = CGPoint(x: 5, y: 14)
        alien.addChild(rightEye)

        // Eye shine
        let leftShine = SKShapeNode(circleOfRadius: 2)
        leftShine.fillColor = .white
        leftShine.strokeColor = .clear
        leftShine.position = CGPoint(x: -6, y: 16)
        alien.addChild(leftShine)

        let rightShine = SKShapeNode(circleOfRadius: 2)
        rightShine.fillColor = .white
        rightShine.strokeColor = .clear
        rightShine.position = CGPoint(x: 4, y: 16)
        alien.addChild(rightShine)

        // Big smile
        let smile = SKShapeNode()
        let smilePath = CGMutablePath()
        smilePath.move(to: CGPoint(x: -6, y: 6))
        smilePath.addQuadCurve(to: CGPoint(x: 6, y: 6), control: CGPoint(x: 0, y: 0))
        smile.path = smilePath
        smile.strokeColor = alienDark
        smile.lineWidth = 2
        smile.lineCap = .round
        alien.addChild(smile)

        // Antennae
        let leftAntenna = SKShapeNode()
        let leftAntennaPath = CGMutablePath()
        leftAntennaPath.move(to: CGPoint(x: -6, y: 20))
        leftAntennaPath.addQuadCurve(to: CGPoint(x: -10, y: 28), control: CGPoint(x: -12, y: 24))
        leftAntenna.path = leftAntennaPath
        leftAntenna.strokeColor = alienGreen
        leftAntenna.lineWidth = 2
        alien.addChild(leftAntenna)

        let leftBall = SKShapeNode(circleOfRadius: 3)
        leftBall.fillColor = .yellow
        leftBall.strokeColor = .orange
        leftBall.lineWidth = 1
        leftBall.position = CGPoint(x: -10, y: 28)
        alien.addChild(leftBall)

        let rightAntenna = SKShapeNode()
        let rightAntennaPath = CGMutablePath()
        rightAntennaPath.move(to: CGPoint(x: 6, y: 20))
        rightAntennaPath.addQuadCurve(to: CGPoint(x: 10, y: 28), control: CGPoint(x: 12, y: 24))
        rightAntenna.path = rightAntennaPath
        rightAntenna.strokeColor = alienGreen
        rightAntenna.lineWidth = 2
        alien.addChild(rightAntenna)

        let rightBall = SKShapeNode(circleOfRadius: 3)
        rightBall.fillColor = .yellow
        rightBall.strokeColor = .orange
        rightBall.lineWidth = 1
        rightBall.position = CGPoint(x: 10, y: 28)
        alien.addChild(rightBall)

        // Little arms waving
        let leftArm = SKShapeNode()
        let leftArmPath = CGMutablePath()
        leftArmPath.move(to: CGPoint(x: -7, y: 0))
        leftArmPath.addLine(to: CGPoint(x: -14, y: 5))
        leftArm.path = leftArmPath
        leftArm.strokeColor = alienGreen
        leftArm.lineWidth = 3
        leftArm.lineCap = .round
        leftArm.name = "leftArm"
        alien.addChild(leftArm)

        let rightArm = SKShapeNode()
        let rightArmPath = CGMutablePath()
        rightArmPath.move(to: CGPoint(x: 7, y: 0))
        rightArmPath.addLine(to: CGPoint(x: 14, y: 5))
        rightArm.path = rightArmPath
        rightArm.strokeColor = alienGreen
        rightArm.lineWidth = 3
        rightArm.lineCap = .round
        rightArm.name = "rightArm"
        alien.addChild(rightArm)

        addChild(alien)

        // Idle animation - antenna balls glow and arms wave
        let glowUp = SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        let glowDown = SKAction.fadeAlpha(to: 0.5, duration: 0.5)
        let glow = SKAction.sequence([glowUp, glowDown])
        leftBall.run(SKAction.repeatForever(glow))
        rightBall.run(SKAction.repeatForever(SKAction.sequence([glowDown, glowUp])))

        // Wave arms
        let waveUp = SKAction.rotate(byAngle: 0.3, duration: 0.3)
        let waveDown = SKAction.rotate(byAngle: -0.3, duration: 0.3)
        let wave = SKAction.sequence([waveUp, waveDown])
        leftArm.run(SKAction.repeatForever(wave))
        rightArm.run(SKAction.repeatForever(SKAction.sequence([waveDown, waveUp])))
    }

    /// Play alien victory animation - UFO comes and picks up the alien
    func playAlienVictoryAnimation(to targetPosition: CGPoint) {
        guard let alien = catNode, isAlien, !isDestroyed else { return }

        // Stop idle animations
        alien.removeAllActions()
        for child in alien.children {
            child.removeAllActions()
        }

        // Create UFO above the screen
        let ufo = SKNode()
        ufo.position = CGPoint(x: 0, y: 150)
        ufo.name = "rescueUFO"

        // UFO body (saucer shape)
        let saucer = SKShapeNode(ellipseOf: CGSize(width: 50, height: 15))
        saucer.fillColor = SKColor(red: 0.6, green: 0.6, blue: 0.7, alpha: 1)
        saucer.strokeColor = SKColor(red: 0.4, green: 0.4, blue: 0.5, alpha: 1)
        saucer.lineWidth = 2
        ufo.addChild(saucer)

        // UFO dome
        let dome = SKShapeNode(ellipseOf: CGSize(width: 25, height: 18))
        dome.fillColor = SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.7)
        dome.strokeColor = SKColor(red: 0.3, green: 0.6, blue: 0.8, alpha: 1)
        dome.lineWidth = 1
        dome.position = CGPoint(x: 0, y: 8)
        ufo.addChild(dome)

        // UFO lights
        for i in 0..<5 {
            let light = SKShapeNode(circleOfRadius: 3)
            light.fillColor = [SKColor.red, .yellow, .green, .cyan, .magenta][i]
            light.strokeColor = .clear
            light.position = CGPoint(x: -20 + CGFloat(i) * 10, y: -2)
            ufo.addChild(light)

            // Blink lights
            let blink = SKAction.sequence([
                SKAction.fadeAlpha(to: 0.3, duration: 0.2),
                SKAction.fadeAlpha(to: 1.0, duration: 0.2)
            ])
            light.run(SKAction.repeatForever(blink))
        }

        addChild(ufo)

        // Tractor beam
        let beam = SKShapeNode()
        let beamPath = CGMutablePath()
        beamPath.move(to: CGPoint(x: -15, y: -5))
        beamPath.addLine(to: CGPoint(x: 15, y: -5))
        beamPath.addLine(to: CGPoint(x: 8, y: -80))
        beamPath.addLine(to: CGPoint(x: -8, y: -80))
        beamPath.closeSubpath()
        beam.path = beamPath
        beam.fillColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.3)
        beam.strokeColor = SKColor(red: 0.5, green: 1.0, blue: 0.5, alpha: 0.5)
        beam.lineWidth = 1
        beam.alpha = 0
        ufo.addChild(beam)

        // Animation sequence
        // 1. UFO descends
        let descend = SKAction.moveTo(y: 60, duration: 1.0)
        descend.timingMode = .easeOut

        // 2. Show tractor beam
        let showBeam = SKAction.run { beam.alpha = 1.0 }

        // 3. Alien floats up into UFO
        let alienFloatUp = SKAction.run {
            let floatUp = SKAction.move(to: CGPoint(x: 0, y: 60), duration: 1.5)
            floatUp.timingMode = .easeIn
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 1.5)
            let scale = SKAction.scale(to: 0.3, duration: 1.5)
            alien.run(SKAction.group([floatUp, spin, scale]))
        }

        // 4. Hide beam and alien, UFO flies away
        let hideBeamAndAlien = SKAction.run {
            beam.alpha = 0
            alien.alpha = 0
        }

        let flyAway = SKAction.group([
            SKAction.moveTo(y: 200, duration: 1.0),
            SKAction.moveTo(x: 100, duration: 1.0)
        ])
        flyAway.timingMode = .easeIn

        // Run the sequence
        ufo.run(SKAction.sequence([
            descend,
            showBeam,
            alienFloatUp,
            SKAction.wait(forDuration: 1.6),
            hideBeamAndAlien,
            flyAway,
            SKAction.removeFromParent()
        ]))
    }
}

// MARK: - Woman (bonus stage) and dog (boss levels)

extension Base {

    private static let skin = SKColor(red: 1.0, green: 0.84, blue: 0.72, alpha: 1)

    private func shape(_ path: CGPath, fill: SKColor, stroke: SKColor = .clear, width: CGFloat = 1) -> SKShapeNode {
        let node = SKShapeNode(path: path)
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = width
        return node
    }

    private func ellipse(_ w: CGFloat, _ h: CGFloat, at p: CGPoint, fill: SKColor, stroke: SKColor = .clear) -> SKShapeNode {
        let node = SKShapeNode(ellipseOf: CGSize(width: w, height: h))
        node.position = p
        node.fillColor = fill
        node.strokeColor = stroke
        node.lineWidth = 1
        return node
    }

    /// Woman in a red polka-dot dress on a rug; black hair, or blond on a boss bonus stage
    fileprivate func drawWoman(blond: Bool) {
        let rug = ellipse(baseSize * 0.95, baseSize * 0.55, at: CGPoint(x: 0, y: -10),
                          fill: SKColor(red: 0.55, green: 0.25, blue: 0.6, alpha: 1),
                          stroke: SKColor(red: 0.95, green: 0.8, blue: 0.3, alpha: 1))
        rug.name = "cushion"
        addChild(rug)

        let hair = blond ? SKColor(red: 0.98, green: 0.84, blue: 0.38, alpha: 1)
                         : SKColor(red: 0.08, green: 0.06, blue: 0.06, alpha: 1)
        let woman = SKNode()
        woman.name = "resident"

        // Long hair behind the head and shoulders
        let back = CGMutablePath()
        back.addRoundedRect(in: CGRect(x: -8, y: -4, width: 16, height: 16), cornerWidth: 7, cornerHeight: 7)
        woman.addChild(shape(back, fill: hair))

        // Legs
        let legs = CGMutablePath()
        legs.move(to: CGPoint(x: -3, y: -13)); legs.addLine(to: CGPoint(x: -3, y: -17))
        legs.move(to: CGPoint(x: 3, y: -13)); legs.addLine(to: CGPoint(x: 3, y: -17))
        let legNode = shape(legs, fill: .clear, stroke: Base.skin, width: 2)
        woman.addChild(legNode)

        // Dress with white dots
        let dress = CGMutablePath()
        dress.move(to: CGPoint(x: -4.5, y: -1))
        dress.addLine(to: CGPoint(x: 4.5, y: -1))
        dress.addLine(to: CGPoint(x: 9, y: -14))
        dress.addLine(to: CGPoint(x: -9, y: -14))
        dress.closeSubpath()
        woman.addChild(shape(dress, fill: SKColor(red: 0.88, green: 0.1, blue: 0.2, alpha: 1),
                             stroke: SKColor(red: 0.55, green: 0.03, blue: 0.1, alpha: 1)))
        for p in [CGPoint(x: -3, y: -6), CGPoint(x: 2.5, y: -4.5), CGPoint(x: 0, y: -10), CGPoint(x: -5.5, y: -11.5), CGPoint(x: 5, y: -10.5)] {
            woman.addChild(ellipse(1.6, 1.6, at: p, fill: .white))
        }

        // Arms (the right one waves)
        let leftArm = CGMutablePath()
        leftArm.move(to: CGPoint(x: -4.5, y: -2)); leftArm.addLine(to: CGPoint(x: -8.5, y: -8))
        woman.addChild(shape(leftArm, fill: .clear, stroke: Base.skin, width: 2))
        let rightArm = CGMutablePath()
        rightArm.move(to: .zero); rightArm.addLine(to: CGPoint(x: 4.5, y: 5))
        let arm = shape(rightArm, fill: .clear, stroke: Base.skin, width: 2)
        arm.position = CGPoint(x: 4.5, y: -2)
        arm.name = "wavingArm"
        woman.addChild(arm)

        // Head, fringe, face
        woman.addChild(ellipse(11, 12, at: CGPoint(x: 0, y: 5), fill: Base.skin))
        let fringe = CGMutablePath()
        fringe.addArc(center: CGPoint(x: 0, y: 6.5), radius: 6, startAngle: 0.15, endAngle: .pi - 0.15, clockwise: false)
        fringe.closeSubpath()
        woman.addChild(shape(fringe, fill: hair))
        woman.addChild(ellipse(1.6, 2, at: CGPoint(x: -2.2, y: 5), fill: .black))
        woman.addChild(ellipse(1.6, 2, at: CGPoint(x: 2.2, y: 5), fill: .black))
        woman.addChild(ellipse(2, 1.3, at: CGPoint(x: -3.6, y: 2.8), fill: SKColor(red: 1, green: 0.55, blue: 0.6, alpha: 0.8)))
        woman.addChild(ellipse(2, 1.3, at: CGPoint(x: 3.6, y: 2.8), fill: SKColor(red: 1, green: 0.55, blue: 0.6, alpha: 0.8)))
        woman.addChild(ellipse(3.2, 1.6, at: CGPoint(x: 0, y: 1.6), fill: SKColor(red: 0.85, green: 0.05, blue: 0.15, alpha: 1)))

        woman.position = CGPoint(x: 0, y: 2)
        addChild(woman)
        catNode = woman

        // Idle: a gentle sway and a little wave now and then
        woman.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.05, duration: 1.2),
            SKAction.rotate(toAngle: -0.05, duration: 1.2)
        ])))
        arm.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.repeat(SKAction.sequence([SKAction.rotate(toAngle: 0.6, duration: 0.15),
                                               SKAction.rotate(toAngle: 0, duration: 0.15)]), count: 3)
        ])))
    }

    /// Dog sitting on a blue bed, wagging its tail
    fileprivate func drawDog() {
        let bed = ellipse(baseSize * 0.9, baseSize * 0.65, at: CGPoint(x: 0, y: -4),
                          fill: SKColor(red: 0.3, green: 0.5, blue: 0.85, alpha: 1),
                          stroke: SKColor(red: 0.15, green: 0.3, blue: 0.6, alpha: 1))
        bed.name = "cushion"
        addChild(bed)

        let fur = SKColor(red: 0.62, green: 0.4, blue: 0.2, alpha: 1)
        let darkFur = SKColor(red: 0.38, green: 0.22, blue: 0.1, alpha: 1)
        let tan = SKColor(red: 0.9, green: 0.75, blue: 0.55, alpha: 1)
        let dog = SKNode()
        dog.name = "resident"

        // Tail (wags)
        let tailPath = CGMutablePath()
        tailPath.move(to: .zero)
        tailPath.addQuadCurve(to: CGPoint(x: 6, y: 6), control: CGPoint(x: 6, y: 0))
        let tail = shape(tailPath, fill: .clear, stroke: fur, width: 3)
        tail.lineCap = .round
        tail.position = CGPoint(x: 6, y: -9)
        tail.name = "tail"
        dog.addChild(tail)

        // Body, chest, front paws
        dog.addChild(ellipse(15, 14, at: CGPoint(x: 0, y: -6), fill: fur, stroke: darkFur))
        dog.addChild(ellipse(7, 8, at: CGPoint(x: 0, y: -6), fill: tan))
        dog.addChild(ellipse(4, 3, at: CGPoint(x: -3, y: -12.5), fill: tan, stroke: darkFur))
        dog.addChild(ellipse(4, 3, at: CGPoint(x: 3, y: -12.5), fill: tan, stroke: darkFur))

        // Collar with a gold tag
        let collar = SKShapeNode(rectOf: CGSize(width: 9, height: 2), cornerRadius: 1)
        collar.fillColor = SKColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)
        collar.strokeColor = .clear
        collar.position = CGPoint(x: 0, y: -0.5)
        dog.addChild(collar)
        dog.addChild(ellipse(2.2, 2.2, at: CGPoint(x: 0, y: -2), fill: .yellow))

        // Floppy ears, head, snout, nose, tongue, eyes
        let leftEar = ellipse(5, 10, at: CGPoint(x: -6.5, y: 4), fill: darkFur)
        leftEar.zRotation = -0.3
        dog.addChild(leftEar)
        let rightEar = ellipse(5, 10, at: CGPoint(x: 6.5, y: 4), fill: darkFur)
        rightEar.zRotation = 0.3
        dog.addChild(rightEar)
        dog.addChild(ellipse(13, 12, at: CGPoint(x: 0, y: 6), fill: fur, stroke: darkFur))
        dog.addChild(ellipse(8, 6, at: CGPoint(x: 0, y: 3), fill: tan))
        dog.addChild(ellipse(3.4, 2.4, at: CGPoint(x: 0, y: 4.6), fill: .black))
        dog.addChild(ellipse(2.4, 3, at: CGPoint(x: 0, y: 0.6), fill: SKColor(red: 1, green: 0.45, blue: 0.55, alpha: 1)))
        dog.addChild(ellipse(2, 2.4, at: CGPoint(x: -2.8, y: 8), fill: .black))
        dog.addChild(ellipse(2, 2.4, at: CGPoint(x: 2.8, y: 8), fill: .black))

        dog.position = CGPoint(x: 0, y: 2)
        addChild(dog)
        catNode = dog

        tail.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.rotate(toAngle: 0.5, duration: 0.18),
            SKAction.rotate(toAngle: -0.3, duration: 0.18)
        ])))
    }

    /// Bonus stage cleared: a car drives up, the woman gets in and they drive off
    func playCarPickupAnimation(blond: Bool) {
        guard let woman = catNode, !isDestroyed else { return }
        woman.removeAllActions()
        woman.zRotation = 0

        let car = SKNode()
        car.zPosition = 30
        let paint = blond ? SKColor(red: 1.0, green: 0.45, blue: 0.7, alpha: 1) : SKColor(red: 0.85, green: 0.08, blue: 0.1, alpha: 1)
        let bodyPath = CGMutablePath()
        bodyPath.addRoundedRect(in: CGRect(x: -18, y: -5, width: 36, height: 11), cornerWidth: 4, cornerHeight: 4)
        car.addChild(shape(bodyPath, fill: paint, stroke: paint.darker(), width: 1.5))
        let cabinPath = CGMutablePath()
        cabinPath.addRoundedRect(in: CGRect(x: -10, y: 5, width: 19, height: 9), cornerWidth: 4, cornerHeight: 4)
        car.addChild(shape(cabinPath, fill: paint, stroke: paint.darker(), width: 1.5))
        let window = CGMutablePath()
        window.addRoundedRect(in: CGRect(x: -8, y: 6.5, width: 15, height: 6), cornerWidth: 2, cornerHeight: 2)
        car.addChild(shape(window, fill: SKColor(red: 0.7, green: 0.9, blue: 1.0, alpha: 1)))
        car.addChild(ellipse(3, 3, at: CGPoint(x: 17, y: 1), fill: .yellow))
        var wheels: [SKNode] = []
        for x: CGFloat in [-10, 10] {
            let wheel = SKNode()
            wheel.position = CGPoint(x: x, y: -6)
            wheel.addChild(ellipse(9, 9, at: .zero, fill: SKColor(white: 0.12, alpha: 1)))
            let spoke = SKShapeNode(rectOf: CGSize(width: 7, height: 1.4))
            spoke.fillColor = SKColor(white: 0.75, alpha: 1)
            spoke.strokeColor = .clear
            wheel.addChild(spoke)
            car.addChild(wheel)
            wheels.append(wheel)
        }
        car.position = CGPoint(x: -260, y: -2)
        addChild(car)
        for wheel in wheels {
            wheel.run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: 0.35)))
        }

        let driveIn = SKAction.moveTo(x: -34, duration: 1.4)
        driveIn.timingMode = .easeOut
        let honk = SKAction.run { [weak self] in
            guard let self = self else { return }
            let label = SKLabelNode(text: "♥ BEEP BEEP ♥")
            label.fontName = "Helvetica-Bold"
            label.fontSize = 10
            label.fontColor = .white
            label.position = CGPoint(x: -34, y: 24)
            label.zPosition = 31
            self.addChild(label)
            label.run(SKAction.sequence([SKAction.moveBy(x: 0, y: 12, duration: 1.0), SKAction.fadeOut(withDuration: 0.4), SKAction.removeFromParent()]))
        }
        let getIn = SKAction.run {
            woman.run(SKAction.sequence([
                SKAction.moveTo(x: -30, duration: 0.6),
                SKAction.group([SKAction.scale(to: 0.4, duration: 0.3), SKAction.fadeOut(withDuration: 0.3)])
            ]))
        }
        let driveOff = SKAction.moveTo(x: 300, duration: 1.8)
        driveOff.timingMode = .easeIn
        car.run(SKAction.sequence([
            driveIn, honk, SKAction.wait(forDuration: 0.4), getIn, SKAction.wait(forDuration: 1.1),
            driveOff, SKAction.removeFromParent()
        ]))
    }

    /// Boss level cleared: the dog trots out, lifts a leg at the base and pees, then wags happily
    func playDogPeeAnimation() {
        guard let dog = catNode, !isDestroyed else { return }
        dog.removeAllActions()

        let walkOut = SKAction.group([
            SKAction.moveTo(x: 26, duration: 0.8),
            SKAction.repeat(SKAction.sequence([SKAction.moveBy(x: 0, y: 2, duration: 0.1),
                                               SKAction.moveBy(x: 0, y: -2, duration: 0.1)]), count: 4)
        ])
        let liftLeg = SKAction.rotate(toAngle: 0.35, duration: 0.25)
        let pee = SKAction.run { [weak self] in self?.startPeeStream(from: CGPoint(x: 19, y: -8)) }
        let putLegDown = SKAction.rotate(toAngle: 0, duration: 0.25)
        let happy = SKAction.repeatForever(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 5, duration: 0.15), SKAction.moveBy(x: 0, y: -5, duration: 0.12),
            SKAction.wait(forDuration: 0.6)
        ]))
        dog.run(SKAction.sequence([
            SKAction.moveBy(x: 0, y: 8, duration: 0.15), SKAction.moveBy(x: 0, y: -8, duration: 0.12),
            walkOut, SKAction.wait(forDuration: 0.3), liftLeg, pee, SKAction.wait(forDuration: 2.2),
            putLegDown, happy
        ]))
    }

    /// Yellow drops arcing from the dog toward the base, and a growing puddle
    private func startPeeStream(from start: CGPoint) {
        let puddle = ellipse(4, 2, at: CGPoint(x: 9, y: -14), fill: SKColor(red: 1.0, green: 0.9, blue: 0.2, alpha: 0.85))
        puddle.zPosition = 1
        addChild(puddle)
        puddle.run(SKAction.scaleX(to: 3.2, y: 2.4, duration: 2.0))

        let drip = SKAction.run { [weak self] in
            guard let self = self else { return }
            let drop = self.ellipse(2, 2, at: start, fill: SKColor(red: 1.0, green: 0.88, blue: 0.15, alpha: 1))
            drop.zPosition = 3
            self.addChild(drop)
            let path = CGMutablePath()
            path.move(to: start)
            path.addQuadCurve(to: CGPoint(x: 9 + CGFloat.random(in: -2...2), y: -13), control: CGPoint(x: 13, y: -2))
            drop.run(SKAction.sequence([SKAction.follow(path, asOffset: false, orientToPath: false, duration: 0.3),
                                        SKAction.removeFromParent()]))
        }
        run(SKAction.repeat(SKAction.sequence([drip, SKAction.wait(forDuration: 0.04)]), count: 50))
    }
}
