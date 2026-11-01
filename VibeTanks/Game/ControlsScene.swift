import SpriteKit
import UIKit

/// Options → Controls: keyboard keys for each player and the two-player touch layout.
/// Tap a key box, then press the new key (Escape cancels).
class ControlsScene: SKScene {

    /// Key box waiting for a key press: (player, action)
    private var listening: (player: Int, action: GameSettings.KeyAction)?
    private var keyBoxes: [String: SKNode] = [:]
    private var placementButtons: [SKNode] = []
    private var placementPreviews: [SKNode] = []
    private var messageLabel: SKLabelNode!

    // Keyboard table columns
    private var actionColumnX: CGFloat { size.width * 0.12 }
    private func keyColumnX(_ player: Int) -> CGFloat { size.width * (player == 0 ? 0.26 : 0.40) }
    private func rowY(_ index: Int) -> CGFloat { size.height * (0.64 - CGFloat(index) * 0.095) }

    // Touch section
    private var touchCenterX: CGFloat { size.width * 0.73 }
    private func touchRowY(_ player: Int) -> CGFloat { size.height * (player == 0 ? 0.58 : 0.36) }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    // MARK: - Layout

    private func setupUI() {
        let title = makeLabel("CONTROLS", size: 36, color: .yellow)
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.87)
        addChild(title)

        setupKeyboardSection()
        setupTouchSection()

        messageLabel = makeLabel("", size: 14, color: .gray)
        messageLabel.position = CGPoint(x: size.width * 0.27, y: size.height * 0.17)
        addChild(messageLabel)
        showDefaultMessage()

        let backButton = createButton(text: "BACK", position: CGPoint(x: size.width / 2 - 95, y: size.height * 0.08))
        backButton.name = "backButton"
        addChild(backButton)

        let resetButton = createButton(text: "RESET", position: CGPoint(x: size.width / 2 + 95, y: size.height * 0.08))
        resetButton.name = "resetButton"
        addChild(resetButton)
    }

    private func setupKeyboardSection() {
        let header = makeLabel("KEYBOARD", size: 22, color: .white)
        header.position = CGPoint(x: size.width * 0.27, y: size.height * 0.76)
        addChild(header)

        for player in 0..<2 {
            let label = makeLabel("\(player + 1)P", size: 18, color: Tank.colorForPlayer(player + 1))
            label.position = CGPoint(x: keyColumnX(player), y: size.height * 0.70)
            addChild(label)
        }

        for (index, action) in GameSettings.KeyAction.allCases.enumerated() {
            let actionLabel = makeLabel(action.displayName, size: 15, color: .lightGray)
            actionLabel.horizontalAlignmentMode = .left
            actionLabel.position = CGPoint(x: actionColumnX - 30, y: rowY(index))
            addChild(actionLabel)

            for player in 0..<2 {
                let box = createKeyBox()
                box.position = CGPoint(x: keyColumnX(player), y: rowY(index))
                box.name = keyBoxName(player: player, action: action)
                addChild(box)
                keyBoxes[box.name!] = box
            }
        }
        refreshKeyBoxes()
    }

    private func setupTouchSection() {
        let header = makeLabel("TOUCH (2 PLAYERS)", size: 22, color: .white)
        header.position = CGPoint(x: touchCenterX, y: size.height * 0.76)
        addChild(header)

        for player in 0..<2 {
            let y = touchRowY(player)

            let label = makeLabel("\(player + 1)P", size: 18, color: Tank.colorForPlayer(player + 1))
            label.position = CGPoint(x: touchCenterX - 150, y: y)
            addChild(label)

            let button = createButton(text: "", position: CGPoint(x: touchCenterX - 15, y: y), width: 170, height: 38)
            button.name = "placement\(player)"
            addChild(button)
            placementButtons.append(button)

            let preview = SKNode()
            preview.position = CGPoint(x: touchCenterX + 130, y: y)
            addChild(preview)
            placementPreviews.append(preview)
        }

        let hint = makeLabel("Tap to change where the fire button sits", size: 13, color: .gray)
        hint.position = CGPoint(x: touchCenterX, y: size.height * 0.20)
        addChild(hint)

        refreshPlacements()
    }

    // MARK: - Refresh

    private func keyBoxName(player: Int, action: GameSettings.KeyAction) -> String {
        return "key\(player)_\(action.rawValue)"
    }

    private func refreshKeyBoxes() {
        for player in 0..<2 {
            for action in GameSettings.KeyAction.allCases {
                guard let box = keyBoxes[keyBoxName(player: player, action: action)] else { continue }
                let isListening = listening?.player == player && listening?.action == action
                if let bg = box.childNode(withName: "bg") as? SKShapeNode {
                    bg.strokeColor = isListening ? .yellow : .gray
                    bg.fillColor = isListening ? SKColor(red: 0.35, green: 0.3, blue: 0.0, alpha: 1) : SKColor(white: 0.18, alpha: 1)
                }
                if let label = box.childNode(withName: "label") as? SKLabelNode {
                    let key = GameSettings.shared.key(for: action, player: player)
                    label.text = isListening ? "?" : GameSettings.keyName(key)
                }
            }
        }
    }

    private func refreshPlacements() {
        for player in 0..<2 {
            let placement = GameSettings.shared.firePlacement(player: player)
            if let label = placementButtons[player].childNode(withName: "label") as? SKLabelNode {
                label.text = placement.displayName
            }
            drawPreview(placementPreviews[player], placement: placement, player: player)
        }
    }

    /// Tiny picture of that player's screen corner: joystick (gray) and fire button (red)
    private func drawPreview(_ node: SKNode, placement: GameSettings.FirePlacement, player: Int) {
        node.removeAllChildren()
        let width: CGFloat = 64, height: CGFloat = 56
        let frame = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 6)
        frame.strokeColor = .darkGray
        frame.fillColor = SKColor(white: 0.08, alpha: 1)
        node.addChild(frame)

        // Player 1 holds the left edge, player 2 the right edge
        let edgeSign: CGFloat = player == 0 ? -1 : 1
        let edgeX = edgeSign * (width / 2 - 14)
        let innerX = edgeX - edgeSign * 26
        let bottomY = -height / 2 + 14
        let upperY = bottomY + 26

        let joystick: CGPoint
        let fire: CGPoint
        switch placement {
        case .above: joystick = CGPoint(x: edgeX, y: bottomY); fire = CGPoint(x: edgeX, y: upperY)
        case .below: joystick = CGPoint(x: edgeX, y: upperY); fire = CGPoint(x: edgeX, y: bottomY)
        case .inside: joystick = CGPoint(x: edgeX, y: bottomY); fire = CGPoint(x: innerX, y: bottomY)
        case .outside: joystick = CGPoint(x: innerX, y: bottomY); fire = CGPoint(x: edgeX, y: bottomY)
        }

        let stick = SKShapeNode(circleOfRadius: 10)
        stick.fillColor = SKColor.gray.withAlphaComponent(0.5)
        stick.strokeColor = Tank.colorForPlayer(player + 1)
        stick.lineWidth = 2
        stick.position = joystick
        node.addChild(stick)

        let fireButton = SKShapeNode(circleOfRadius: 8)
        fireButton.fillColor = SKColor.red.withAlphaComponent(0.7)
        fireButton.strokeColor = .red
        fireButton.position = fire
        node.addChild(fireButton)
    }

    private func showDefaultMessage() {
        messageLabel.fontColor = .gray
        messageLabel.text = "Tap a key box, then press the new key"
    }

    private func showMessage(_ text: String, color: SKColor) {
        messageLabel.fontColor = color
        messageLabel.text = text
    }

    // MARK: - Input

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        handleClick(at: touch.location(in: self))
    }

    private func handleClick(at location: CGPoint) {
        for node in nodes(at: location) {
            let name = targetName(of: node)

            if name == "backButton" {
                goBack()
                return
            }
            if name == "resetButton" {
                GameSettings.shared.resetKeys()
                for player in 0..<2 {
                    GameSettings.shared.setFirePlacement(.above, player: player)
                }
                listening = nil
                refreshKeyBoxes()
                refreshPlacements()
                showMessage("Default controls restored", color: .green)
                return
            }
            for player in 0..<2 where name == "placement\(player)" {
                let next = GameSettings.shared.firePlacement(player: player).next
                GameSettings.shared.setFirePlacement(next, player: player)
                refreshPlacements()
                return
            }
            for player in 0..<2 {
                for action in GameSettings.KeyAction.allCases where name == keyBoxName(player: player, action: action) {
                    listening = (player, action)
                    refreshKeyBoxes()
                    showMessage("\(player + 1)P \(action.displayName): press a key (Esc cancels)", color: .yellow)
                    return
                }
            }
        }

        // Tap anywhere else cancels a key change
        if listening != nil {
            listening = nil
            refreshKeyBoxes()
            showDefaultMessage()
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard let key = presses.first?.key?.keyCode else { return }

        guard let target = listening else {
            if key == .keyboardEscape { goBack() }
            return
        }

        if key == .keyboardEscape {
            listening = nil
            refreshKeyBoxes()
            showDefaultMessage()
            return
        }
        if GameSettings.reservedKeys.contains(key) {
            showMessage("P and Esc pause the game, pick another key", color: .orange)
            return
        }

        GameSettings.shared.setKey(key, for: target.action, player: target.player)
        listening = nil
        refreshKeyBoxes()
        showMessage("\(target.player + 1)P \(target.action.displayName) = \(GameSettings.keyName(key))", color: .green)
    }

    // MARK: - Helpers

    /// Name of the tapped control: the node's own name, or its parent's for the inner "bg" / "label"
    private func targetName(of node: SKNode) -> String {
        var current: SKNode? = node
        while let n = current {
            if let name = n.name, name != "bg", name != "label" {
                return name
            }
            current = n.parent
        }
        return ""
    }

    private func makeLabel(_ text: String, size: CGFloat, color: SKColor) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = size
        label.fontColor = color
        label.verticalAlignmentMode = .center
        return label
    }

    private func createKeyBox() -> SKNode {
        let container = SKNode()
        let bg = SKShapeNode(rectOf: CGSize(width: 96, height: 30), cornerRadius: 6)
        bg.lineWidth = 2
        bg.name = "bg"
        container.addChild(bg)

        let label = makeLabel("", size: 15, color: .white)
        label.name = "label"
        container.addChild(label)
        return container
    }

    private func createButton(text: String, position: CGPoint, width: CGFloat = 160, height: CGFloat = 45) -> SKNode {
        let container = SKNode()
        container.position = position

        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        background.name = "bg"
        container.addChild(background)

        let label = makeLabel(text, size: height < 45 ? 17 : 22, color: .white)
        label.name = "label"
        container.addChild(label)

        return container
    }

    private func goBack() {
        let options = OptionsScene(size: size)
        options.scaleMode = scaleMode
        view?.presentScene(options, transition: .fade(withDuration: 0.3))
    }
}
