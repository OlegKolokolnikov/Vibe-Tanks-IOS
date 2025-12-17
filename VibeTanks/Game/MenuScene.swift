import SpriteKit

class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupMenu()
    }

    private func setupMenu() {
        // Title
        let title = SKLabelNode(text: "VIBE TANKS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 48
        title.fontColor = .yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "Tank Battle Game")
        subtitle.fontName = "Helvetica"
        subtitle.fontSize = 20
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.75 - 35)
        addChild(subtitle)

        // Tank in profile view and skull with war hat
        let decoration = createTankAndSkull()
        decoration.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
        addChild(decoration)

        // Play button
        let playButton = createButton(text: "PLAY", position: CGPoint(x: size.width / 2, y: size.height * 0.28))
        playButton.name = "playButton"
        addChild(playButton)

        // Instructions
        let instructions = SKLabelNode(text: "Defend your base from enemy tanks!")
        instructions.fontName = "Helvetica"
        instructions.fontSize = 14
        instructions.fontColor = .lightGray
        instructions.position = CGPoint(x: size.width / 2, y: size.height * 0.18)
        addChild(instructions)

        // Credits
        let credits = SKLabelNode(text: "Designed by Oleg")
        credits.fontName = "Helvetica-Bold"
        credits.fontSize = 14
        credits.fontColor = .gray
        credits.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        addChild(credits)
    }

    /// Create tank in profile view with smiling skull in war hat
    private func createTankAndSkull() -> SKNode {
        let container = SKNode()

        // Tank in profile (side view) - facing right
        let tank = createProfileTank()
        tank.position = CGPoint(x: -60, y: -20)
        container.addChild(tank)

        // Smiling skull with war hat
        let skull = createSmilingSkull()
        skull.position = CGPoint(x: 60, y: 0)
        container.addChild(skull)

        // Add subtle animation
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: 1.03, duration: 1.5),
            SKAction.scaleY(to: 0.97, duration: 1.5)
        ])
        container.run(SKAction.repeatForever(breathe))

        return container
    }

    /// Create a tank in profile (side) view
    private func createProfileTank() -> SKNode {
        let tank = SKNode()
        let tankColor = SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)  // Army green
        let darkColor = SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)

        // Track (bottom)
        let track = SKShapeNode(rectOf: CGSize(width: 70, height: 18), cornerRadius: 9)
        track.fillColor = darkColor
        track.strokeColor = .black
        track.lineWidth = 1
        track.position = CGPoint(x: 0, y: -15)
        tank.addChild(track)

        // Track wheels
        for i in 0..<4 {
            let wheel = SKShapeNode(circleOfRadius: 6)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            wheel.position = CGPoint(x: CGFloat(i - 1) * 18 - 9, y: -15)
            tank.addChild(wheel)
        }

        // Hull (main body)
        let hull = SKShapeNode(rectOf: CGSize(width: 55, height: 22), cornerRadius: 3)
        hull.fillColor = tankColor
        hull.strokeColor = darkColor
        hull.lineWidth = 1
        hull.position = CGPoint(x: -5, y: 2)
        tank.addChild(hull)

        // Turret
        let turret = SKShapeNode(ellipseOf: CGSize(width: 30, height: 20))
        turret.fillColor = tankColor
        turret.strokeColor = darkColor
        turret.lineWidth = 1
        turret.position = CGPoint(x: -5, y: 15)
        tank.addChild(turret)

        // Barrel (pointing right)
        let barrel = SKShapeNode(rectOf: CGSize(width: 35, height: 8), cornerRadius: 2)
        barrel.fillColor = darkColor
        barrel.strokeColor = .black
        barrel.lineWidth = 1
        barrel.position = CGPoint(x: 22, y: 15)
        tank.addChild(barrel)

        // Muzzle brake
        let muzzle = SKShapeNode(rectOf: CGSize(width: 6, height: 12))
        muzzle.fillColor = darkColor
        muzzle.strokeColor = .black
        muzzle.lineWidth = 1
        muzzle.position = CGPoint(x: 42, y: 15)
        tank.addChild(muzzle)

        // Star emblem on turret
        let star = createStar(size: 8, color: .red)
        star.position = CGPoint(x: -5, y: 15)
        tank.addChild(star)

        return tank
    }

    /// Create a small star shape
    private func createStar(size: CGFloat, color: SKColor) -> SKNode {
        let star = SKShapeNode()
        let path = CGMutablePath()
        let points = 5
        let outerRadius = size
        let innerRadius = size * 0.4

        for i in 0..<points * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        star.path = path
        star.fillColor = color
        star.strokeColor = .darkGray
        star.lineWidth = 0.5
        return star
    }

    /// Create a smiling skull with war hat
    private func createSmilingSkull() -> SKNode {
        let skull = SKNode()

        // War hat (pilotka style)
        let hat = SKShapeNode()
        let hatPath = CGMutablePath()
        hatPath.move(to: CGPoint(x: -25, y: 25))
        hatPath.addLine(to: CGPoint(x: 0, y: 40))
        hatPath.addLine(to: CGPoint(x: 25, y: 25))
        hatPath.addLine(to: CGPoint(x: 20, y: 25))
        hatPath.addLine(to: CGPoint(x: 0, y: 35))
        hatPath.addLine(to: CGPoint(x: -20, y: 25))
        hatPath.closeSubpath()
        hat.path = hatPath
        hat.fillColor = SKColor(red: 0.4, green: 0.25, blue: 0.1, alpha: 1.0)  // Khaki/brown
        hat.strokeColor = SKColor(red: 0.3, green: 0.15, blue: 0.05, alpha: 1.0)
        hat.lineWidth = 1
        skull.addChild(hat)

        // Hat star
        let hatStar = createStar(size: 6, color: .red)
        hatStar.position = CGPoint(x: 0, y: 30)
        skull.addChild(hatStar)

        // Skull shape (rounded)
        let head = SKShapeNode(ellipseOf: CGSize(width: 50, height: 55))
        head.fillColor = SKColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)  // Bone white
        head.strokeColor = SKColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 1.0)
        head.lineWidth = 2
        head.position = CGPoint(x: 0, y: 0)
        skull.addChild(head)

        // Eye sockets (dark, looking at player)
        let leftEyeSocket = SKShapeNode(ellipseOf: CGSize(width: 14, height: 16))
        leftEyeSocket.fillColor = .black
        leftEyeSocket.strokeColor = .clear
        leftEyeSocket.position = CGPoint(x: -10, y: 8)
        skull.addChild(leftEyeSocket)

        let rightEyeSocket = SKShapeNode(ellipseOf: CGSize(width: 14, height: 16))
        rightEyeSocket.fillColor = .black
        rightEyeSocket.strokeColor = .clear
        rightEyeSocket.position = CGPoint(x: 10, y: 8)
        skull.addChild(rightEyeSocket)

        // Eye glints (friendly look)
        let leftGlint = SKShapeNode(circleOfRadius: 3)
        leftGlint.fillColor = .white
        leftGlint.strokeColor = .clear
        leftGlint.position = CGPoint(x: -7, y: 10)
        skull.addChild(leftGlint)

        let rightGlint = SKShapeNode(circleOfRadius: 3)
        rightGlint.fillColor = .white
        rightGlint.strokeColor = .clear
        rightGlint.position = CGPoint(x: 13, y: 10)
        skull.addChild(rightGlint)

        // Nose hole (triangle)
        let nose = SKShapeNode()
        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: 0, y: -2))
        nosePath.addLine(to: CGPoint(x: -5, y: -10))
        nosePath.addLine(to: CGPoint(x: 5, y: -10))
        nosePath.closeSubpath()
        nose.path = nosePath
        nose.fillColor = .black
        nose.strokeColor = .clear
        skull.addChild(nose)

        // Smiling mouth with teeth
        let smile = SKShapeNode()
        let smilePath = CGMutablePath()
        smilePath.move(to: CGPoint(x: -15, y: -18))
        smilePath.addQuadCurve(to: CGPoint(x: 15, y: -18), control: CGPoint(x: 0, y: -28))
        smile.path = smilePath
        smile.strokeColor = .black
        smile.lineWidth = 2
        smile.fillColor = .clear
        skull.addChild(smile)

        // Teeth
        for i in 0..<6 {
            let tooth = SKShapeNode(rectOf: CGSize(width: 4, height: 6))
            tooth.fillColor = SKColor(red: 1.0, green: 0.98, blue: 0.9, alpha: 1.0)
            tooth.strokeColor = SKColor(red: 0.7, green: 0.65, blue: 0.55, alpha: 1.0)
            tooth.lineWidth = 0.5
            tooth.position = CGPoint(x: CGFloat(i - 2) * 5 - 2.5, y: -20)
            skull.addChild(tooth)
        }

        // Cheek blush (friendly look)
        let leftBlush = SKShapeNode(ellipseOf: CGSize(width: 10, height: 6))
        leftBlush.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 0.5)
        leftBlush.strokeColor = .clear
        leftBlush.position = CGPoint(x: -18, y: -2)
        skull.addChild(leftBlush)

        let rightBlush = SKShapeNode(ellipseOf: CGSize(width: 10, height: 6))
        rightBlush.fillColor = SKColor(red: 1.0, green: 0.6, blue: 0.6, alpha: 0.5)
        rightBlush.strokeColor = .clear
        rightBlush.position = CGPoint(x: 18, y: -2)
        skull.addChild(rightBlush)

        return skull
    }

    private func createButton(text: String, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        // Button background
        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)

        // Button text
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)

        for node in nodes {
            if node.name == "playButton" || node.parent?.name == "playButton" {
                startGame()
                return
            }
        }
    }

    private func startGame() {
        // Generate a new random session seed for this game session
        let sessionSeed = UInt64.random(in: 0..<UInt64.max)
        let gameScene = GameScene(size: size, level: 1, score: 0, sessionSeed: sessionSeed)
        gameScene.scaleMode = scaleMode

        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }
}
