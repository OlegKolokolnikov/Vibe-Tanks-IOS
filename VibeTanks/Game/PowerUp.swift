import SpriteKit

/// Power-up items that can be collected
class PowerUp: SKSpriteNode {

    enum PowerUpType: CaseIterable {
        case shield      // Temporary invincibility
        case life        // Extra life
        case speedUp     // Faster movement
        case rapidFire   // Faster shooting
        case bomb        // Destroy all enemies
        case freeze      // Freeze all enemies
    }

    let type: PowerUpType
    private var lifetime: Int = 600 // 10 seconds at 60fps
    private var blinkTimer: Int = 0

    init(position: CGPoint, type: PowerUpType) {
        self.type = type

        let size = CGSize(width: 28, height: 28)
        super.init(texture: nil, color: .clear, size: size)

        self.position = position
        self.zPosition = 8

        drawPowerUp()

        // Physics
        physicsBody = SKPhysicsBody(rectangleOf: size)
        physicsBody?.isDynamic = false
        physicsBody?.categoryBitMask = PhysicsCategory.powerUp
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawPowerUp() {
        removeAllChildren()

        let background = SKShapeNode(rectOf: size, cornerRadius: 4)
        background.fillColor = colorForType
        background.strokeColor = .white
        background.lineWidth = 2
        addChild(background)

        // Add icon
        let icon = SKLabelNode(text: iconForType)
        icon.fontSize = 18
        icon.verticalAlignmentMode = .center
        addChild(icon)
    }

    private var colorForType: SKColor {
        switch type {
        case .shield: return SKColor(hex: "#00BFFF") // Deep sky blue
        case .life: return SKColor(hex: "#FF69B4")   // Hot pink
        case .speedUp: return SKColor(hex: "#32CD32") // Lime green
        case .rapidFire: return SKColor(hex: "#FF4500") // Orange red
        case .bomb: return SKColor(hex: "#8B0000")    // Dark red
        case .freeze: return SKColor(hex: "#00CED1")  // Dark turquoise
        }
    }

    private var iconForType: String {
        switch type {
        case .shield: return "🛡"
        case .life: return "❤️"
        case .speedUp: return "⚡"
        case .rapidFire: return "🔫"
        case .bomb: return "💣"
        case .freeze: return "❄️"
        }
    }

    func update() -> Bool {
        lifetime -= 1

        // Blink when about to expire
        if lifetime < 180 { // Last 3 seconds
            blinkTimer += 1
            isHidden = (blinkTimer / 10) % 2 == 0
        }

        return lifetime <= 0
    }

    func apply(to tank: Tank) {
        switch type {
        case .shield:
            tank.hasShield = true
            tank.shieldTimer = 600 // 10 seconds
        case .life:
            tank.lives += 1
        case .speedUp:
            tank.speedMultiplier = 1.5
            // Would need timer to reset
        case .rapidFire:
            tank.hasRapidFire = true
            // Would need timer to reset
        case .bomb:
            // Handled by game scene
            break
        case .freeze:
            // Handled by game scene
            break
        }
    }

    static func randomType() -> PowerUpType {
        return PowerUpType.allCases.randomElement()!
    }
}
