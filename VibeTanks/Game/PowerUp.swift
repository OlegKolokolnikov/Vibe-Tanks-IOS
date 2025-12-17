import SpriteKit

/// Power-up items that can be collected (matching original Vibe-Tanks)
class PowerUp: SKSpriteNode {

    enum PowerUpType: CaseIterable {
        case gun        // Ability to break steel walls
        case star       // Shooting faster (stackable)
        case car        // Tank becomes faster (stackable)
        case ship       // Tank can swim through water
        case shovel     // Base surrounded by steel for 1 minute
        case saw        // Able to destroy forest/trees
        case tank       // Extra life
        case shield     // Shield for 1 minute
        case machinegun // Multiple bullets
        case freeze     // Freeze enemies for 10 seconds
        case bomb       // Explode all enemies
    }

    let type: PowerUpType
    private var lifetime: Int
    private var blinkTimer: Int = 0

    init(position: CGPoint, type: PowerUpType? = nil) {
        self.type = type ?? PowerUp.randomType()
        self.lifetime = GameConstants.powerUpLifetime

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
        icon.fontSize = 16
        icon.verticalAlignmentMode = .center
        addChild(icon)
    }

    private var colorForType: SKColor {
        switch type {
        case .gun: return SKColor(red: 0.8, green: 0.4, blue: 0.0, alpha: 1.0) // Orange-brown
        case .star: return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold
        case .car: return SKColor(red: 0.0, green: 0.8, blue: 0.0, alpha: 1.0) // Green
        case .ship: return SKColor(red: 0.0, green: 0.5, blue: 1.0, alpha: 1.0) // Blue
        case .shovel: return SKColor(red: 0.6, green: 0.4, blue: 0.2, alpha: 1.0) // Brown
        case .saw: return SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0) // Gray
        case .tank: return SKColor(red: 1.0, green: 0.4, blue: 0.7, alpha: 1.0) // Pink
        case .shield: return SKColor(red: 0.0, green: 0.75, blue: 1.0, alpha: 1.0) // Cyan
        case .machinegun: return SKColor(red: 0.8, green: 0.0, blue: 0.0, alpha: 1.0) // Red
        case .freeze: return SKColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 1.0) // Light blue
        case .bomb: return SKColor(red: 0.5, green: 0.0, blue: 0.0, alpha: 1.0) // Dark red
        }
    }

    private var iconForType: String {
        switch type {
        case .gun: return "🔫"
        case .star: return "⭐"
        case .car: return "🚗"
        case .ship: return "🚢"
        case .shovel: return "⛏️"
        case .saw: return "🪚"
        case .tank: return "❤️"
        case .shield: return "🛡️"
        case .machinegun: return "💥"
        case .freeze: return "❄️"
        case .bomb: return "💣"
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
        case .gun:
            tank.bulletPower = 2 // Can break steel
        case .star:
            tank.starCount = min(tank.starCount + 1, 3) // Max 3 stars
        case .car:
            tank.speedMultiplier = min(tank.speedMultiplier + 0.3, 2.5) // Max 2.5x
        case .ship:
            tank.activateShip()
        case .shovel:
            // Handled by game scene (affects map, not tank)
            break
        case .saw:
            tank.canDestroyTrees = true
        case .tank:
            tank.lives += 1
        case .shield:
            tank.activateShield(duration: GameConstants.shieldDuration)
        case .machinegun:
            tank.machinegunCount = min(tank.machinegunCount + 1, 3) // Max 4 total bullets
        case .freeze:
            // Handled by game scene
            break
        case .bomb:
            // Handled by game scene
            break
        }
    }

    static func randomType() -> PowerUpType {
        // Weighted random selection - some power-ups are rarer
        let rand = Double.random(in: 0...1)
        if rand < 0.15 { return .star }
        if rand < 0.30 { return .car }
        if rand < 0.40 { return .gun }
        if rand < 0.50 { return .shield }
        if rand < 0.60 { return .tank }
        if rand < 0.70 { return .freeze }
        if rand < 0.80 { return .bomb }
        if rand < 0.87 { return .ship }
        if rand < 0.94 { return .saw }
        return .machinegun
    }
}
