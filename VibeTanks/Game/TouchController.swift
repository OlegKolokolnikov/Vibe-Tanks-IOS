import SpriteKit

/// Virtual joystick and fire button for touch controls
class TouchController: SKNode {

    // Joystick
    private let joystickBase: SKShapeNode
    private let joystickKnob: SKShapeNode
    private let joystickRadius: CGFloat = 80
    private let knobRadius: CGFloat = 35

    // Fire button
    private let fireButton: SKShapeNode
    private let fireButtonRadius: CGFloat = 65

    // Pause button
    private let pauseButton: SKShapeNode
    private let pauseButtonSize: CGFloat = 50

    // State
    private(set) var currentDirection: Direction?
    private(set) var isFiring: Bool = false
    private(set) var pausePressed: Bool = false
    private var joystickTouch: UITouch?
    private var fireTouch: UITouch?

    // Positions (set based on screen size - coordinates relative to camera center)
    var joystickPosition: CGPoint = .zero {
        didSet {
            joystickBase.position = joystickPosition
            joystickKnob.position = joystickPosition
        }
    }

    var fireButtonPosition: CGPoint = .zero {
        didSet {
            fireButton.position = fireButtonPosition
        }
    }

    var pauseButtonPosition: CGPoint = .zero {
        didSet {
            pauseButton.position = pauseButtonPosition
        }
    }

    override init() {
        // Create joystick base
        joystickBase = SKShapeNode(circleOfRadius: joystickRadius)
        joystickBase.fillColor = SKColor.gray.withAlphaComponent(0.3)
        joystickBase.strokeColor = SKColor.white.withAlphaComponent(0.5)
        joystickBase.lineWidth = 2
        joystickBase.zPosition = 100

        // Create joystick knob
        joystickKnob = SKShapeNode(circleOfRadius: knobRadius)
        joystickKnob.fillColor = SKColor.white.withAlphaComponent(0.6)
        joystickKnob.strokeColor = SKColor.white
        joystickKnob.lineWidth = 2
        joystickKnob.zPosition = 101

        // Create fire button
        fireButton = SKShapeNode(circleOfRadius: fireButtonRadius)
        fireButton.fillColor = SKColor.red.withAlphaComponent(0.5)
        fireButton.strokeColor = SKColor.red
        fireButton.lineWidth = 3
        fireButton.zPosition = 100

        // Add "FIRE" label
        let fireLabel = SKLabelNode(text: "FIRE")
        fireLabel.fontName = "Helvetica-Bold"
        fireLabel.fontSize = 20
        fireLabel.fontColor = .white
        fireLabel.verticalAlignmentMode = .center
        fireButton.addChild(fireLabel)

        // Create pause button
        pauseButton = SKShapeNode(rectOf: CGSize(width: pauseButtonSize, height: pauseButtonSize), cornerRadius: 8)
        pauseButton.fillColor = SKColor.gray.withAlphaComponent(0.4)
        pauseButton.strokeColor = SKColor.white.withAlphaComponent(0.6)
        pauseButton.lineWidth = 2
        pauseButton.zPosition = 250  // Above pause overlay

        // Add pause icon (two vertical bars)
        let barWidth: CGFloat = 8
        let barHeight: CGFloat = 24
        let barSpacing: CGFloat = 10

        let leftBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight))
        leftBar.fillColor = .white
        leftBar.strokeColor = .clear
        leftBar.position = CGPoint(x: -barSpacing/2, y: 0)
        pauseButton.addChild(leftBar)

        let rightBar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight))
        rightBar.fillColor = .white
        rightBar.strokeColor = .clear
        rightBar.position = CGPoint(x: barSpacing/2, y: 0)
        pauseButton.addChild(rightBar)

        super.init()

        addChild(joystickBase)
        addChild(joystickKnob)
        addChild(fireButton)
        addChild(pauseButton)

        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    func setupForScreen(size: CGSize) {
        // Coordinates are relative to camera center (0,0)
        // Use larger margins to keep controls well inside screen
        let sideMargin: CGFloat = 130
        let bottomMargin: CGFloat = 100
        let topMargin: CGFloat = 80

        let leftX = -size.width / 2 + sideMargin
        let rightX = size.width / 2 - sideMargin
        let bottomY = -size.height / 2 + bottomMargin

        // Check if controls are swapped (fire on left instead of right)
        if GameSettings.shared.controlsSwapped {
            // Fire on LEFT, joystick on RIGHT
            fireButtonPosition = CGPoint(x: leftX, y: bottomY)
            joystickPosition = CGPoint(x: rightX, y: bottomY)
        } else {
            // Default: joystick on LEFT, fire on RIGHT
            joystickPosition = CGPoint(x: leftX, y: bottomY)
            fireButtonPosition = CGPoint(x: rightX, y: bottomY)
        }

        pauseButtonPosition = CGPoint(x: rightX, y: size.height / 2 - topMargin)
    }

    func setControlsScale(_ scale: CGFloat) {
        joystickBase.setScale(scale)
        joystickKnob.setScale(scale)
        fireButton.setScale(scale)
        pauseButton.setScale(scale)
    }

    func setGzhelMode(_ isGzhel: Bool) {
        let barColor: SKColor = isGzhel ? .blue : .white
        for child in pauseButton.children {
            if let bar = child as? SKShapeNode {
                bar.fillColor = barColor
            }
        }
        pauseButton.strokeColor = isGzhel ? SKColor.blue.withAlphaComponent(0.6) : SKColor.white.withAlphaComponent(0.6)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)

            // Check if touch is on pause button
            if location.distance(to: pauseButtonPosition) < pauseButtonSize {
                pausePressed = true
                pauseButton.fillColor = SKColor.white.withAlphaComponent(0.6)
            }
            // Check if touch is on joystick
            else if joystickTouch == nil && location.distance(to: joystickPosition) < joystickRadius * 1.5 {
                joystickTouch = touch
                updateJoystick(touch: touch)
            }
            // Check if touch is on fire button
            else if fireTouch == nil && location.distance(to: fireButtonPosition) < fireButtonRadius * 1.5 {
                fireTouch = touch
                isFiring = true
                fireButton.fillColor = SKColor.red.withAlphaComponent(0.8)
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                updateJoystick(touch: touch)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            if touch == joystickTouch {
                joystickTouch = nil
                resetJoystick()
            }
            if touch == fireTouch {
                fireTouch = nil
                isFiring = false
                fireButton.fillColor = SKColor.red.withAlphaComponent(0.5)
            }
        }
        // Reset pause button visual
        pauseButton.fillColor = SKColor.gray.withAlphaComponent(0.4)
    }

    func resetPausePressed() {
        pausePressed = false
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        touchesEnded(touches, with: event)
    }

    // MARK: - Joystick Logic

    private func updateJoystick(touch: UITouch) {
        let location = touch.location(in: self)
        let dx = location.x - joystickPosition.x
        let dy = location.y - joystickPosition.y
        let distance = sqrt(dx * dx + dy * dy)

        // Clamp knob to joystick radius
        let clampedDistance = min(distance, joystickRadius)
        let angle = atan2(dy, dx)

        joystickKnob.position = CGPoint(
            x: joystickPosition.x + cos(angle) * clampedDistance,
            y: joystickPosition.y + sin(angle) * clampedDistance
        )

        // Determine direction (4-way, snapped to nearest)
        if distance > 20 { // Dead zone
            let normalizedAngle = angle * 180 / .pi

            if normalizedAngle >= -45 && normalizedAngle < 45 {
                currentDirection = .right
            } else if normalizedAngle >= 45 && normalizedAngle < 135 {
                currentDirection = .up
            } else if normalizedAngle >= -135 && normalizedAngle < -45 {
                currentDirection = .down
            } else {
                currentDirection = .left
            }
        } else {
            currentDirection = nil
        }
    }

    private func resetJoystick() {
        joystickKnob.position = joystickPosition
        currentDirection = nil
    }
}

// MARK: - CGPoint Extension

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        let dx = x - point.x
        let dy = y - point.y
        return sqrt(dx * dx + dy * dy)
    }
}
