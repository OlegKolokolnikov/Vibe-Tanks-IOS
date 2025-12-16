import SpriteKit

/// Virtual joystick and fire button for touch controls
class TouchController: SKNode {

    // Joystick
    private let joystickBase: SKShapeNode
    private let joystickKnob: SKShapeNode
    private let joystickRadius: CGFloat = 60
    private let knobRadius: CGFloat = 25

    // Fire button
    private let fireButton: SKShapeNode
    private let fireButtonRadius: CGFloat = 40

    // State
    private(set) var currentDirection: Direction?
    private(set) var isFiring: Bool = false
    private var joystickTouch: UITouch?
    private var fireTouch: UITouch?

    // Positions (set based on screen size)
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
        fireLabel.fontSize = 14
        fireLabel.fontColor = .white
        fireLabel.verticalAlignmentMode = .center
        fireButton.addChild(fireLabel)

        super.init()

        addChild(joystickBase)
        addChild(joystickKnob)
        addChild(fireButton)

        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    func setupForScreen(size: CGSize) {
        let margin: CGFloat = 100
        joystickPosition = CGPoint(x: margin, y: margin)
        fireButtonPosition = CGPoint(x: size.width - margin, y: margin)
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let location = touch.location(in: self)

            // Check if touch is on joystick
            if joystickTouch == nil && location.distance(to: joystickPosition) < joystickRadius * 1.5 {
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
