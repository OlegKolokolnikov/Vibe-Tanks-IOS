import SpriteKit

class OptionsScene: SKScene {

    private var controlsToggle: SKNode!
    /// Color buttons per player (index 0 = player 1, 1 = player 2)
    private var colorButtons: [[GameSettings.TankColor: SKNode]] = [[:], [:]]
    private var tankPreviews: [SKNode] = []

    // Two-column layout: controls + volume on the left, tank color on the right
    private var leftColumnX: CGFloat { size.width * 0.27 }
    private var rightColumnX: CGFloat { size.width * 0.73 }

    // Volume control
    private var volumeLabel: SKLabelNode?
    private var volumeSegments: [SKShapeNode] = []
    private var volumeBarFrame: CGRect = .zero  // scene coordinates, includes touch padding
    private var isDraggingVolume = false

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

        // Volume Section
        setupVolumeSection()

        // Tank Color Section
        setupColorSection()

        // Back button and the controls screen (keys and touch layout per player)
        let backButton = createButton(text: "BACK", position: CGPoint(x: size.width / 2 - 95, y: size.height * 0.1))
        backButton.name = "backButton"
        addChild(backButton)

        let controlsButton = createButton(text: "CONTROLS", position: CGPoint(x: size.width / 2 + 95, y: size.height * 0.1))
        controlsButton.name = "controlsButton"
        addChild(controlsButton)
    }

    // MARK: - Controls Section

    private func setupControlsSection() {
        let sectionY = size.height * 0.66

        // Section label
        let label = SKLabelNode(text: "Controls Position")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: leftColumnX, y: sectionY + 30)
        addChild(label)

        // Toggle container
        let toggleContainer = SKNode()
        toggleContainer.position = CGPoint(x: leftColumnX, y: sectionY - 20)
        addChild(toggleContainer)
        controlsToggle = toggleContainer

        // Left option: Fire on LEFT
        let leftOption = createToggleOption(
            text: "Fire LEFT",
            isSelected: GameSettings.shared.controlsSwapped,
            xOffset: -70
        )
        leftOption.name = "fireLeft"
        toggleContainer.addChild(leftOption)

        // Right option: Fire on RIGHT (default)
        let rightOption = createToggleOption(
            text: "Fire RIGHT",
            isSelected: !GameSettings.shared.controlsSwapped,
            xOffset: 70
        )
        rightOption.name = "fireRight"
        toggleContainer.addChild(rightOption)

        // Hint
        let hint = SKLabelNode(text: "Swaps joystick and fire button positions")
        hint.fontName = "Helvetica"
        hint.fontSize = 14
        hint.fontColor = .gray
        hint.position = CGPoint(x: leftColumnX, y: sectionY - 60)
        addChild(hint)
    }

    private func createToggleOption(text: String, isSelected: Bool, xOffset: CGFloat) -> SKNode {
        let container = SKNode()
        container.position = CGPoint(x: xOffset, y: 0)

        let bg = SKShapeNode(rectOf: CGSize(width: 130, height: 45), cornerRadius: 6)
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

    // MARK: - Volume Section

    private static let segmentWidth: CGFloat = 14
    private static let segmentSpacing: CGFloat = 3

    private func setupVolumeSection() {
        let sectionY = size.height * 0.34
        let levels = GameSettings.maxVolumeLevel

        // Section label (shows current percentage)
        let label = SKLabelNode(text: "")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: leftColumnX, y: sectionY + 30)
        addChild(label)
        volumeLabel = label

        // Segmented bar: tap or drag to set volume
        let barY = sectionY - 20
        let segmentStep = OptionsScene.segmentWidth + OptionsScene.segmentSpacing
        let barWidth = CGFloat(levels) * segmentStep - OptionsScene.segmentSpacing
        let barLeft = leftColumnX - barWidth / 2

        for i in 0..<levels {
            let segment = SKShapeNode(rectOf: CGSize(width: OptionsScene.segmentWidth, height: 24), cornerRadius: 2)
            segment.position = CGPoint(x: barLeft + CGFloat(i) * segmentStep + OptionsScene.segmentWidth / 2, y: barY)
            segment.lineWidth = 1
            addChild(segment)
            volumeSegments.append(segment)
        }
        // Generous vertical padding so the bar is easy to hit with a finger
        volumeBarFrame = CGRect(x: barLeft, y: barY - 22, width: barWidth, height: 44)

        // − and + buttons on either side of the bar
        let minusButton = createSmallButton(text: "\u{2212}", position: CGPoint(x: barLeft - 32, y: barY))
        minusButton.name = "volumeMinus"
        addChild(minusButton)

        let plusButton = createSmallButton(text: "+", position: CGPoint(x: barLeft + barWidth + 32, y: barY))
        plusButton.name = "volumePlus"
        addChild(plusButton)

        updateVolumeDisplay()
    }

    private func createSmallButton(text: String, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        let background = SKShapeNode(rectOf: CGSize(width: 40, height: 40), cornerRadius: 6)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 26
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    private func updateVolumeDisplay() {
        let level = SoundManager.shared.volumeLevel
        let percent = level * 100 / GameSettings.maxVolumeLevel
        if SoundManager.shared.isMuted {
            volumeLabel?.text = "Volume: Muted"
        } else {
            volumeLabel?.text = level == 0 ? "Volume: Off" : "Volume: \(percent)%"
        }

        for (i, segment) in volumeSegments.enumerated() {
            let isOn = i < level
            segment.fillColor = isOn ? SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0) : SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            segment.strokeColor = isOn ? .green : .gray
        }
    }

    private func setVolumeLevel(_ level: Int) {
        let clamped = min(max(level, 0), GameSettings.maxVolumeLevel)
        // Touching the volume control while muted unmutes, so the change is audible
        guard clamped != SoundManager.shared.volumeLevel || SoundManager.shared.isMuted else { return }
        SoundManager.shared.isMuted = false
        SoundManager.shared.volumeLevel = clamped
        updateVolumeDisplay()
        // Short sample so the player hears the new level
        SoundManager.shared.playShoot()
    }

    /// Map an x position on the bar to a volume level (left edge = off)
    private func setVolumeFromBar(x: CGFloat) {
        let fraction = min(max((x - volumeBarFrame.minX) / volumeBarFrame.width, 0), 1)
        let level = Int((fraction * CGFloat(GameSettings.maxVolumeLevel)).rounded(.up))
        setVolumeLevel(level)
    }

    // MARK: - Color Section

    private func setupColorSection() {
        let sectionY = size.height * 0.66

        // Section label
        let label = SKLabelNode(text: "Tank Color")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.position = CGPoint(x: rightColumnX, y: sectionY + 30)
        addChild(label)

        // One row of colors per player: [1P] (o) (o) (o) (o) [tank preview]
        let colors = GameSettings.TankColor.allCases
        let spacing: CGFloat = 70
        let totalWidth = CGFloat(colors.count - 1) * spacing
        let startX = rightColumnX - totalWidth / 2
        let rowSpacing: CGFloat = 80

        for player in 0..<2 {
            let rowY = sectionY - 20 - CGFloat(player) * rowSpacing

            let playerLabel = SKLabelNode(text: "\(player + 1)P")
            playerLabel.fontName = "Helvetica-Bold"
            playerLabel.fontSize = 20
            playerLabel.fontColor = .white
            playerLabel.verticalAlignmentMode = .center
            playerLabel.position = CGPoint(x: startX - 60, y: rowY)
            addChild(playerLabel)

            for (index, tankColor) in colors.enumerated() {
                let colorButton = createColorButton(tankColor: tankColor)
                colorButton.position = CGPoint(x: startX + CGFloat(index) * spacing, y: rowY)
                colorButton.name = "color\(player)_\(tankColor.rawValue)"
                addChild(colorButton)
                colorButtons[player][tankColor] = colorButton
            }

            let preview = SKNode()
            preview.position = CGPoint(x: startX + totalWidth + 60, y: rowY)
            addChild(preview)
            tankPreviews.append(preview)
        }

        updateColorButtons()
        updateTankPreviews()
    }

    private func selectedColor(forPlayer player: Int) -> GameSettings.TankColor {
        return player == 0 ? GameSettings.shared.playerTankColor : GameSettings.shared.player2TankColor
    }

    private func createColorButton(tankColor: GameSettings.TankColor) -> SKNode {
        let container = SKNode()

        // Color circle
        let circle = SKShapeNode(circleOfRadius: 22)
        circle.fillColor = tankColor.color
        circle.strokeColor = .gray
        circle.lineWidth = 2
        circle.name = "circle"
        container.addChild(circle)

        // Label
        let label = SKLabelNode(text: tankColor.displayName)
        label.fontName = "Helvetica"
        label.fontSize = 12
        label.fontColor = .gray
        label.position = CGPoint(x: 0, y: -36)
        label.name = "colorLabel"
        container.addChild(label)

        return container
    }

    private func updateTankPreviews() {
        for (player, preview) in tankPreviews.enumerated() {
            preview.removeAllChildren()
            preview.addChild(createPreviewTank(color: selectedColor(forPlayer: player).color, tankSize: 32))
        }
    }

    /// Simple tank drawing for the color preview
    private func createPreviewTank(color: SKColor, tankSize: CGFloat) -> SKNode {
        let tank = SKNode()

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
        let gun = SKShapeNode(rectOf: CGSize(width: 6, height: tankSize * 0.5), cornerRadius: 2)
        gun.fillColor = color.darker()
        gun.strokeColor = .black
        gun.lineWidth = 1
        gun.position = CGPoint(x: 0, y: tankSize * 0.4)
        tank.addChild(gun)

        // Tracks
        for side: CGFloat in [-1, 1] {
            let track = SKShapeNode(rectOf: CGSize(width: tankSize * 0.2, height: tankSize * 0.9))
            track.fillColor = SKColor(white: 0.3, alpha: 1)
            track.strokeColor = .black
            track.lineWidth = 1
            track.position = CGPoint(x: side * tankSize * 0.45, y: 0)
            tank.addChild(track)
        }

        return tank
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

        // Volume bar: tap or start dragging
        if volumeBarFrame.contains(location) {
            isDraggingVolume = true
            setVolumeFromBar(x: location.x)
            return
        }

        handleClick(at: location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isDraggingVolume, let touch = touches.first else { return }
        setVolumeFromBar(x: touch.location(in: self).x)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingVolume = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        isDraggingVolume = false
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
            if name == "controlsButton" || node.parent?.name == "controlsButton" {
                let controls = ControlsScene(size: size)
                controls.scaleMode = scaleMode
                view?.presentScene(controls, transition: .fade(withDuration: 0.3))
                return
            }

            // Volume buttons
            if name == "volumeMinus" {
                setVolumeLevel(SoundManager.shared.volumeLevel - 1)
                return
            }
            if name == "volumePlus" {
                setVolumeLevel(SoundManager.shared.volumeLevel + 1)
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

            // Color buttons (one row per player)
            for player in 0..<2 {
                for tankColor in GameSettings.TankColor.allCases {
                    let colorName = "color\(player)_\(tankColor.rawValue)"
                    if name == colorName || node.parent?.name == colorName {
                        setTankColor(tankColor, forPlayer: player)
                        return
                    }
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

    private func setTankColor(_ color: GameSettings.TankColor, forPlayer player: Int) {
        // The other player's color is taken: both tanks can't have the same color
        guard color != selectedColor(forPlayer: 1 - player) else { return }
        if player == 0 {
            GameSettings.shared.playerTankColor = color
        } else {
            GameSettings.shared.player2TankColor = color
        }
        updateColorButtons()
        updateTankPreviews()
    }

    /// Selected color: white ring + check mark. The other player's color: dimmed with a cross.
    private func updateColorButtons() {
        for player in 0..<2 {
            let selected = selectedColor(forPlayer: player)
            let taken = selectedColor(forPlayer: 1 - player)

            for (tankColor, button) in colorButtons[player] {
                let isSelected = tankColor == selected
                let isTaken = tankColor == taken

                button.alpha = isTaken ? 0.3 : 1.0
                if let circle = button.childNode(withName: "circle") as? SKShapeNode {
                    circle.strokeColor = isSelected ? .white : .gray
                    circle.lineWidth = isSelected ? 4 : 2
                }

                button.childNode(withName: "check")?.removeFromParent()
                if isSelected || isTaken {
                    let mark = SKLabelNode(text: isSelected ? "\u{2713}" : "\u{2715}")
                    mark.fontName = "Helvetica-Bold"
                    mark.fontSize = 22
                    mark.fontColor = .black
                    mark.verticalAlignmentMode = .center
                    mark.name = "check"
                    button.addChild(mark)
                }

                if let label = button.childNode(withName: "colorLabel") as? SKLabelNode {
                    label.fontColor = isSelected ? .white : .gray
                }
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
