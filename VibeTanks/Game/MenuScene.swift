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
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.7)
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "Tank Battle Game")
        subtitle.fontName = "Helvetica"
        subtitle.fontSize = 20
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.7 - 40)
        addChild(subtitle)

        // Play button
        let playButton = createButton(text: "PLAY", position: CGPoint(x: size.width / 2, y: size.height * 0.48))
        playButton.name = "playButton"
        addChild(playButton)

        // Test button (5 enemies only)
        let testButton = createButton(text: "TEST (5)", position: CGPoint(x: size.width / 2, y: size.height * 0.38), smaller: true)
        testButton.name = "testButton"
        addChild(testButton)

        // Instructions
        let instructions = SKLabelNode(text: "Defend your base from enemy tanks!")
        instructions.fontName = "Helvetica"
        instructions.fontSize = 14
        instructions.fontColor = .lightGray
        instructions.position = CGPoint(x: size.width / 2, y: size.height * 0.25)
        addChild(instructions)

        // Controls info
        let controls = SKLabelNode(text: "Use joystick to move, tap FIRE to shoot")
        controls.fontName = "Helvetica"
        controls.fontSize = 12
        controls.fontColor = .lightGray
        controls.position = CGPoint(x: size.width / 2, y: size.height * 0.20)
        addChild(controls)

        // Credits
        let credits = SKLabelNode(text: "Designed by Oleg and Artiom")
        credits.fontName = "Helvetica"
        credits.fontSize = 11
        credits.fontColor = .gray
        credits.position = CGPoint(x: size.width / 2, y: size.height * 0.08)
        addChild(credits)

        // Add tank decorations
        addTankDecoration(at: CGPoint(x: size.width * 0.2, y: size.height * 0.5), direction: .right)
        addTankDecoration(at: CGPoint(x: size.width * 0.8, y: size.height * 0.5), direction: .left)
    }

    private func createButton(text: String, position: CGPoint, smaller: Bool = false) -> SKNode {
        let container = SKNode()
        container.position = position

        // Button background
        let buttonSize = smaller ? CGSize(width: 140, height: 36) : CGSize(width: 200, height: 50)
        let background = SKShapeNode(rectOf: buttonSize, cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = smaller ? .gray : .yellow
        background.lineWidth = 2
        container.addChild(background)

        // Button text
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = smaller ? 16 : 24
        label.fontColor = smaller ? .lightGray : .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    private func addTankDecoration(at position: CGPoint, direction: Direction) {
        let tank = SKShapeNode(rectOf: CGSize(width: 28, height: 28))
        tank.fillColor = .yellow
        tank.strokeColor = .orange
        tank.lineWidth = 2
        tank.position = position

        // Barrel
        let barrelSize = CGSize(width: 8, height: 14)
        let barrel = SKShapeNode(rectOf: barrelSize)
        barrel.fillColor = .yellow
        barrel.strokeColor = .orange
        barrel.lineWidth = 1

        switch direction {
        case .up:
            barrel.position = CGPoint(x: 0, y: 20)
        case .down:
            barrel.position = CGPoint(x: 0, y: -20)
        case .left:
            barrel.position = CGPoint(x: -20, y: 0)
            barrel.zRotation = .pi / 2
        case .right:
            barrel.position = CGPoint(x: 20, y: 0)
            barrel.zRotation = .pi / 2
        }

        tank.addChild(barrel)
        addChild(tank)

        // Add idle animation
        let moveUp = SKAction.moveBy(x: 0, y: 5, duration: 1.0)
        let moveDown = SKAction.moveBy(x: 0, y: -5, duration: 1.0)
        let sequence = SKAction.sequence([moveUp, moveDown])
        tank.run(SKAction.repeatForever(sequence))
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
            if node.name == "testButton" || node.parent?.name == "testButton" {
                startGame(testEnemyCount: 5)
                return
            }
        }
    }

    private func startGame(testEnemyCount: Int? = nil) {
        // Generate a new random session seed for this game session
        let sessionSeed = UInt64.random(in: 0..<UInt64.max)
        let gameScene = GameScene(size: size, level: 1, score: 0, sessionSeed: sessionSeed, testEnemyCount: testEnemyCount)
        gameScene.scaleMode = scaleMode

        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }
}
