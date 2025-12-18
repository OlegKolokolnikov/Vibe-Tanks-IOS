import SpriteKit

class OptionsScene: SKScene {

    private var controlsToggle: SKNode!
    private var colorButtons: [GameSettings.TankColor: SKNode] = [:]
    private var tankPreview: SKNode?

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    private func setupUI() {
        // Title
        let title = SKLabelNode(text: "OPTIONS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 42
        title.fontColor = .yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.85)
        addChild(title)

        // Controls Position Section
        setupControlsSection()

        // Tank Color Section
        setupColorSection()

        // Back button
        let backButton = createButton(text: "BACK", position: CGPoint(x: size.width / 2, y: size.height * 0.1))
        backButton.name = "backButton"
        addChild(backButton)
    }

    // MARK: - Controls Section

    private func setupControlsSection() {
        let sectionY = size.height * 0.68

        // Section label
        let label = SKLabelNode(text: "Controls Position")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: sectionY + 30)
        addChild(label)

        // Toggle container
        let toggleContainer = SKNode()
        toggleContainer.position = CGPoint(x: size.width / 2, y: sectionY - 20)
        addChild(toggleContainer)
        controlsToggle = toggleContainer

        // Left option: Fire on LEFT
        let leftOption = createToggleOption(
            text: "Fire LEFT",
            isSelected: GameSettings.shared.controlsSwapped,
            xOffset: -100
        )
        leftOption.name = "fireLeft"
        toggleContainer.addChild(leftOption)

        // Right option: Fire on RIGHT (default)
        let rightOption = createToggleOption(
            text: "Fire RIGHT",
            isSelected: !GameSettings.shared.controlsSwapped,
            xOffset: 100
        )
        rightOption.name = "fireRight"
        toggleContainer.addChild(rightOption)

        // Hint
        let hint = SKLabelNode(text: "Swaps joystick and fire button positions")
        hint.fontName = "Helvetica"
        hint.fontSize = 14
        hint.fontColor = .gray
        hint.position = CGPoint(x: size.width / 2, y: sectionY - 60)
        addChild(hint)
    }

    private func createToggleOption(text: String, isSelected: Bool, xOffset: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: xOffset, y: 0)

        let bg = SKShapeNode(rectOf: CGSize(width: 140, height: 45), cornerRadius: 6)
        bg.fillColor = isSelected ? SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0) : SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        bg.strokeColor = isSelected ? .green : .gray
        bg.lineWidth = 2
        bg.name = "bg"
        container.addChild(bg)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 18
        label.fontColor = isSelected ? .white : .gray
        label.verticalAlignmentMode = .center
        label.name = "label"
        container.addChild(label)

        return container
    }

    // MARK: - Color Section

    private func setupColorSection() {
        let sectionY = size.height * 0.42

        // Section label
        let label = SKLabelNode(text: "Tank Color")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: sectionY + 30)
        addChild(label)

        // Color options
        let colors = GameSettings.TankColor.allCases
        let totalWidth: CGFloat = CGFloat(colors.count - 1) * 80
        let startX = size.width / 2 - totalWidth / 2

        for (index, tankColor) in colors.enumerated() {
            let colorButton = createColorButton(
                tankColor: tankColor,
                isSelected: GameSettings.shared.playerTankColor == tankColor
            )
            colorButton.position = CGPoint(x: startX + CGFloat(index) * 80, y: sectionY - 25)
            colorButton.name = "color_\(tankColor.rawValue)"
            addChild(colorButton)
            colorButtons[tankColor] = colorButton
        }

        // Tank preview
        let preview = createTankPreview()
        preview.position = CGPoint(x: size.width / 2, y: sectionY - 100)
        addChild(preview)
        tankPreview = preview
        updateTankPreview()
    }

    private func createColorButton(tankColor: GameSettings.TankColor, isSelected: Bool) -> SKNode {
        let container = SKNode()

        // Color circle
        let circle = SKShapeNode(circleOfRadius: 25)
        circle.fillColor = tankColor.color
        circle.strokeColor = isSelected ? .white : .gray
        circle.lineWidth = isSelected ? 4 : 2
        circle.name = "circle"
        container.addChild(circle)

        // Selection indicator
        if isSelected {
            let check = SKLabelNode(text: "\u{2713}")
            check.fontName = "Helvetica-Bold"
            check.fontSize = 24
            check.fontColor = .black
            check.verticalAlignmentMode = .center
            check.name = "check"
            container.addChild(check)
        }

        // Label
        let label = SKLabelNode(text: tankColor.displayName)
        label.fontName = "Helvetica"
        label.fontSize = 14
        label.fontColor = isSelected ? .white : .gray
        label.position = CGPoint(x: 0, y: -40)
        label.name = "colorLabel"
        container.addChild(label)

        return container
    }

    private func createTankPreview() -> SKNode {
        let container = SKNode()

        let label = SKLabelNode(text: "Preview:")
        label.fontName = "Helvetica"
        label.fontSize = 16
        label.fontColor = .gray
        label.position = CGPoint(x: -50, y: 0)
        container.addChild(label)

        return container
    }

    private func updateTankPreview() {
        guard let preview = tankPreview else { return }

        // Remove old tank preview
        preview.childNode(withName: "tankSprite")?.removeFromParent()

        // Create simple tank representation
        let tankSize: CGFloat = 40
        let color = GameSettings.shared.playerTankColor.color

        let tank = SKNode()
        tank.name = "tankSprite"
        tank.position = CGPoint(x: 30, y: 0)

        // Body
        let body = SKShapeNode(rectOf: CGSize(width: tankSize, height: tankSize * 0.8), cornerRadius: 4)
        body.fillColor = color
        body.strokeColor = color.darker()
        body.lineWidth = 2
        tank.addChild(body)

        // Turret
        let turret = SKShapeNode(circleOfRadius: tankSize * 0.25)
        turret.fillColor = color.darker()
        turret.strokeColor = color.darker().darker()
        turret.lineWidth = 1
        turret.position = CGPoint(x: 0, y: 2)
        tank.addChild(turret)

        // Gun
        let gun = SKShapeNode(rectOf: CGSize(width: tankSize * 0.5, height: 6), cornerRadius: 2)
        gun.fillColor = color.darker()
        gun.strokeColor = .black
        gun.lineWidth = 1
        gun.position = CGPoint(x: 0, y: tankSize * 0.4)
        tank.addChild(gun)

        // Tracks
        let leftTrack = SKShapeNode(rectOf: CGSize(width: tankSize * 0.2, height: tankSize * 0.9))
        leftTrack.fillColor = SKColor(white: 0.3, alpha: 1)
        leftTrack.strokeColor = .black
        leftTrack.lineWidth = 1
        leftTrack.position = CGPoint(x: -tankSize * 0.45, y: 0)
        tank.addChild(leftTrack)

        let rightTrack = SKShapeNode(rectOf: CGSize(width: tankSize * 0.2, height: tankSize * 0.9))
        rightTrack.fillColor = SKColor(white: 0.3, alpha: 1)
        rightTrack.strokeColor = .black
        rightTrack.lineWidth = 1
        rightTrack.position = CGPoint(x: tankSize * 0.45, y: 0)
        tank.addChild(rightTrack)

        preview.addChild(tank)
    }

    // MARK: - Button Creation

    private func createButton(text: String, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        let background = SKShapeNode(rectOf: CGSize(width: 160, height: 45), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 22
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    // MARK: - Input Handling

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        handleClick(at: location)
    }
    #elseif os(macOS)
    override func mouseDown(with event: NSEvent) {
        let location = event.location(in: self)
        handleClick(at: location)
    }

    override func keyDown(with event: NSEvent) {
        // Escape to go back
        if event.keyCode == 53 {
            goBack()
        }
    }
    #endif

    private func handleClick(at location: CGPoint) {
        let nodes = nodes(at: location)

        for node in nodes {
            let name = node.name ?? node.parent?.name ?? ""

            // Back button
            if name == "backButton" || node.parent?.name == "backButton" {
                goBack()
                return
            }

            // Controls toggle
            if name == "fireLeft" || node.parent?.name == "fireLeft" {
                setControlsSwapped(true)
                return
            }
            if name == "fireRight" || node.parent?.name == "fireRight" {
                setControlsSwapped(false)
                return
            }

            // Color buttons
            for tankColor in GameSettings.TankColor.allCases {
                let colorName = "color_\(tankColor.rawValue)"
                if name == colorName || node.parent?.name == colorName {
                    setTankColor(tankColor)
                    return
                }
            }
        }
    }

    // MARK: - Actions

    private func setControlsSwapped(_ swapped: Bool) {
        GameSettings.shared.controlsSwapped = swapped
        updateControlsToggle()
    }

    private func updateControlsToggle() {
        let swapped = GameSettings.shared.controlsSwapped

        if let leftOption = controlsToggle.childNode(withName: "fireLeft") {
            updateToggleVisual(leftOption, isSelected: swapped)
        }
        if let rightOption = controlsToggle.childNode(withName: "fireRight") {
            updateToggleVisual(rightOption, isSelected: !swapped)
        }
    }

    private func updateToggleVisual(_ node: SKNode, isSelected: Bool) {
        if let bg = node.childNode(withName: "bg") as? SKShapeNode {
            bg.fillColor = isSelected ? SKColor(red: 0.2, green: 0.5, blue: 0.2, alpha: 1.0) : SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            bg.strokeColor = isSelected ? .green : .gray
        }
        if let label = node.childNode(withName: "label") as? SKLabelNode {
            label.fontColor = isSelected ? .white : .gray
        }
    }

    private func setTankColor(_ color: GameSettings.TankColor) {
        GameSettings.shared.playerTankColor = color
        updateColorButtons()
        updateTankPreview()
    }

    private func updateColorButtons() {
        let selectedColor = GameSettings.shared.playerTankColor

        for (tankColor, button) in colorButtons {
            let isSelected = tankColor == selectedColor

            if let circle = button.childNode(withName: "circle") as? SKShapeNode {
                circle.strokeColor = isSelected ? .white : .gray
                circle.lineWidth = isSelected ? 4 : 2
            }

            // Add/remove check mark
            button.childNode(withName: "check")?.removeFromParent()
            if isSelected {
                let check = SKLabelNode(text: "\u{2713}")
                check.fontName = "Helvetica-Bold"
                check.fontSize = 24
                check.fontColor = .black
                check.verticalAlignmentMode = .center
                check.name = "check"
                button.addChild(check)
            }

            if let label = button.childNode(withName: "colorLabel") as? SKLabelNode {
                label.fontColor = isSelected ? .white : .gray
            }
        }
    }

    private func goBack() {
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = scaleMode
        view?.presentScene(menuScene, transition: .fade(withDuration: 0.3))
    }
}

// MARK: - SKColor Extension

extension SKColor {
    func darker() -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: max(r - 0.2, 0), green: max(g - 0.2, 0), blue: max(b - 0.2, 0), alpha: a)
    }
}
