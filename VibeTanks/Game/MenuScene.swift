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

    /// Create tank in profile view with skull commander sticking out
    private func createTankAndSkull() -> SKNode {
        let container = SKNode()

        // Tank in profile (side view) - facing right
        let tank = createProfileTankWithSkull()
        container.addChild(tank)

        // Add subtle animation
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: 1.03, duration: 1.5),
            SKAction.scaleY(to: 0.97, duration: 1.5)
        ])
        container.run(SKAction.repeatForever(breathe))

        return container
    }

    /// Create a tank in profile (side) view with skull commander
    private func createProfileTankWithSkull() -> SKNode {
        let tank = SKNode()
        let tankColor = SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0)  // Army green
        let darkColor = SKColor(red: 0.1, green: 0.3, blue: 0.1, alpha: 1.0)

        // Track (bottom)
        let track = SKShapeNode(rectOf: CGSize(width: 80, height: 20), cornerRadius: 10)
        track.fillColor = darkColor
        track.strokeColor = .black
        track.lineWidth = 1
        track.position = CGPoint(x: 0, y: -20)
        tank.addChild(track)

        // Track wheels
        for i in 0..<5 {
            let wheel = SKShapeNode(circleOfRadius: 7)
            wheel.fillColor = .darkGray
            wheel.strokeColor = .black
            wheel.lineWidth = 1
            wheel.position = CGPoint(x: CGFloat(i - 2) * 18, y: -20)
            tank.addChild(wheel)
        }

        // Hull (main body)
        let hull = SKShapeNode(rectOf: CGSize(width: 65, height: 25), cornerRadius: 3)
        hull.fillColor = tankColor
        hull.strokeColor = darkColor
        hull.lineWidth = 1
        hull.position = CGPoint(x: -5, y: -2)
        tank.addChild(hull)

        // Turret base
        let turret = SKShapeNode(ellipseOf: CGSize(width: 35, height: 22))
        turret.fillColor = tankColor
        turret.strokeColor = darkColor
        turret.lineWidth = 1
        turret.position = CGPoint(x: -8, y: 12)
        tank.addChild(turret)

        // Hatch opening (where skull comes out)
        let hatch = SKShapeNode(ellipseOf: CGSize(width: 18, height: 10))
        hatch.fillColor = .black
        hatch.strokeColor = darkColor
        hatch.lineWidth = 1
        hatch.position = CGPoint(x: -8, y: 18)
        tank.addChild(hatch)

        // Barrel (pointing right)
        let barrel = SKShapeNode(rectOf: CGSize(width: 45, height: 9), cornerRadius: 2)
        barrel.fillColor = darkColor
        barrel.strokeColor = .black
        barrel.lineWidth = 1
        barrel.position = CGPoint(x: 25, y: 12)
        tank.addChild(barrel)

        // Muzzle brake
        let muzzle = SKShapeNode(rectOf: CGSize(width: 8, height: 14))
        muzzle.fillColor = darkColor
        muzzle.strokeColor = .black
        muzzle.lineWidth = 1
        muzzle.position = CGPoint(x: 52, y: 12)
        tank.addChild(muzzle)

        // Star emblem on hull
        let star = createStar(size: 10, color: .red)
        star.position = CGPoint(x: -5, y: -2)
        tank.addChild(star)

        // Skull commander sticking out of hatch (profile view, facing right)
        let skull = createProfileSkull()
        skull.position = CGPoint(x: -8, y: 38)
        tank.addChild(skull)

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

    /// Create a smiling skull in profile view (facing right) with war hat
    private func createProfileSkull() -> SKNode {
        let skull = SKNode()
        let boneColor = SKColor(red: 0.95, green: 0.9, blue: 0.8, alpha: 1.0)
        let boneOutline = SKColor(red: 0.6, green: 0.55, blue: 0.45, alpha: 1.0)

        // War hat (pilotka) in profile - tilted
        let hat = SKShapeNode()
        let hatPath = CGMutablePath()
        hatPath.move(to: CGPoint(x: -12, y: 12))
        hatPath.addLine(to: CGPoint(x: 8, y: 20))
        hatPath.addLine(to: CGPoint(x: 18, y: 14))
        hatPath.addLine(to: CGPoint(x: 12, y: 10))
        hatPath.addLine(to: CGPoint(x: -8, y: 10))
        hatPath.closeSubpath()
        hat.path = hatPath
        hat.fillColor = SKColor(red: 0.35, green: 0.25, blue: 0.15, alpha: 1.0)
        hat.strokeColor = SKColor(red: 0.25, green: 0.15, blue: 0.05, alpha: 1.0)
        hat.lineWidth = 1
        skull.addChild(hat)

        // Hat star (small, on side)
        let hatStar = createStar(size: 5, color: .red)
        hatStar.position = CGPoint(x: 10, y: 14)
        skull.addChild(hatStar)

        // Skull profile shape (side view - more skull-like)
        let head = SKShapeNode()
        let headPath = CGMutablePath()
        // Back of skull (rounded)
        headPath.move(to: CGPoint(x: -15, y: 8))
        headPath.addQuadCurve(to: CGPoint(x: -12, y: -8), control: CGPoint(x: -18, y: 0))
        // Jaw line
        headPath.addLine(to: CGPoint(x: 5, y: -12))
        // Chin
        headPath.addQuadCurve(to: CGPoint(x: 12, y: -8), control: CGPoint(x: 10, y: -14))
        // Front of face (nose area dips in)
        headPath.addLine(to: CGPoint(x: 14, y: -2))
        headPath.addQuadCurve(to: CGPoint(x: 10, y: 5), control: CGPoint(x: 16, y: 2))
        // Forehead
        headPath.addQuadCurve(to: CGPoint(x: -15, y: 8), control: CGPoint(x: 0, y: 14))
        headPath.closeSubpath()
        head.path = headPath
        head.fillColor = boneColor
        head.strokeColor = boneOutline
        head.lineWidth = 2
        skull.addChild(head)

        // Eye socket (single, profile view - dark hollow)
        let eyeSocket = SKShapeNode(ellipseOf: CGSize(width: 10, height: 12))
        eyeSocket.fillColor = .black
        eyeSocket.strokeColor = .clear
        eyeSocket.position = CGPoint(x: 4, y: 2)
        skull.addChild(eyeSocket)

        // Eye glint (friendly)
        let glint = SKShapeNode(circleOfRadius: 2)
        glint.fillColor = .white
        glint.strokeColor = .clear
        glint.position = CGPoint(x: 6, y: 4)
        skull.addChild(glint)

        // Nose hole (profile - just a dark area)
        let nose = SKShapeNode()
        let nosePath = CGMutablePath()
        nosePath.move(to: CGPoint(x: 12, y: -2))
        nosePath.addLine(to: CGPoint(x: 10, y: -5))
        nosePath.addLine(to: CGPoint(x: 14, y: -4))
        nosePath.closeSubpath()
        nose.path = nosePath
        nose.fillColor = .black
        nose.strokeColor = .clear
        skull.addChild(nose)

        // Teeth (profile view - showing smile)
        let teeth = SKShapeNode()
        let teethPath = CGMutablePath()
        teethPath.move(to: CGPoint(x: 5, y: -10))
        teethPath.addLine(to: CGPoint(x: 12, y: -8))
        // Individual teeth lines
        for i in 0..<4 {
            let x = CGFloat(5 + i * 2)
            teethPath.move(to: CGPoint(x: x, y: -10))
            teethPath.addLine(to: CGPoint(x: x + 1, y: -7))
        }
        teeth.path = teethPath
        teeth.strokeColor = boneOutline
        teeth.lineWidth = 1
        teeth.fillColor = .clear
        skull.addChild(teeth)

        // Upper teeth row
        let upperTeeth = SKShapeNode(rectOf: CGSize(width: 8, height: 3), cornerRadius: 1)
        upperTeeth.fillColor = boneColor
        upperTeeth.strokeColor = boneOutline
        upperTeeth.lineWidth = 0.5
        upperTeeth.position = CGPoint(x: 9, y: -8)
        skull.addChild(upperTeeth)

        // Cheekbone highlight
        let cheek = SKShapeNode(ellipseOf: CGSize(width: 6, height: 4))
        cheek.fillColor = SKColor(red: 1.0, green: 0.7, blue: 0.7, alpha: 0.4)
        cheek.strokeColor = .clear
        cheek.position = CGPoint(x: 8, y: -3)
        skull.addChild(cheek)

        // Jaw bone detail
        let jawLine = SKShapeNode()
        let jawPath = CGMutablePath()
        jawPath.move(to: CGPoint(x: -10, y: -6))
        jawPath.addQuadCurve(to: CGPoint(x: 5, y: -11), control: CGPoint(x: -2, y: -10))
        jawLine.path = jawPath
        jawLine.strokeColor = boneOutline
        jawLine.lineWidth = 1
        jawLine.fillColor = .clear
        skull.addChild(jawLine)

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
