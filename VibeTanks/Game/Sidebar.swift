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

    // Cached enemy icon texture (pre-rendered once)
    private static var enemyIconTexture: SKTexture?

    /// Get or create cached enemy icon texture
    private static func getEnemyIconTexture(size: CGFloat) -> SKTexture {
        if let cached = enemyIconTexture {
            return cached
        }

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.black.cgColor)

            let center = size / 2

            // Tank body
            let bodyWidth = size * 0.7
            let bodyHeight = size * 0.6
            ctx.fill(CGRect(
                x: center - bodyWidth / 2,
                y: center - bodyHeight / 2 + size * 0.1,
                width: bodyWidth,
                height: bodyHeight
            ))

            // Left track
            let trackWidth = size * 0.2
            let trackHeight = size * 0.7
            ctx.fill(CGRect(
                x: center - size * 0.35 - trackWidth / 2,
                y: center - trackHeight / 2 + size * 0.05,
                width: trackWidth,
                height: trackHeight
            ))

            // Right track
            ctx.fill(CGRect(
                x: center + size * 0.35 - trackWidth / 2,
                y: center - trackHeight / 2 + size * 0.05,
                width: trackWidth,
                height: trackHeight
            ))

            // Barrel
            let barrelWidth = size * 0.2
            let barrelHeight = size * 0.4
            ctx.fill(CGRect(
                x: center - barrelWidth / 2,
                y: center - size * 0.3 - barrelHeight / 2,
                width: barrelWidth,
                height: barrelHeight
            ))
        }

        let texture = SKTexture(image: image)
        enemyIconTexture = texture
        return texture
    }

    // Icon settings
    private static let enemyIconSize: CGFloat = 18
    private static let enemyIconSpacing: CGFloat = 6
    private static let enemyColumns = 2
    private static let sectionPadding: CGFloat = 10

    // Fixed Y positions (from top)
    private static let enemySectionY: CGFloat = 10
    private static let playerSectionY: CGFloat = 400
    private static let powerUpSectionY: CGFloat = 480
    private static let flagSectionY: CGFloat = 710

    private let sidebarHeight: CGFloat
    private var enemyIconsNode: SKNode!
    private var playerInfoNode: SKNode!
    private var powerUpNode: SKNode!
    private var flagNode: SKNode!
    private var levelLabel: SKLabelNode!

    // Cache previous values to avoid unnecessary updates
    private var lastEnemyCount: Int = -1
    private var lastPlayerLives: Int = -1
    private var lastPlayer2Lives: Int = -1
    private var lastLevel: Int = -1
    private var lastPowerUps: PowerUpData?
    private var lastPowerUps2: PowerUpData?

    /// Two-player game: shows lives for both players and power-ups in two columns
    private let twoPlayers: Bool

    // Two-player layout (from the top): each player gets a block with lives and their own
    // power-ups below: IP block at playerSectionY, IIP block player2BlockOffset lower
    private static let player2BlockOffset: CGFloat = 160     // IIP lives below IP lives
    private static let twoPlayerPowerUpGap: CGFloat = 52     // Lives section height before power-ups
    private static let twoPlayerLineHeight: CGFloat = 14     // 7 power-up rows fit in a block
    private static let twoPlayerFlagSectionY: CGFloat = 745  // Flag moves down to make room

    init(height: CGFloat, twoPlayers: Bool = false) {
        self.sidebarHeight = height
        self.twoPlayers = twoPlayers
        super.init()

        setupBackground()
        setupEnemyIcons()
        setupPlayerInfo()
        setupPowerUps()
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

    private func setupPowerUps() {
        powerUpNode = SKNode()
        // Two players: power-ups start right under the IP lives (IIP rows are drawn one block lower)
        let topY = twoPlayers ? Sidebar.playerSectionY + Sidebar.twoPlayerPowerUpGap : Sidebar.powerUpSectionY
        powerUpNode.position = CGPoint(x: Sidebar.sectionPadding, y: sidebarHeight - topY)
        addChild(powerUpNode)
    }

    private func setupFlag() {
        flagNode = SKNode()
        let flagY = twoPlayers ? Sidebar.twoPlayerFlagSectionY : Sidebar.flagSectionY
        flagNode.position = CGPoint(x: Sidebar.sectionPadding, y: sidebarHeight - flagY)
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

    /// Power-up data structure for sidebar display
    struct PowerUpData: Equatable {
        var starCount: Int = 0        // Shooting speed (max 3)
        var bossFireBoost: Int = 0    // Defeated bosses: faster shooting (every 3rd: extra bullet)
        var machinegunCount: Int = 0  // Extra bullets (max 3)
        var hasGun: Bool = false      // Can break steel
        var hasShip: Bool = false     // Can swim
        var hasSaw: Bool = false      // Can destroy trees
        var speedBoosts: Int = 0      // Speed upgrades (cars)
        var ballBoosts: Int = 0       // Start speed from soccer balls
        var hasLaser: Bool = false    // Shots pass through walls
        var friendHits: Int = 0       // Gzhel friend's remaining hits (0 = no friend on field)
    }

    /// Update the sidebar display (only when values change to avoid recreating nodes every frame).
    /// `player2Lives` / `powerUps2` are used in two-player games only.
    func update(remainingEnemies: Int, playerLives: Int, player2Lives: Int = 0, level: Int,
                powerUps: PowerUpData = PowerUpData(), powerUps2: PowerUpData = PowerUpData()) {
        if remainingEnemies != lastEnemyCount {
            lastEnemyCount = remainingEnemies
            updateEnemyIcons(count: remainingEnemies)
        }
        if playerLives != lastPlayerLives || (twoPlayers && player2Lives != lastPlayer2Lives) {
            lastPlayerLives = playerLives
            lastPlayer2Lives = player2Lives
            updatePlayerInfo(lives: playerLives, player2Lives: player2Lives)
        }
        if level != lastLevel {
            lastLevel = level
            updateFlag(level: level)
        }
        if powerUps != lastPowerUps || (twoPlayers && powerUps2 != lastPowerUps2) {
            lastPowerUps = powerUps
            lastPowerUps2 = powerUps2
            updatePowerUps(powerUps, player2: twoPlayers ? powerUps2 : nil)
        }
    }

    private func updatePowerUps(_ data: PowerUpData, player2 data2: PowerUpData?) {
        powerUpNode.removeAllChildren()

        var lineHeight: CGFloat = 16
        var yOffset: CGFloat

        if let data2 = data2 {
            // Each player's power-ups sit in their own block, under that player's lives
            lineHeight = Sidebar.twoPlayerLineHeight
            _ = addPowerUpRows(data, x: 0, y: 0, iconSize: 12, fontSize: 11, lineHeight: lineHeight)
            yOffset = addPowerUpRows(data2, x: 0, y: -Sidebar.player2BlockOffset,
                                     iconSize: 12, fontSize: 11, lineHeight: lineHeight)
            // Friend goes below the IIP block (fixed spot, so it doesn't jump around)
            yOffset = -Sidebar.player2BlockOffset - 7 * lineHeight - 6
        } else {
            yOffset = addPowerUpRows(data, x: 0, y: 0, iconSize: 12, fontSize: 11, lineHeight: lineHeight)
        }

        // Friend (Gzhel tank) and its remaining hits
        if data.friendHits > 0 {
            yOffset -= 4
            let title = SKLabelNode(text: "FRIEND")
            title.fontName = "Helvetica-Bold"
            title.fontSize = 10
            title.fontColor = SKColor(red: 0.35, green: 0.6, blue: 1.0, alpha: 1.0)
            title.horizontalAlignmentMode = .left
            title.verticalAlignmentMode = .center
            title.position = CGPoint(x: 0, y: yOffset)
            powerUpNode.addChild(title)
            yOffset -= lineHeight
            let row = createPowerUpRow(icon: "💙", label: "x\(data.friendHits)", iconSize: 12)
            row.position = CGPoint(x: 0, y: yOffset)
            powerUpNode.addChild(row)
            yOffset -= lineHeight
        }
    }

    /// Add one player's power-up rows in a column starting at the top; returns the next free Y
    private func addPowerUpRows(_ data: PowerUpData, x: CGFloat, y: CGFloat, iconSize: CGFloat,
                                fontSize: CGFloat, lineHeight: CGFloat) -> CGFloat {
        var rows: [(icon: String, label: String)] = []
        if data.starCount > 0 { rows.append(("⭐", "x\(data.starCount)")) }          // Shooting speed
        if data.bossFireBoost > 0 { rows.append(("🔥", "x\(data.bossFireBoost)")) }  // Boss reward: faster shooting
        if data.machinegunCount > 0 { rows.append(("💥", "x\(data.machinegunCount)")) } // Extra bullets
        if data.hasGun { rows.append(("🔫", "")) }      // Can break steel
        if data.hasShip { rows.append(("🚢", "")) }     // Can swim
        if data.hasSaw { rows.append(("🪚", "")) }      // Can destroy trees
        if data.hasLaser { rows.append(("🔦", "")) }    // Shots pass through walls
        if data.speedBoosts > 0 { rows.append(("🚗", "x\(data.speedBoosts)")) }
        if data.ballBoosts > 0 { rows.append(("⚽", "x\(data.ballBoosts)")) }      // Start speed (kept until a new game)

        var yOffset: CGFloat = y
        for row in rows {
            let node = createPowerUpRow(icon: row.icon, label: row.label, iconSize: iconSize, fontSize: fontSize)
            node.position = CGPoint(x: x, y: yOffset)
            powerUpNode.addChild(node)
            yOffset -= lineHeight
        }
        return yOffset
    }

    private func createPowerUpRow(icon: String, label: String, iconSize: CGFloat, fontSize: CGFloat = 11) -> SKNode {
        let container = SKNode()

        // Icon
        let iconLabel = SKLabelNode(text: icon)
        iconLabel.fontSize = iconSize
        iconLabel.horizontalAlignmentMode = .left
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: 0)
        container.addChild(iconLabel)

        // Label (quantity)
        if !label.isEmpty {
            let textLabel = SKLabelNode(text: label)
            textLabel.fontName = "Helvetica-Bold"
            textLabel.fontSize = fontSize
            textLabel.fontColor = Sidebar.textColor
            textLabel.horizontalAlignmentMode = .left
            textLabel.verticalAlignmentMode = .center
            textLabel.position = CGPoint(x: iconSize + (fontSize < 11 ? 2 : 4), y: 0)
            container.addChild(textLabel)
        }

        return container
    }

    private func updateEnemyIcons(count: Int) {
        enemyIconsNode.removeAllChildren()

        // Get cached texture (created once, reused for all icons)
        let texture = Sidebar.getEnemyIconTexture(size: Sidebar.enemyIconSize)

        for i in 0..<count {
            let col = i % Sidebar.enemyColumns
            let row = i / Sidebar.enemyColumns

            let x = CGFloat(col) * (Sidebar.enemyIconSize + Sidebar.enemyIconSpacing)
            let y = -CGFloat(row) * (Sidebar.enemyIconSize + Sidebar.enemyIconSpacing)

            // Use pre-rendered texture instead of 4 SKShapeNodes
            let icon = SKSpriteNode(texture: texture)
            icon.size = CGSize(width: Sidebar.enemyIconSize, height: Sidebar.enemyIconSize)
            icon.position = CGPoint(x: x + Sidebar.enemyIconSize / 2, y: y - Sidebar.enemyIconSize / 2)
            enemyIconsNode.addChild(icon)
        }
    }

    private func updatePlayerInfo(lives: Int, player2Lives: Int) {
        playerInfoNode.removeAllChildren()

        addPlayerLivesSection(title: "IP", lives: lives,
                              tankColor: GameSettings.shared.playerTankColor.color, y: 0)
        if twoPlayers {
            addPlayerLivesSection(title: "IIP", lives: player2Lives,
                                  tankColor: GameSettings.shared.player2TankColor.color,
                                  y: -Sidebar.player2BlockOffset)
            // Divider between the IP and IIP blocks
            let divider = SKShapeNode(rectOf: CGSize(width: Sidebar.sidebarWidth - Sidebar.sectionPadding * 2, height: 2))
            divider.fillColor = Sidebar.textColor
            divider.strokeColor = .clear
            divider.position = CGPoint(x: (Sidebar.sidebarWidth - Sidebar.sectionPadding * 2) / 2,
                                       y: -Sidebar.player2BlockOffset + 12)
            playerInfoNode.addChild(divider)
        }
    }

    /// "IP" / "IIP" title, small tank icon and remaining lives
    private func addPlayerLivesSection(title: String, lives: Int, tankColor: SKColor, y: CGFloat) {
        let ipLabel = SKLabelNode(text: title)
        ipLabel.fontName = "Helvetica-Bold"
        ipLabel.fontSize = 12
        ipLabel.fontColor = Sidebar.playerIconColor
        ipLabel.horizontalAlignmentMode = .left
        ipLabel.position = CGPoint(x: 0, y: y)
        playerInfoNode.addChild(ipLabel)

        // Small player tank icon
        let tankIcon = createPlayerTankIcon(size: 20, color: tankColor)
        tankIcon.position = CGPoint(x: 10, y: y - 25)
        playerInfoNode.addChild(tankIcon)

        // Lives count (show lives - 1 like original)
        let displayLives = max(0, lives - 1)
        let livesLabel = SKLabelNode(text: "\(displayLives)")
        livesLabel.fontName = "Helvetica-Bold"
        livesLabel.fontSize = 14
        livesLabel.fontColor = Sidebar.textColor
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.position = CGPoint(x: Sidebar.sidebarWidth - Sidebar.sectionPadding * 2, y: y - 18)
        playerInfoNode.addChild(livesLabel)
    }

    private func createPlayerTankIcon(size: CGFloat, color tankColor: SKColor) -> SKNode {
        let container = SKNode()

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
