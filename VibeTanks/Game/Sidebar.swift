import SpriteKit

/// Sidebar like in original Battle City.
/// Shows remaining enemies, player lives, and level number with flag.
class Sidebar: SKNode {

    // Layout constants
    private static let sidebarWidth: CGFloat = GameConstants.sidebarWidth
    private static let backgroundColor = SKColor(red: 0.39, green: 0.39, blue: 0.39, alpha: 1.0)
    private static let enemyIconColor = SKColor.black
    private static let playerIconColor = SKColor(red: 1.0, green: 0.7, blue: 0.0, alpha: 1.0)
    private static let textColor = SKColor.black
    private static let flagPoleColor = SKColor.black

    // Icon settings
    private static let enemyIconSize: CGFloat = 18
    private static let enemyIconSpacing: CGFloat = 6
    private static let enemyColumns = 2
    private static let sectionPadding: CGFloat = 10

    // Fixed Y positions (from top)
    private static let enemySectionY: CGFloat = 10
    private static let playerSectionY: CGFloat = 550
    private static let flagSectionY: CGFloat = 710

    private let sidebarHeight: CGFloat
    private var enemyIconsNode: SKNode!
    private var playerInfoNode: SKNode!
    private var flagNode: SKNode!
    private var levelLabel: SKLabelNode!

    // Cache previous values to avoid unnecessary updates
    private var lastEnemyCount: Int = -1
    private var lastPlayerLives: Int = -1
    private var lastLevel: Int = -1

    init(height: CGFloat) {
        self.sidebarHeight = height
        super.init()

        setupBackground()
        setupEnemyIcons()
        setupPlayerInfo()
        setupFlag()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupBackground() {
        let background = SKShapeNode(rectOf: CGSize(width: Sidebar.sidebarWidth, height: sidebarHeight))
        background.fillColor = Sidebar.backgroundColor
        background.strokeColor = .clear
        background.position = CGPoint(x: Sidebar.sidebarWidth / 2, y: sidebarHeight / 2)
        addChild(background)
    }

    private func setupEnemyIcons() {
        enemyIconsNode = SKNode()
        enemyIconsNode.position = CGPoint(x: Sidebar.sectionPadding, y: sidebarHeight - Sidebar.enemySectionY)
        addChild(enemyIconsNode)
    }

    private func setupPlayerInfo() {
        playerInfoNode = SKNode()
        playerInfoNode.position = CGPoint(x: Sidebar.sectionPadding, y: sidebarHeight - Sidebar.playerSectionY)
        addChild(playerInfoNode)
    }

    private func setupFlag() {
        flagNode = SKNode()
        flagNode.position = CGPoint(x: Sidebar.sectionPadding, y: sidebarHeight - Sidebar.flagSectionY)
        addChild(flagNode)

        // Flag pole
        let pole = SKShapeNode(rectOf: CGSize(width: 3, height: 40))
        pole.fillColor = Sidebar.flagPoleColor
        pole.strokeColor = .clear
        pole.position = CGPoint(x: 11.5, y: -20)
        flagNode.addChild(pole)

        // Level label under flag
        levelLabel = SKLabelNode(text: "1")
        levelLabel.fontName = "Helvetica-Bold"
        levelLabel.fontSize = 20
        levelLabel.fontColor = Sidebar.textColor
        levelLabel.horizontalAlignmentMode = .left
        levelLabel.position = CGPoint(x: 5, y: -65)
        flagNode.addChild(levelLabel)
    }

    /// Update the sidebar display (only when values change to avoid recreating nodes every frame)
    func update(remainingEnemies: Int, playerLives: Int, level: Int) {
        if remainingEnemies != lastEnemyCount {
            lastEnemyCount = remainingEnemies
            updateEnemyIcons(count: remainingEnemies)
        }
        if playerLives != lastPlayerLives {
            lastPlayerLives = playerLives
            updatePlayerInfo(lives: playerLives)
        }
        if level != lastLevel {
            lastLevel = level
            updateFlag(level: level)
        }
    }

    private func updateEnemyIcons(count: Int) {
        enemyIconsNode.removeAllChildren()

        for i in 0..<count {
            let col = i % Sidebar.enemyColumns
            let row = i / Sidebar.enemyColumns

            let x = CGFloat(col) * (Sidebar.enemyIconSize + Sidebar.enemyIconSpacing)
            let y = -CGFloat(row) * (Sidebar.enemyIconSize + Sidebar.enemyIconSpacing)

            let icon = createEnemyIcon(size: Sidebar.enemyIconSize)
            icon.position = CGPoint(x: x + Sidebar.enemyIconSize / 2, y: y - Sidebar.enemyIconSize / 2)
            enemyIconsNode.addChild(icon)
        }
    }

    private func createEnemyIcon(size: CGFloat) -> SKNode {
        let container = SKNode()

        // Tank body
        let bodyWidth = size * 0.7
        let bodyHeight = size * 0.6
        let body = SKShapeNode(rectOf: CGSize(width: bodyWidth, height: bodyHeight))
        body.fillColor = Sidebar.enemyIconColor
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: -size * 0.1)
        container.addChild(body)

        // Left track
        let trackWidth = size * 0.2
        let trackHeight = size * 0.7
        let leftTrack = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight))
        leftTrack.fillColor = Sidebar.enemyIconColor
        leftTrack.strokeColor = .clear
        leftTrack.position = CGPoint(x: -size * 0.35, y: -size * 0.05)
        container.addChild(leftTrack)

        // Right track
        let rightTrack = SKShapeNode(rectOf: CGSize(width: trackWidth, height: trackHeight))
        rightTrack.fillColor = Sidebar.enemyIconColor
        rightTrack.strokeColor = .clear
        rightTrack.position = CGPoint(x: size * 0.35, y: -size * 0.05)
        container.addChild(rightTrack)

        // Barrel
        let barrelWidth = size * 0.2
        let barrelHeight = size * 0.4
        let barrel = SKShapeNode(rectOf: CGSize(width: barrelWidth, height: barrelHeight))
        barrel.fillColor = Sidebar.enemyIconColor
        barrel.strokeColor = .clear
        barrel.position = CGPoint(x: 0, y: size * 0.3)
        container.addChild(barrel)

        return container
    }

    private func updatePlayerInfo(lives: Int) {
        playerInfoNode.removeAllChildren()

        // "IP" label (Player 1)
        let ipLabel = SKLabelNode(text: "IP")
        ipLabel.fontName = "Helvetica-Bold"
        ipLabel.fontSize = 12
        ipLabel.fontColor = Sidebar.playerIconColor
        ipLabel.horizontalAlignmentMode = .left
        ipLabel.position = CGPoint(x: 0, y: 0)
        playerInfoNode.addChild(ipLabel)

        // Small player tank icon
        let tankIcon = createPlayerTankIcon(size: 20)
        tankIcon.position = CGPoint(x: 10, y: -25)
        playerInfoNode.addChild(tankIcon)

        // Lives count (show lives - 1 like original)
        let displayLives = max(0, lives - 1)
        let livesLabel = SKLabelNode(text: "\(displayLives)")
        livesLabel.fontName = "Helvetica-Bold"
        livesLabel.fontSize = 14
        livesLabel.fontColor = Sidebar.textColor
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.position = CGPoint(x: Sidebar.sidebarWidth - Sidebar.sectionPadding * 2, y: -18)
        playerInfoNode.addChild(livesLabel)
    }

    private func createPlayerTankIcon(size: CGFloat) -> SKNode {
        let container = SKNode()
        let tankColor = SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0) // Gold

        // Body
        let bodyW = size * 0.6
        let bodyH = size * 0.5
        let body = SKShapeNode(rectOf: CGSize(width: bodyW, height: bodyH))
        body.fillColor = tankColor
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: -size * 0.1)
        container.addChild(body)

        // Tracks
        let trackW = size * 0.15
        let trackH = size * 0.6
        let leftTrack = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH))
        leftTrack.fillColor = tankColor
        leftTrack.strokeColor = .clear
        leftTrack.position = CGPoint(x: -size * 0.35, y: 0)
        container.addChild(leftTrack)

        let rightTrack = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH))
        rightTrack.fillColor = tankColor
        rightTrack.strokeColor = .clear
        rightTrack.position = CGPoint(x: size * 0.35, y: 0)
        container.addChild(rightTrack)

        // Barrel
        let barrelW = size * 0.15
        let barrelH = size * 0.45
        let barrel = SKShapeNode(rectOf: CGSize(width: barrelW, height: barrelH))
        barrel.fillColor = tankColor
        barrel.strokeColor = .clear
        barrel.position = CGPoint(x: 0, y: size * 0.3)
        container.addChild(barrel)

        return container
    }

    private func updateFlag(level: Int) {
        // Remove old flag (but keep pole and level label)
        flagNode.children.filter { $0.name == "flagShape" }.forEach { $0.removeFromParent() }

        // Generate flag colors based on level
        let colorCount: Int
        if level % 100 == 0 && level > 0 {
            colorCount = 3
        } else if level % 10 == 0 && level > 0 {
            colorCount = 2
        } else {
            colorCount = 1
        }

        let flagColors = generateFlagColors(level: level, count: colorCount)

        // Draw flag shape (triangular pennant)
        let flagShape = createFlagShape(colors: flagColors, width: 17, height: 18)
        flagShape.position = CGPoint(x: 13, y: -3)
        flagShape.name = "flagShape"
        flagNode.addChild(flagShape)

        // Update level label
        levelLabel.text = "\(level)"
    }

    private func generateFlagColors(level: Int, count: Int) -> [SKColor] {
        // Seed random with level for consistency
        srand48(level * 12345)

        var colors: [SKColor] = []
        for _ in 0..<count {
            let hue = CGFloat(drand48())
            let saturation = 0.7 + CGFloat(drand48()) * 0.3
            let brightness = 0.7 + CGFloat(drand48()) * 0.3
            colors.append(SKColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0))
        }
        return colors
    }

    private func createFlagShape(colors: [SKColor], width: CGFloat, height: CGFloat) -> SKNode {
        let container = SKNode()

        let stripeCount = colors.count
        let stripeHeight = height / CGFloat(stripeCount)

        for i in 0..<stripeCount {
            // Create triangular stripe
            let stripe = SKShapeNode()
            let path = CGMutablePath()

            let stripeY = -CGFloat(i) * stripeHeight
            let nextStripeY = -CGFloat(i + 1) * stripeHeight

            // Calculate right edge X based on Y position (triangular flag)
            let rightTopX = width * (1 - CGFloat(i) / CGFloat(stripeCount))
            let rightBottomX = width * (1 - CGFloat(i + 1) / CGFloat(stripeCount))

            path.move(to: CGPoint(x: 0, y: stripeY))
            path.addLine(to: CGPoint(x: rightTopX, y: stripeY))
            path.addLine(to: CGPoint(x: rightBottomX, y: nextStripeY))
            path.addLine(to: CGPoint(x: 0, y: nextStripeY))
            path.closeSubpath()

            stripe.path = path
            stripe.fillColor = colors[i]
            stripe.strokeColor = .clear
            container.addChild(stripe)
        }

        return container
    }
}
