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
        case gold       // Gzhel-only: 99 points, enemies get major upgrade
        case laser      // Only dropped by the alien: shots of light pass through walls
        case magic      // Very rare: protects from the enemies' bomb and freeze until the end of the round
        // Level-clear bonuses (appear when the last enemy dies)
        case strawberry // Player crossed 250 points this level: +50 points
        case banana     // Player crossed 500 points this level: +75 points
        case ball       // No bomb used this level: +90 points and faster start speed for the rest of the game

        /// Level-clear bonus items: only players can pick them up
        var isLevelBonus: Bool {
            self == .strawberry || self == .banana || self == .ball
        }
    }

    let type: PowerUpType
    /// Question mark dropped by a defeated boss: a random power-up, revealed when picked up
    let isMystery: Bool
    private var lifetime: Int
    private var blinkTimer: Int = 0

    /// Only players can take it (level-clear bonuses and the boss's question mark),
    /// and the level waits for it
    var isPlayersOnly: Bool { type.isLevelBonus || isMystery || type == .magic }

    init(position: CGPoint, type: PowerUpType? = nil, mystery: Bool = false) {
        self.type = type ?? PowerUp.randomType()
        self.isMystery = mystery
        // Level-clear bonuses and the question mark stay until the level ends
        self.lifetime = (self.type.isLevelBonus || mystery) ? Int.max : GameConstants.powerUpLifetime

        let size = CGSize(width: 28, height: 28)
        super.init(texture: nil, color: .clear, size: size)

        self.position = position
        self.zPosition = 8

        drawPowerUp()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawPowerUp() {
        removeAllChildren()

        if isMystery {
            drawMystery()
        } else if type == .gold {
            // Lode Runner style gold bar/ingot
            drawGoldBar()
        } else if type.isLevelBonus {
            drawLevelBonus()
        } else {
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
    }

    /// Draw Lode Runner style gold bar
    private func drawGoldBar() {
        // Gold bar trapezoid shape (like Lode Runner)
        let goldColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)
        let darkGold = SKColor(red: 0.85, green: 0.65, blue: 0.0, alpha: 1.0)
        let lightGold = SKColor(red: 1.0, green: 0.95, blue: 0.5, alpha: 1.0)

        // Main gold bar (trapezoid-ish rectangle)
        let barWidth: CGFloat = 24
        let barHeight: CGFloat = 16

        let bar = SKShapeNode(rectOf: CGSize(width: barWidth, height: barHeight), cornerRadius: 2)
        bar.fillColor = goldColor
        bar.strokeColor = darkGold
        bar.lineWidth = 2
        addChild(bar)

        // Shine/highlight on top
        let shine = SKShapeNode(rectOf: CGSize(width: barWidth - 6, height: 4))
        shine.fillColor = lightGold
        shine.strokeColor = .clear
        shine.position = CGPoint(x: 0, y: 4)
        addChild(shine)

        // Small "$" symbol
        let symbol = SKLabelNode(text: "$")
        symbol.fontName = "Helvetica-Bold"
        symbol.fontSize = 12
        symbol.fontColor = darkGold
        symbol.verticalAlignmentMode = .center
        symbol.position = CGPoint(x: 0, y: -1)
        addChild(symbol)

        // Add sparkle effect
        addSparkle()
    }

    /// Boss drop: purple box with a big pulsing question mark
    private func drawMystery() {
        let background = SKShapeNode(rectOf: size, cornerRadius: 4)
        background.fillColor = SKColor(red: 0.45, green: 0.1, blue: 0.75, alpha: 1.0)
        background.strokeColor = .white
        background.lineWidth = 2
        addChild(background)

        let mark = SKLabelNode(text: "?")
        mark.fontName = "Helvetica-Bold"
        mark.fontSize = 22
        mark.fontColor = .yellow
        mark.verticalAlignmentMode = .center
        addChild(mark)
        mark.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.4),
            SKAction.scale(to: 0.9, duration: 0.4)
        ])))
        background.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.run { background.strokeColor = .yellow },
            SKAction.wait(forDuration: 0.25),
            SKAction.run { background.strokeColor = .white },
            SKAction.wait(forDuration: 0.25)
        ])))
    }

    /// Fruit / soccer ball: no box, a soft glow and a gentle bounce
    private func drawLevelBonus() {
        let glowColor: SKColor
        let icon: String
        let iconSize: CGFloat
        switch type {
        case .strawberry: glowColor = .red; icon = "🍓"; iconSize = 16  // Small strawberry
        case .banana: glowColor = .yellow; icon = "🍌"; iconSize = 22
        default: glowColor = .white; icon = "⚽"; iconSize = 22
        }

        let glow = SKShapeNode(circleOfRadius: 14)
        glow.fillColor = glowColor.withAlphaComponent(0.25)
        glow.strokeColor = glowColor.withAlphaComponent(0.6)
        glow.lineWidth = 1.5
        addChild(glow)
        glow.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.2, duration: 0.5),
            SKAction.scale(to: 0.9, duration: 0.5)
        ])))

        let label = SKLabelNode(text: icon)
        label.fontSize = iconSize
        label.verticalAlignmentMode = .center
        addChild(label)
        let bounce = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 3, duration: 0.3),
            SKAction.moveBy(x: 0, y: -3, duration: 0.3)
        ])
        label.run(SKAction.repeatForever(bounce))
        if type == .ball {
            label.run(SKAction.repeatForever(SKAction.rotate(byAngle: -.pi * 2, duration: 1.2)))
        }
    }

    /// Add sparkle animation to gold
    private func addSparkle() {
        let sparkle = SKShapeNode(circleOfRadius: 3)
        sparkle.fillColor = .white
        sparkle.strokeColor = .clear
        sparkle.alpha = 0
        sparkle.position = CGPoint(x: 8, y: 5)
        sparkle.name = "sparkle"
        addChild(sparkle)

        // Sparkle animation
        let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
        let fadeOut = SKAction.fadeAlpha(to: 0.0, duration: 0.3)
        let wait = SKAction.wait(forDuration: 1.0)
        let moveToOther = SKAction.move(to: CGPoint(x: -6, y: -3), duration: 0)
        let sparkleSequence = SKAction.sequence([fadeIn, fadeOut, wait, moveToOther, fadeIn, fadeOut, wait, SKAction.move(to: CGPoint(x: 8, y: 5), duration: 0)])
        sparkle.run(SKAction.repeatForever(sparkleSequence))
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
        case .gold: return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Bright gold
        case .laser: return SKColor(red: 0.0, green: 0.85, blue: 0.85, alpha: 1.0) // Cyan
        case .magic: return SKColor(red: 0.55, green: 0.2, blue: 0.85, alpha: 1.0) // Violet
        case .strawberry: return .red
        case .banana: return .yellow
        case .ball: return .white
        }
    }

    var iconForType: String {
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
        case .gold: return "$"  // Lode Runner style
        case .laser: return "🔦"
        case .magic: return "🔮"
        case .strawberry: return "🍓"
        case .banana: return "🍌"
        case .ball: return "⚽"
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
        case .gold:
            // Handled by game scene (+99 points)
            break
        case .laser:
            tank.laserRounds = GameConstants.laserRoundsOnPickup
        case .magic:
            tank.hasMagic = true
        case .strawberry, .banana:
            // Handled by game scene (points only)
            break
        case .ball:
            tank.addBallSpeedBoost()
        }
    }

    static func randomType() -> PowerUpType {
        // Weighted random selection - some power-ups are rarer
        let rand = Double.random(in: 0...1)
        if rand < 0.14 { return .star }
        if rand < 0.27 { return .car }
        if rand < 0.37 { return .gun }
        if rand < 0.46 { return .shield }
        if rand < 0.55 { return .tank }
        if rand < 0.64 { return .freeze }
        if rand < 0.73 { return .bomb }
        if rand < 0.80 { return .ship }
        if rand < 0.87 { return .saw }
        if rand < 0.94 { return .shovel }
        return .machinegun
    }
}
