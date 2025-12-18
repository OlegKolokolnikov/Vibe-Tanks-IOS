import SpriteKit

// MARK: - UIImage Extension for solid color textures
extension UIImage {
    static func solidColor(_ color: UIColor, size: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}

/// Main game scene
class GameScene: SKScene {

    // Highscore (persists across games until app restart)
    private static var highScore: Int = 250

    // Easy mode: activates after 3 consecutive losses
    private static var consecutiveLosses: Int = 0
    static var isEasyMode: Bool { consecutiveLosses >= 3 }

    // Gzhel decoration state (accessible for cat color)
    private(set) static var isGzhelActive: Bool = false

    // Alien mode state (accessible for enemy spawner)
    private(set) static var isAlienModeActive: Bool = false

    // Pre-rendered spawn effect textures (static for reuse)
    private static var lightningBoltTexture: SKTexture?
    private static var spawnFlashTexture: SKTexture?

    /// Get or create lightning bolt texture
    static func getLightningBoltTexture() -> SKTexture {
        if let cached = lightningBoltTexture {
            return cached
        }

        // Render lightning bolt to texture
        let size = CGSize(width: 20, height: 35)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext

            // Draw lightning bolt path
            ctx.setStrokeColor(UIColor.cyan.cgColor)
            ctx.setLineWidth(2)
            ctx.setLineCap(.round)

            ctx.move(to: CGPoint(x: 10, y: 5))
            ctx.addLine(to: CGPoint(x: 13, y: 12))
            ctx.addLine(to: CGPoint(x: 8, y: 18))
            ctx.addLine(to: CGPoint(x: 14, y: 28))
            ctx.addLine(to: CGPoint(x: 9, y: 22))
            ctx.addLine(to: CGPoint(x: 12, y: 15))
            ctx.addLine(to: CGPoint(x: 7, y: 8))
            ctx.strokePath()
        }

        let texture = SKTexture(image: image)
        lightningBoltTexture = texture
        return texture
    }

    /// Get or create spawn flash texture
    static func getSpawnFlashTexture() -> SKTexture {
        if let cached = spawnFlashTexture {
            return cached
        }

        let size: CGFloat = 40
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = size / 2

            // Outer glow (cyan)
            ctx.setFillColor(UIColor.cyan.withAlphaComponent(0.3).cgColor)
            ctx.fillEllipse(in: CGRect(x: center - 18, y: center - 18, width: 36, height: 36))

            // Inner flash (white)
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fillEllipse(in: CGRect(x: center - 15, y: center - 15, width: 30, height: 30))
        }

        let texture = SKTexture(image: image)
        spawnFlashTexture = texture
        return texture
    }

    // Game objects (internal for extension access)
    var gameMap: GameMap!
    var playerTank: Tank!
    var enemyTanks: [Tank] = []
    private var _cachedAllTanks: [Tank] = []
    private var _allTanksDirty: Bool = true
    var bullets: [Bullet] = []
    var bulletsMarkedForRemoval: Set<ObjectIdentifier> = []
    var powerUps: [PowerUp] = []
    var base: Base!

    // UFO and Easter Egg
    var ufo: UFO?
    var easterEgg: EasterEgg?
    var ufoSpawnedThisLevel: Bool = false
    var ufoWasKilled: Bool = false
    var playerCollectedEasterEgg: Bool = false
    var playerKills: Int = 0
    private var ufoMessageTimer: Int = 0

    // Gold power-up (Gzhel mode only)
    private var goldSpawnedThisLevel: Bool = false
    private var goldSpawnTimer: Int = 0
    private let goldSpawnChance: Double = 0.0003  // ~1% chance per second at 60fps
    private var ufoMessageLabel: SKLabelNode?

    // UI
    var touchController: TouchController!
    var sidebar: Sidebar!
    var scoreLabel: SKLabelNode!

    // Game state
    var score: Int = 0
    private var lastBonusLifeScore: Int = 0  // Track last 100-point milestone
    var level: Int = 1
    private var sessionSeed: UInt64 = 0
    var isGameOver: Bool = false
    var isGamePaused: Bool = false
    var didWinLevel: Bool = false

    // Level stats for score breakdown
    private var levelStartScore: Int = 0
    var killsByType: [Tank.EnemyType: Int] = [:]

    // Freeze effect
    var freezeTimer: Int = 0
    var playerFreezeTimer: Int = 0  // Player frozen by enemy power-up

    // Victory delay (5 seconds to collect remaining power-ups)
    private var victoryDelayTimer: Int = 0

    // Base protection
    var baseProtectionTimer: Int = 0
    var baseFlashTimer: Int = 0
    var baseIsSteel: Bool = false

    // Keyboard input (for simulator and macOS)
    private var keyboardDirection: Direction?
    private var keyboardFiring: Bool = false
    #if os(iOS) || os(tvOS)
    private var pressedDirectionKeys: Set<UIKeyboardHIDUsage> = []
    #else
    private var pressedDirectionKeys: Set<UInt16> = []
    #endif

    // Spawning
    private var enemySpawner: EnemySpawner!

    // Camera for scrolling (if needed)
    private var gameCamera: SKCameraNode!
    var gameLayer: SKNode!

    // Player lives to carry across levels
    private var initialLives: Int = 3

    // Power-ups to carry across levels
    struct PlayerPowerUps {
        var starCount: Int = 0
        var machinegunCount: Int = 0
        var bulletPower: Int = 1
        var speedMultiplier: CGFloat = 1.0
        var canSwim: Bool = false
        var canDestroyTrees: Bool = false
    }
    private var initialPowerUps = PlayerPowerUps()

    // Gzhel decoration (reward for cat victory)
    private var showGzhelBorder: Bool = false

    // Alien mode (when UFO escaped previous level - alien is at base instead of cat)
    private var alienMode: Bool = false
    private var ufoEscapedThisLevel: Bool = false  // Track if UFO escapes to trigger alien mode next level

    // Level initialization
    init(size: CGSize, level: Int = 1, score: Int = 0, lives: Int = 3, sessionSeed: UInt64 = 0, powerUps: PlayerPowerUps = PlayerPowerUps(), gzhelBorder: Bool = false, alienMode: Bool = false) {
        self.level = level
        self.score = score
        self.initialLives = lives
        self.initialPowerUps = powerUps
        self.showGzhelBorder = gzhelBorder
        self.alienMode = alienMode
        self.sessionSeed = sessionSeed == 0 ? UInt64.random(in: 0..<UInt64.max) : sessionSeed
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        backgroundColor = .black

        setupCamera()
        setupGame()
        setupUI()

        // Play intro sound when game starts
        SoundManager.shared.playIntro()
    }

    // MARK: - Setup

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)
    }

    /// Setup Gzhel (Russian blue ceramic) style border decoration (optimized with textures)
    private func setupGzhelBorder() {
        let gzhelLayer = SKNode()
        gzhelLayer.zPosition = -10  // Behind everything

        // Gzhel colors
        let gzhelBlue = SKColor(red: 0.0, green: 0.3, blue: 0.7, alpha: 1.0)
        let gzhelLightBlue = SKColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1.0)

        // Calculate border areas
        let mapWidth = CGFloat(GameConstants.mapWidth) * GameConstants.tileSize
        let mapHeight = CGFloat(GameConstants.mapHeight) * GameConstants.tileSize
        let totalWidth = mapWidth + GameConstants.sidebarWidth

        // Pre-render flower and vine textures (much faster than SKShapeNodes)
        let flowerTexture30 = renderGzhelFlowerTexture(size: 30, blueColor: gzhelBlue, lightBlue: gzhelLightBlue)
        let flowerTexture25 = renderGzhelFlowerTexture(size: 25, blueColor: gzhelBlue, lightBlue: gzhelLightBlue)
        let vineTexture = renderGzhelVineTexture(length: 50, color: gzhelBlue)

        // White background sprites (single texture, very efficient)
        let whiteTexture = SKTexture(image: UIImage.solidColor(.white, size: CGSize(width: 4, height: 4)))

        let leftBorder = SKSpriteNode(texture: whiteTexture)
        leftBorder.size = CGSize(width: 200, height: mapHeight + 400)
        leftBorder.position = CGPoint(x: -100, y: mapHeight / 2)
        gzhelLayer.addChild(leftBorder)

        let rightBorder = SKSpriteNode(texture: whiteTexture)
        rightBorder.size = CGSize(width: 200, height: mapHeight + 400)
        rightBorder.position = CGPoint(x: totalWidth + 100, y: mapHeight / 2)
        gzhelLayer.addChild(rightBorder)

        let topBorder = SKSpriteNode(texture: whiteTexture)
        topBorder.size = CGSize(width: totalWidth + 400, height: 200)
        topBorder.position = CGPoint(x: totalWidth / 2, y: mapHeight + 100)
        gzhelLayer.addChild(topBorder)

        let bottomBorder = SKSpriteNode(texture: whiteTexture)
        bottomBorder.size = CGSize(width: totalWidth + 400, height: 200)
        bottomBorder.position = CGPoint(x: totalWidth / 2, y: -100)
        gzhelLayer.addChild(bottomBorder)

        // Add flowers using pre-rendered texture
        let flowerSpacing: CGFloat = 80

        // Left side flowers
        for y in stride(from: CGFloat(40), to: mapHeight, by: flowerSpacing) {
            let flower = SKSpriteNode(texture: flowerTexture30)
            flower.position = CGPoint(x: -30, y: y)
            flower.zPosition = 1  // On top of white background
            gzhelLayer.addChild(flower)
        }

        // Right side flowers
        for y in stride(from: CGFloat(40), to: mapHeight, by: flowerSpacing) {
            let flower = SKSpriteNode(texture: flowerTexture30)
            flower.position = CGPoint(x: totalWidth + 30, y: y)
            flower.xScale = -1
            flower.zPosition = 1
            gzhelLayer.addChild(flower)
        }

        // Top flowers
        for x in stride(from: CGFloat(40), to: totalWidth, by: flowerSpacing) {
            let flower = SKSpriteNode(texture: flowerTexture25)
            flower.position = CGPoint(x: x, y: mapHeight + 30)
            flower.zRotation = -.pi / 2
            flower.zPosition = 1
            gzhelLayer.addChild(flower)
        }

        // Bottom flowers
        for x in stride(from: CGFloat(40), to: totalWidth, by: flowerSpacing) {
            let flower = SKSpriteNode(texture: flowerTexture25)
            flower.position = CGPoint(x: x, y: -30)
            flower.zRotation = .pi / 2
            flower.zPosition = 1
            gzhelLayer.addChild(flower)
        }

        // Add vines using pre-rendered texture
        for y in stride(from: CGFloat(70), to: mapHeight - 40, by: flowerSpacing) {
            let vine = SKSpriteNode(texture: vineTexture)
            vine.position = CGPoint(x: -45, y: y + flowerSpacing / 2)
            vine.zPosition = 1
            gzhelLayer.addChild(vine)

            let vine2 = SKSpriteNode(texture: vineTexture)
            vine2.position = CGPoint(x: totalWidth + 45, y: y + flowerSpacing / 2)
            vine2.xScale = -1
            vine2.zPosition = 1
            gzhelLayer.addChild(vine2)
        }

        gameLayer.addChild(gzhelLayer)
    }

    /// Render Gzhel chamomile flower to texture - white petals, yellow center, blue accents
    private func renderGzhelFlowerTexture(size: CGFloat, blueColor: SKColor, lightBlue: SKColor) -> SKTexture {
        let textureSize = CGSize(width: size * 2, height: size * 2)
        let renderer = UIGraphicsImageRenderer(size: textureSize)

        // Convert SKColor to UIColor for use in renderer
        let blueUIColor = UIColor(cgColor: blueColor.cgColor)
        let lightBlueUIColor = UIColor(cgColor: lightBlue.cgColor)

        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = CGPoint(x: textureSize.width / 2, y: textureSize.height / 2)

            // Colors
            let petalWhite = UIColor.white.cgColor
            let petalShadow = UIColor(red: 0.9, green: 0.92, blue: 0.98, alpha: 1).cgColor
            let centerYellow = UIColor(red: 1.0, green: 0.85, blue: 0.2, alpha: 1).cgColor
            let centerOrange = UIColor(red: 0.95, green: 0.7, blue: 0.1, alpha: 1).cgColor

            // Outer decorative swirls (blue)
            ctx.setStrokeColor(lightBlueUIColor.cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)
            for i in 0..<8 {
                let angle = CGFloat(i) * .pi / 4 + .pi / 8
                let startR = size * 0.7
                let endR = size * 0.85
                ctx.move(to: CGPoint(x: center.x + cos(angle) * startR, y: center.y + sin(angle) * startR))
                ctx.addQuadCurve(
                    to: CGPoint(x: center.x + cos(angle + 0.3) * endR, y: center.y + sin(angle + 0.3) * endR),
                    control: CGPoint(x: center.x + cos(angle + 0.15) * (endR + 5), y: center.y + sin(angle + 0.15) * (endR + 5))
                )
            }
            ctx.strokePath()

            // Main white petals (chamomile style - many thin petals)
            let petalCount = 16
            for i in 0..<petalCount {
                let angle = CGFloat(i) * .pi * 2 / CGFloat(petalCount)

                ctx.saveGState()
                ctx.translateBy(x: center.x, y: center.y)
                ctx.rotate(by: angle)

                // Petal shape - elongated with pointed tip
                let petalPath = CGMutablePath()
                let petalLength = size * 0.55
                let petalWidth = size * 0.12

                petalPath.move(to: CGPoint(x: 0, y: size * 0.15))
                petalPath.addQuadCurve(
                    to: CGPoint(x: 0, y: size * 0.15 + petalLength),
                    control: CGPoint(x: petalWidth, y: size * 0.15 + petalLength * 0.5)
                )
                petalPath.addQuadCurve(
                    to: CGPoint(x: 0, y: size * 0.15),
                    control: CGPoint(x: -petalWidth, y: size * 0.15 + petalLength * 0.5)
                )

                // Shadow side
                ctx.setFillColor(i % 2 == 0 ? petalWhite : petalShadow)
                ctx.addPath(petalPath)
                ctx.fillPath()

                // Blue outline
                ctx.setStrokeColor(blueUIColor.cgColor)
                ctx.setLineWidth(0.8)
                ctx.addPath(petalPath)
                ctx.strokePath()

                // Center vein (blue line)
                ctx.setStrokeColor(lightBlueUIColor.cgColor)
                ctx.setLineWidth(0.5)
                ctx.move(to: CGPoint(x: 0, y: size * 0.18))
                ctx.addLine(to: CGPoint(x: 0, y: size * 0.15 + petalLength * 0.7))
                ctx.strokePath()

                ctx.restoreGState()
            }

            // Yellow center with gradient effect
            let centerRadius = size * 0.18
            let centerRect = CGRect(x: center.x - centerRadius, y: center.y - centerRadius,
                                    width: centerRadius * 2, height: centerRadius * 2)
            ctx.setFillColor(centerYellow)
            ctx.fillEllipse(in: centerRect)

            // Inner orange ring
            let innerRadius = size * 0.12
            let innerRect = CGRect(x: center.x - innerRadius, y: center.y - innerRadius,
                                   width: innerRadius * 2, height: innerRadius * 2)
            ctx.setFillColor(centerOrange)
            ctx.fillEllipse(in: innerRect)

            // Center texture dots
            ctx.setFillColor(UIColor(red: 0.85, green: 0.6, blue: 0.1, alpha: 1).cgColor)
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let dotR = size * 0.06
                let dotX = center.x + cos(angle) * dotR - 1
                let dotY = center.y + sin(angle) * dotR - 1
                ctx.fillEllipse(in: CGRect(x: dotX, y: dotY, width: 2, height: 2))
            }

            // Blue center outline
            ctx.setStrokeColor(blueUIColor.cgColor)
            ctx.setLineWidth(1.5)
            ctx.strokeEllipse(in: centerRect)
        }

        return SKTexture(image: image)
    }

    /// Render decorative Gzhel vine with curls and leaves
    private func renderGzhelVineTexture(length: CGFloat, color: SKColor) -> SKTexture {
        let textureSize = CGSize(width: 50, height: length + 20)
        let renderer = UIGraphicsImageRenderer(size: textureSize)

        // Convert SKColor to UIColor for use in renderer
        let colorUIColor = UIColor(cgColor: color.cgColor)

        let image = renderer.image { context in
            let ctx = context.cgContext
            let centerX: CGFloat = 20
            let startY: CGFloat = 10
            let endY = textureSize.height - 10

            let darkBlue = colorUIColor.cgColor
            let lightBlue = UIColor(red: 0.4, green: 0.6, blue: 0.9, alpha: 1).cgColor

            // Main flowing vine stem
            ctx.setStrokeColor(darkBlue)
            ctx.setLineWidth(2.5)
            ctx.setLineCap(.round)

            ctx.move(to: CGPoint(x: centerX, y: startY))
            ctx.addCurve(
                to: CGPoint(x: centerX + 8, y: startY + length * 0.33),
                control1: CGPoint(x: centerX + 15, y: startY + length * 0.1),
                control2: CGPoint(x: centerX - 5, y: startY + length * 0.25)
            )
            ctx.addCurve(
                to: CGPoint(x: centerX, y: endY),
                control1: CGPoint(x: centerX + 20, y: startY + length * 0.5),
                control2: CGPoint(x: centerX - 10, y: startY + length * 0.8)
            )
            ctx.strokePath()

            // Decorative curling tendrils
            ctx.setStrokeColor(lightBlue)
            ctx.setLineWidth(1.5)

            // Top curl
            ctx.move(to: CGPoint(x: centerX + 5, y: startY + length * 0.15))
            ctx.addQuadCurve(
                to: CGPoint(x: centerX + 18, y: startY + length * 0.08),
                control: CGPoint(x: centerX + 20, y: startY + length * 0.18)
            )
            ctx.addQuadCurve(
                to: CGPoint(x: centerX + 22, y: startY + length * 0.12),
                control: CGPoint(x: centerX + 22, y: startY + length * 0.05)
            )
            ctx.strokePath()

            // Middle curl
            ctx.move(to: CGPoint(x: centerX + 10, y: startY + length * 0.45))
            ctx.addQuadCurve(
                to: CGPoint(x: centerX + 25, y: startY + length * 0.5),
                control: CGPoint(x: centerX + 22, y: startY + length * 0.4)
            )
            ctx.addQuadCurve(
                to: CGPoint(x: centerX + 20, y: startY + length * 0.55),
                control: CGPoint(x: centerX + 30, y: startY + length * 0.52)
            )
            ctx.strokePath()

            // Bottom curl
            ctx.move(to: CGPoint(x: centerX - 3, y: startY + length * 0.75))
            ctx.addQuadCurve(
                to: CGPoint(x: centerX - 12, y: startY + length * 0.7),
                control: CGPoint(x: centerX - 15, y: startY + length * 0.78)
            )
            ctx.strokePath()

            // Decorative leaves
            func drawLeaf(at point: CGPoint, angle: CGFloat, leafSize: CGFloat) {
                ctx.saveGState()
                ctx.translateBy(x: point.x, y: point.y)
                ctx.rotate(by: angle)

                // Leaf shape
                let leafPath = CGMutablePath()
                leafPath.move(to: CGPoint(x: 0, y: 0))
                leafPath.addQuadCurve(to: CGPoint(x: 0, y: leafSize), control: CGPoint(x: leafSize * 0.5, y: leafSize * 0.5))
                leafPath.addQuadCurve(to: CGPoint(x: 0, y: 0), control: CGPoint(x: -leafSize * 0.5, y: leafSize * 0.5))

                ctx.setFillColor(darkBlue)
                ctx.addPath(leafPath)
                ctx.fillPath()

                // Leaf vein
                ctx.setStrokeColor(lightBlue)
                ctx.setLineWidth(0.8)
                ctx.move(to: CGPoint(x: 0, y: 2))
                ctx.addLine(to: CGPoint(x: 0, y: leafSize * 0.7))
                ctx.strokePath()

                ctx.restoreGState()
            }

            // Add leaves along the vine
            drawLeaf(at: CGPoint(x: centerX + 3, y: startY + length * 0.25), angle: .pi / 4, leafSize: 12)
            drawLeaf(at: CGPoint(x: centerX + 12, y: startY + length * 0.4), angle: .pi / 3, leafSize: 10)
            drawLeaf(at: CGPoint(x: centerX + 5, y: startY + length * 0.6), angle: -.pi / 5, leafSize: 11)
            drawLeaf(at: CGPoint(x: centerX - 5, y: startY + length * 0.8), angle: -.pi / 3, leafSize: 9)

            // Small decorative dots
            ctx.setFillColor(lightBlue)
            let dotPositions: [(CGFloat, CGFloat)] = [
                (centerX + 15, startY + length * 0.2),
                (centerX + 20, startY + length * 0.35),
                (centerX - 8, startY + length * 0.65),
                (centerX + 8, startY + length * 0.85)
            ]
            for (x, y) in dotPositions {
                ctx.fillEllipse(in: CGRect(x: x - 1.5, y: y - 1.5, width: 3, height: 3))
            }
        }

        return SKTexture(image: image)
    }

    private func setupGame() {
        // Initialize level stats tracking
        levelStartScore = score
        killsByType = [:]

        // Create game layer
        gameLayer = SKNode()
        addChild(gameLayer)

        // Add Gzhel border decoration if earned from previous level (must be after gameLayer exists)
        GameScene.isGzhelActive = showGzhelBorder
        GameScene.isAlienModeActive = alienMode
        if showGzhelBorder {
            setupGzhelBorder()
        }

        // Create map with session seed + level for deterministic but session-unique generation
        let mapSeed = sessionSeed + UInt64(level * 12345)
        gameMap = GameMap(level: level, seed: mapSeed)
        gameLayer.addChild(gameMap)

        // Create sidebar (on right side of game area)
        let mapSize = gameMap.pixelSize
        sidebar = Sidebar(height: mapSize.height)
        sidebar.position = CGPoint(x: mapSize.width, y: 0)
        gameLayer.addChild(sidebar)

        // Center camera on game area + sidebar
        let totalWidth = mapSize.width + GameConstants.sidebarWidth
        gameCamera.position = CGPoint(x: totalWidth / 2, y: mapSize.height / 2)

        // Scale to fit the map + sidebar in the screen
        let scaleX = size.width / totalWidth
        let scaleY = size.height / mapSize.height
        let scale = min(scaleX, scaleY) * 0.95
        gameCamera.setScale(1 / scale)

        // Create base - centered in col 13, row 24 (matching the protection gap)
        // Tile center formula: x = col * tileSize + tileSize/2, y = (mapHeight-1-row) * tileSize + tileSize/2
        let baseCol = 13
        let baseRow = 24
        let basePosition = CGPoint(
            x: CGFloat(baseCol) * GameConstants.tileSize + GameConstants.tileSize / 2,
            y: CGFloat(GameConstants.mapHeight - 1 - baseRow) * GameConstants.tileSize + GameConstants.tileSize / 2
        )
        base = Base(position: basePosition, isAlien: alienMode)
        gameLayer.addChild(base)

        // Create player tank
        let playerSpawnPos = CGPoint(
            x: GameConstants.tileSize * 8,
            y: GameConstants.tileSize * 2
        )
        playerTank = Tank(
            position: playerSpawnPos,
            direction: .up,
            isPlayer: true,
            playerNumber: 1
        )
        playerTank.lives = initialLives  // Carry lives from previous level

        // Apply power-ups from previous level
        playerTank.starCount = initialPowerUps.starCount
        playerTank.machinegunCount = initialPowerUps.machinegunCount
        playerTank.bulletPower = initialPowerUps.bulletPower
        playerTank.speedMultiplier = initialPowerUps.speedMultiplier
        playerTank.canSwim = initialPowerUps.canSwim
        playerTank.canDestroyTrees = initialPowerUps.canDestroyTrees

        // Always redraw tank to show power-up indicators
        playerTank.drawTank()

        gameLayer.addChild(playerTank)

        // Calculate enemies for this level (easy mode: 18, normal: base 20 + 2 per level)
        let totalEnemies = GameScene.isEasyMode ? 18 : min(20 + (level - 1) * 2, 50)

        // Setup enemy spawner
        enemySpawner = EnemySpawner(
            totalEnemies: totalEnemies,
            maxOnScreen: GameConstants.maxEnemiesOnScreen
        )
    }

    private func setupUI() {
        // Get the camera scale to properly size UI elements
        let cameraScale = gameCamera.xScale

        // Touch controller - add to camera so it stays on screen
        // Use the visible screen size in camera coordinates
        touchController = TouchController()
        let visibleSize = CGSize(width: size.width * cameraScale, height: size.height * cameraScale)
        touchController.setupForScreen(size: visibleSize)
        touchController.setGzhelMode(showGzhelBorder)
        gameCamera.addChild(touchController)

        // Score label - positioned at top left with safe margin
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = showGzhelBorder ? .blue : .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(
            x: -visibleSize.width / 2 + 80,
            y: visibleSize.height / 2 - 60
        )
        scoreLabel.zPosition = 100
        gameCamera.addChild(scoreLabel)

        // Initial sidebar update
        sidebar.update(
            remainingEnemies: enemySpawner.remainingEnemies,
            playerLives: playerTank.lives,
            level: level
        )
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        // Check for pause button press
        if touchController.pausePressed {
            touchController.resetPausePressed()
            togglePause()
        }

        guard !isGameOver && !isGamePaused else { return }

        // Update freeze timer (enemies frozen)
        if freezeTimer > 0 {
            freezeTimer -= 1
        }

        // Update player freeze timer
        if playerFreezeTimer > 0 {
            playerFreezeTimer -= 1
        }

        // Update victory delay timer (5 seconds to collect power-ups)
        if victoryDelayTimer > 0 {
            victoryDelayTimer -= 1
            if victoryDelayTimer == 0 {
                levelComplete()
                return
            }
        }

        // Update base protection timer
        updateBaseProtection()

        updatePlayer()
        updateEnemies()
        updateBullets()
        updatePowerUps()
        updateSpawner()
        updateUFO()
        updateEasterEgg()
        updateGoldSpawn()
        checkCollisions()
        flushBulletRemovals()  // Batch remove all bullets marked for removal
        checkGameState()
        updateUI()
    }

    private func updatePlayer() {
        guard playerTank.isAlive else {
            // Player is dead - handle respawn
            if playerTank.lives > 0 {
                // If not already respawning, start respawn
                if !playerTank.isWaitingToRespawn {
                    playerTank.respawn(at: CGPoint(
                        x: GameConstants.tileSize * 8,
                        y: GameConstants.tileSize * 2
                    ))
                }
                playerTank.updateRespawnTimer()
            }
            return
        }

        // Handle movement from touch controller or keyboard
        let direction = touchController.currentDirection ?? keyboardDirection
        if playerFreezeTimer <= 0 {
            // Normal movement
            if let dir = direction {
                playerTank.move(direction: dir, map: gameMap, allTanks: allTanks)
            } else {
                // No input - continue ice slide if player was on ice
                _ = playerTank.continueIceSlide(map: gameMap, allTanks: allTanks)
            }
        } else if GameScene.isEasyMode, let dir = direction {
            // Easy mode: can turn while frozen (but not move)
            playerTank.turn(to: dir)
        }

        // Check for forest destruction (SAW power-up)
        if playerTank.canDestroyTrees {
            checkForestDestruction(for: playerTank)
        }

        // Handle shooting from touch or keyboard (allowed even when frozen)
        if touchController.isFiring || keyboardFiring {
            let newBullets = playerTank.shoot()
            if !newBullets.isEmpty {
                SoundManager.shared.playShoot()
                addBulletsWithSpawnCheck(newBullets)
            }
        }

        playerTank.update(map: gameMap, allTanks: allTanks)
    }

    private func updateEnemies() {
        for enemy in enemyTanks {
            guard enemy.isAlive else { continue }

            // Skip AI update if frozen
            if freezeTimer > 0 { continue }

            // Update AI
            if let ai = enemy.ai {
                let (direction, shouldShoot) = ai.update(
                    map: gameMap,
                    playerTanks: [playerTank],
                    allTanks: allTanks
                )

                if let dir = direction {
                    enemy.move(direction: dir, map: gameMap, allTanks: allTanks)
                }

                // Check for forest destruction (SAW power-up)
                if enemy.canDestroyTrees {
                    checkForestDestruction(for: enemy)
                }

                if shouldShoot {
                    let newBullets = enemy.shoot()
                    if !newBullets.isEmpty {
                        SoundManager.shared.playShoot()
                        addBulletsWithSpawnCheck(newBullets)
                    }
                }
            }

            enemy.update(map: gameMap, allTanks: allTanks)
        }
    }

    /// Check and destroy forest tiles at tank position (SAW power-up)
    private func checkForestDestruction(for tank: Tank) {
        let halfSize = tank.size.width / 2
        let positions = [
            tank.position,
            CGPoint(x: tank.position.x - halfSize, y: tank.position.y),
            CGPoint(x: tank.position.x + halfSize, y: tank.position.y),
            CGPoint(x: tank.position.x, y: tank.position.y - halfSize),
            CGPoint(x: tank.position.x, y: tank.position.y + halfSize)
        ]

        for pos in positions {
            _ = gameMap.destroyForest(at: pos)
        }
    }

    private func updateBullets() {
        var bulletsOutOfBounds: [Bullet] = []
        var bulletsHitObstacle: [Bullet] = []

        for bullet in bullets {
            bullet.update()

            // Check out of bounds (not an obstacle - bullet left the screen)
            if bullet.isOutOfBounds(mapSize: gameMap.pixelSize) {
                bulletsOutOfBounds.append(bullet)
                continue
            }

            // Check map collision (walls - this IS an obstacle)
            let (hit, _) = gameMap.checkBulletCollision(
                position: bullet.position,
                power: bullet.power
            )
            if hit {
                bulletsHitObstacle.append(bullet)
            }
        }

        // Remove bullets that went out of bounds (not obstacles)
        for bullet in bulletsOutOfBounds {
            removeBullet(bullet, hitObstacle: false)
        }

        // Remove bullets that hit walls/obstacles
        for bullet in bulletsHitObstacle {
            removeBullet(bullet, hitObstacle: true)
        }
    }

    /// Add bullets to the scene, checking if they spawn inside walls
    /// If a bullet spawns inside a wall, it immediately triggers the wall collision
    private func addBulletsWithSpawnCheck(_ newBullets: [Bullet]) {
        for bullet in newBullets {
            // Check if bullet spawns inside a wall
            let (hit, _) = gameMap.checkBulletCollision(
                position: bullet.position,
                power: bullet.power
            )
            if hit {
                // Bullet spawned inside wall - immediately destroy it
                // This triggers wall destruction if applicable
                bullet.owner?.bulletDestroyed(hitObstacle: true)
                // Don't add bullet to scene
            } else {
                bullets.append(bullet)
                gameLayer.addChild(bullet)
            }
        }
    }

    private func updatePowerUps() {
        var powerUpsToRemove: [PowerUp] = []

        for powerUp in powerUps {
            if powerUp.update() {
                powerUpsToRemove.append(powerUp)
            }
        }

        for powerUp in powerUpsToRemove {
            powerUp.removeFromParent()
            powerUps.removeAll { $0 === powerUp }
        }
    }

    private func updateSpawner() {
        // Spawn regular enemies (don't spawn on player)
        if let newEnemy = enemySpawner.update(existingEnemies: enemyTanks, playerTank: playerTank, map: gameMap) {
            enemyTanks.append(newEnemy)
            invalidateAllTanksCache()
            gameLayer.addChild(newEnemy)
            showSpawnEffect(at: newEnemy.position)
        }

        // Spawn extra enemies (from tank power-up collection, don't spawn on player)
        if let extraEnemy = enemySpawner.spawnExtraEnemy(existingEnemies: enemyTanks, playerTank: playerTank, map: gameMap) {
            enemyTanks.append(extraEnemy)
            invalidateAllTanksCache()
            gameLayer.addChild(extraEnemy)
            showSpawnEffect(at: extraEnemy.position)
        }
    }

    /// Show electricity/lightning effect when enemy spawns
    private func showSpawnEffect(at position: CGPoint) {
        let effectNode = SKNode()
        effectNode.position = position
        effectNode.zPosition = 50

        // Get cached textures
        let boltTexture = GameScene.getLightningBoltTexture()
        let flashTexture = GameScene.getSpawnFlashTexture()

        // Create multiple lightning bolts using cached texture
        for i in 0..<6 {
            let bolt = SKSpriteNode(texture: boltTexture)
            bolt.size = CGSize(width: 20, height: 35)
            bolt.zRotation = CGFloat(i) * .pi / 3  // Spread around 360 degrees
            effectNode.addChild(bolt)
        }

        // Add center flash using cached texture
        let flash = SKSpriteNode(texture: flashTexture)
        flash.size = CGSize(width: 40, height: 40)
        effectNode.addChild(flash)

        gameLayer.addChild(effectNode)

        // Animate: quick flash then fade
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()

        effectNode.run(SKAction.sequence([scaleUp, fadeOut, remove]))
    }

    private func updateUFO() {
        // Update message timer
        if ufoMessageTimer > 0 {
            ufoMessageTimer -= 1
            if ufoMessageTimer == 0 {
                ufoMessageLabel?.removeFromParent()
                ufoMessageLabel = nil
            }
        }

        // Check UFO spawn conditions (no UFO in alien mode or easy mode)
        if !ufoSpawnedThisLevel && ufo == nil && !alienMode && !GameScene.isEasyMode {
            // UFO spawns when player has machinegun and 5+ kills
            if playerTank.machinegunCount > 0 && playerKills >= GameConstants.ufoKillsRequired {
                // Random chance each frame
                if Double.random(in: 0...1) < GameConstants.ufoSpawnChance {
                    spawnUFO()
                }
            }
        }

        // Update existing UFO
        guard let currentUFO = ufo, currentUFO.isAlive else {
            // Check if UFO escaped (died but wasn't killed by player)
            if ufo != nil && !ufoWasKilled {
                showUFOMessage("UFO ESCAPED!", color: .red)
                ufoEscapedThisLevel = true  // Next level will have alien at base
            }
            if ufo != nil && !ufo!.isAlive {
                ufo?.removeFromParent()
                ufo = nil
            }
            return
        }

        let newBullets = currentUFO.update(
            mapWidth: gameMap.pixelSize.width,
            mapHeight: gameMap.pixelSize.height
        )

        for bullet in newBullets {
            bullets.append(bullet)
            gameLayer.addChild(bullet)
            SoundManager.shared.playLaser()
        }
    }

    private func spawnUFO() {
        let mapSize = gameMap.pixelSize
        let fromRight = Bool.random()
        let startX = fromRight ? mapSize.width + 48 : -48
        let startY = 100 + CGFloat.random(in: 0...200)

        ufo = UFO(startX: startX, startY: startY, movingRight: !fromRight)
        gameLayer.addChild(ufo!)
        ufoSpawnedThisLevel = true

        showUFOMessage("UFO INCOMING!", color: .yellow)
    }

    func showUFOMessage(_ text: String, color: SKColor) {
        ufoMessageLabel?.removeFromParent()

        let cameraScale = gameCamera.xScale

        ufoMessageLabel = SKLabelNode(text: text)
        ufoMessageLabel?.fontName = "Helvetica-Bold"
        ufoMessageLabel?.fontSize = 28 * cameraScale
        ufoMessageLabel?.fontColor = color
        ufoMessageLabel?.position = CGPoint(x: 0, y: 80 * cameraScale)
        ufoMessageLabel?.zPosition = 150
        gameCamera.addChild(ufoMessageLabel!)

        ufoMessageTimer = GameConstants.ufoMessageDuration
    }

    private func updateEasterEgg() {
        guard let egg = easterEgg else { return }

        egg.update()

        if egg.isExpired {
            egg.removeFromParent()
            easterEgg = nil
        }
    }

    /// Try to spawn gold power-up (Gzhel mode only, once per level)
    private func updateGoldSpawn() {
        // Only spawn in Gzhel mode, once per level, and not during victory
        guard showGzhelBorder && !goldSpawnedThisLevel && victoryDelayTimer == 0 else { return }

        // Wait a bit before gold can spawn (at least 5 seconds into level)
        goldSpawnTimer += 1
        guard goldSpawnTimer > 300 else { return }  // 5 seconds at 60fps

        // Random chance to spawn gold
        if Double.random(in: 0...1) < goldSpawnChance {
            spawnGold()
        }
    }

    /// Spawn gold power-up at random empty position
    private func spawnGold() {
        goldSpawnedThisLevel = true
        let position = findRandomEmptyPosition()
        let gold = PowerUp(position: position, type: .gold)
        powerUps.append(gold)
        gameLayer.addChild(gold)
        showEffect(text: "GOLD!", color: .yellow)
        SoundManager.shared.playPowerUpSpawn()
    }

    // MARK: - Collision Detection

    private func checkCollisions() {
        // Bullet collisions are handled in GameScene+Collision extension
        checkAllCollisions()
        checkPowerUpCollisions()
        checkEasterEggCollisions()
    }

    private func checkEasterEggCollisions() {
        guard let egg = easterEgg, !egg.isCollected else { return }

        // Check player collision
        if playerTank.isAlive && egg.collidesWith(playerTank) {
            // Player collected the easter egg!
            egg.collect()
            easterEgg = nil
            playerCollectedEasterEgg = true

            // Give player 3 extra lives
            playerTank.addLives(GameConstants.easterEggLivesBonus)

            // Turn all enemies into POWER (rainbow) tanks
            for enemy in enemyTanks where enemy.isAlive && enemy.enemyType != .boss {
                enemy.convertToType(.power)
            }

            showEffect(text: "+3 LIVES!", color: .green)
            showUFOMessage("EASTER EGG!", color: .magenta)
            return
        }

        // Check enemy collision
        for enemy in enemyTanks {
            if enemy.isAlive && egg.collidesWith(enemy) {
                // Enemy collected the easter egg!
                egg.collect()
                easterEgg = nil

                // Turn all enemies into HEAVY (black) tanks
                for otherEnemy in enemyTanks where otherEnemy.isAlive && otherEnemy.enemyType != .boss {
                    otherEnemy.convertToType(.heavy)
                }

                showUFOMessage("ENEMIES POWERED UP!", color: .red)
                return
            }
        }
    }

    private func checkPowerUpCollisions() {
        var powerUpsToRemove: [PowerUp] = []

        for powerUp in powerUps {
            // Check player collision
            let playerDx = abs(playerTank.position.x - powerUp.position.x)
            let playerDy = abs(playerTank.position.y - powerUp.position.y)
            let collisionDist = (playerTank.size.width + powerUp.size.width) / 2

            if playerDx < collisionDist && playerDy < collisionDist {
                handlePowerUpCollection(powerUp)
                powerUpsToRemove.append(powerUp)
                SoundManager.shared.playPowerUp()
                continue
            }

            // Check enemy collisions
            for enemy in enemyTanks {
                guard enemy.isAlive else { continue }
                let enemyDx = abs(enemy.position.x - powerUp.position.x)
                let enemyDy = abs(enemy.position.y - powerUp.position.y)
                let enemyCollisionDist = (enemy.size.width + powerUp.size.width) / 2

                if enemyDx < enemyCollisionDist && enemyDy < enemyCollisionDist {
                    handleEnemyPowerUpCollection(powerUp, enemy: enemy)
                    powerUpsToRemove.append(powerUp)
                    break
                }
            }
        }

        for powerUp in powerUpsToRemove {
            powerUp.removeFromParent()
            powerUps.removeAll { $0 === powerUp }
        }
    }

    private func handleEnemyPowerUpCollection(_ powerUp: PowerUp, enemy: Tank) {
        switch powerUp.type {
        case .shield:
            // Enemy gets upgraded tank type (NOT shield protection)
            upgradeEnemyTank(enemy)
        case .star:
            // Enemy shoots faster
            enemy.starCount += 1
            showEffect(text: "ENEMY POWERED!", color: .red)
        case .tank:
            // Spawn extra enemy
            enemySpawner.addExtraEnemy()
            showEffect(text: "EXTRA ENEMY!", color: .red)
        case .gun:
            // Enemy gets stronger bullets (can break steel)
            enemy.bulletPower = 2
            showEffect(text: "ENEMY GUN!", color: .red)
        case .car:
            // Enemy moves faster
            enemy.speedMultiplier = 1.5
            showEffect(text: "ENEMY FAST!", color: .red)
        case .ship:
            // Enemy can swim
            enemy.activateShip()
            showEffect(text: "ENEMY SHIP!", color: .red)
        case .machinegun:
            // Enemy shoots more bullets
            enemy.machinegunCount += 1
            showEffect(text: "ENEMY MACHINEGUN!", color: .red)
        case .freeze:
            // Freeze player for 30 seconds (can still shoot)
            playerFreezeTimer = GameConstants.freezeDuration
            addFreezeEffectToPlayer()
            showEffect(text: "PLAYER FROZEN!", color: .red)
        case .bomb:
            // Kills player instantly! Bypasses ship AND shield protection
            playerTank.damage(bypassShip: true, bypassShield: true)
            showEffect(text: "BOMB!", color: .red)
        case .shovel:
            // Enemy removes base protection
            removeBaseProtection()
            showEffect(text: "BASE EXPOSED!", color: .red)
        case .saw:
            // Enemy can break forest
            enemy.canDestroyTrees = true
            showEffect(text: "ENEMY SAW!", color: .red)
        case .gold:
            // Major upgrade based on current type
            handleEnemyGoldCollection(enemy)
        }
    }

    /// Handle enemy collecting gold - major upgrade
    private func handleEnemyGoldCollection(_ enemy: Tank) {
        switch enemy.enemyType {
        case .power:
            // Power tank → Heavy tank
            enemy.convertToType(.heavy)
            showEffect(text: "GOLD HEAVY!", color: .red)
        case .heavy:
            // Heavy tank → gets speed + machinegun + ship (ultimate form)
            enemy.speedMultiplier = 1.8
            enemy.machinegunCount = 2
            enemy.activateShip()
            showEffect(text: "GOLD ULTIMATE!", color: .red)
        default:
            // Regular/fast/armored → Power tank
            enemy.convertToType(.power)
            showEffect(text: "GOLD POWER!", color: .red)
        }
    }

    /// Upgrade enemy tank type when collecting shield power-up
    private func upgradeEnemyTank(_ enemy: Tank) {
        switch enemy.enemyType {
        case .regular:
            // Regular → Armored (2 hits)
            enemy.convertToType(.armored)
            showEffect(text: "ENEMY ARMORED!", color: .red)
        case .armored:
            // Armored → Heavy (3 hits, bulletPower 2)
            enemy.convertToType(.heavy)
            showEffect(text: "ENEMY HEAVY!", color: .red)
        case .fast:
            // Fast → Armored but keep extra speed
            let savedSpeed = enemy.moveSpeed
            enemy.convertToType(.armored)
            enemy.moveSpeed = savedSpeed  // Keep the fast speed
            showEffect(text: "FAST ARMORED!", color: .red)
        case .power:
            // Power → 3 shots instead of 2
            enemy.health = 3
            enemy.maxHealth = 3
            showEffect(text: "POWER TANK+!", color: .red)
        case .heavy, .boss:
            // Already at max, just heal
            enemy.health = enemy.maxHealth
            showEffect(text: "ENEMY HEALED!", color: .red)
        }
    }

    /// Add freeze visual effect to player
    private func addFreezeEffectToPlayer() {
        // Remove any existing freeze effect
        playerTank.childNode(withName: "freezeEffect")?.removeFromParent()

        let freezeNode = SKNode()
        freezeNode.name = "freezeEffect"

        // Ice crystals around the tank
        for i in 0..<8 {
            let angle = CGFloat(i) * .pi / 4
            let crystal = SKShapeNode(rectOf: CGSize(width: 4, height: 8))
            crystal.fillColor = SKColor.cyan.withAlphaComponent(0.7)
            crystal.strokeColor = .white
            crystal.lineWidth = 1
            crystal.position = CGPoint(
                x: cos(angle) * playerTank.size.width * 0.5,
                y: sin(angle) * playerTank.size.height * 0.5
            )
            crystal.zRotation = angle
            freezeNode.addChild(crystal)
        }

        // Pulsing animation
        let pulse = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.3),
            SKAction.scale(to: 0.9, duration: 0.3)
        ])
        freezeNode.run(SKAction.repeatForever(pulse))

        playerTank.addChild(freezeNode)

        // Schedule removal when freeze ends
        run(SKAction.sequence([
            SKAction.wait(forDuration: 30.0),
            SKAction.run { [weak self] in
                self?.playerTank.childNode(withName: "freezeEffect")?.removeFromParent()
            }
        ]))
    }

    private func handlePowerUpCollection(_ powerUp: PowerUp) {
        // Gold gives 99 points, others give 1
        if powerUp.type == .gold {
            addScore(99)
            showEffect(text: "+99 GOLD!", color: .yellow)
            return
        }

        addScore(1)

        switch powerUp.type {
        case .freeze:
            // Freeze enemies for 30 seconds with animation
            freezeTimer = GameConstants.freezeDuration
            addFreezeEffectToEnemies()
            showEffect(text: "FREEZE!", color: .cyan)
        case .bomb:
            destroyAllEnemies()
            showEffect(text: "BOMB!", color: .red)
        case .shovel:
            // Base gets steel protection for 60 seconds
            activateBaseProtection()
            showEffect(text: "STEEL BASE!", color: .white)
        case .saw:
            // Player can break forest
            playerTank.canDestroyTrees = true
            showEffect(text: "SAW!", color: .green)
        default:
            powerUp.apply(to: playerTank)
        }
    }

    /// Add freeze visual effect to all enemies
    private func addFreezeEffectToEnemies() {
        for enemy in enemyTanks where enemy.isAlive {
            // Remove any existing freeze effect
            enemy.childNode(withName: "freezeEffect")?.removeFromParent()

            let freezeNode = SKNode()
            freezeNode.name = "freezeEffect"

            // Ice crystals around the tank
            for i in 0..<6 {
                let angle = CGFloat(i) * .pi / 3
                let crystal = SKShapeNode(rectOf: CGSize(width: 3, height: 6))
                crystal.fillColor = SKColor.cyan.withAlphaComponent(0.7)
                crystal.strokeColor = .white
                crystal.lineWidth = 1
                crystal.position = CGPoint(
                    x: cos(angle) * enemy.size.width * 0.45,
                    y: sin(angle) * enemy.size.height * 0.45
                )
                crystal.zRotation = angle
                freezeNode.addChild(crystal)
            }

            // Pulsing animation
            let pulse = SKAction.sequence([
                SKAction.scale(to: 1.1, duration: 0.3),
                SKAction.scale(to: 0.9, duration: 0.3)
            ])
            freezeNode.run(SKAction.repeatForever(pulse))

            enemy.addChild(freezeNode)
        }

        // Schedule removal when freeze ends
        run(SKAction.sequence([
            SKAction.wait(forDuration: 30.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }
                for enemy in self.enemyTanks {
                    enemy.childNode(withName: "freezeEffect")?.removeFromParent()
                }
            }
        ]), withKey: "removeFreezeEffect")
    }

    private func destroyAllEnemies() {
        for enemy in enemyTanks {
            if enemy.isAlive {
                // No score or kill credit for bomb kills
                // Force kill - keep damaging until dead (for heavy tanks with multiple health)
                while enemy.isAlive {
                    enemy.damage(bypassShip: true, bypassShield: true)
                }
            }
            // Remove from scene
            enemy.removeFromParent()
        }
        enemyTanks.removeAll()
        invalidateAllTanksCache()
    }

    // MARK: - Base Protection

    /// Activate steel protection around base for 60 seconds
    private func activateBaseProtection() {
        baseProtectionTimer = GameConstants.baseProtectionTime
        baseFlashTimer = 0
        baseIsSteel = true
        gameMap.setBaseProtection(steel: true)
    }

    /// Remove base protection (when enemy gets shovel)
    private func removeBaseProtection() {
        baseProtectionTimer = 0
        baseFlashTimer = 0
        baseIsSteel = false
        gameMap.setBaseProtection(steel: false)
        gameMap.clearBaseProtection()  // Remove bricks entirely
    }

    /// Update base protection timer and handle flashing transition
    private func updateBaseProtection() {
        guard baseProtectionTimer > 0 else { return }

        baseProtectionTimer -= 1

        // Last 3 seconds (180 frames): flash between steel and brick
        if baseProtectionTimer <= 180 && baseProtectionTimer > 0 {
            baseFlashTimer += 1
            // Flash every 15 frames (0.25 seconds)
            if baseFlashTimer >= 15 {
                baseFlashTimer = 0
                baseIsSteel = !baseIsSteel
                gameMap.setBaseProtection(steel: baseIsSteel)
            }
        }

        // When timer expires, return to brick
        if baseProtectionTimer == 0 {
            baseIsSteel = false
            gameMap.setBaseProtection(steel: false)
        }
    }

    func spawnPowerUp(at position: CGPoint) {
        // Find random empty position instead of spawning at enemy location
        let spawnPosition = findRandomEmptyPosition()
        let powerUp = PowerUp(position: spawnPosition)
        powerUps.append(powerUp)
        gameLayer.addChild(powerUp)
        SoundManager.shared.playPowerUpSpawn()
    }

    func findRandomEmptyPosition() -> CGPoint {
        let tileSize = GameConstants.tileSize

        // First, collect all empty positions
        var emptyPositions: [CGPoint] = []

        for row in 2..<24 {
            for col in 2..<24 {
                let position = CGPoint(
                    x: CGFloat(col) * tileSize + tileSize / 2,
                    y: CGFloat(GameConstants.mapHeight - 1 - row) * tileSize + tileSize / 2
                )

                if gameMap.getTile(at: position) == .empty {
                    emptyPositions.append(position)
                }
            }
        }

        // Return random empty position, or center of map if none found
        if let randomPosition = emptyPositions.randomElement() {
            return randomPosition
        }

        // Fallback - should rarely happen
        return CGPoint(
            x: 13 * tileSize + tileSize / 2,
            y: 13 * tileSize + tileSize / 2
        )
    }

    private func showEffect(text: String, color: SKColor) {
        let cameraScale = gameCamera.xScale

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 32 * cameraScale
        label.fontColor = color
        label.position = CGPoint(x: 0, y: 50 * cameraScale)
        label.zPosition = 150
        gameCamera.addChild(label)

        let fadeOut = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ])
        label.run(fadeOut)
    }

    func removeBullet(_ bullet: Bullet, hitObstacle: Bool = false) {
        bullet.owner?.bulletDestroyed(hitObstacle: hitObstacle)
        bullet.removeFromParent()
        // Mark for batch removal instead of O(n) removeAll per bullet
        bulletsMarkedForRemoval.insert(ObjectIdentifier(bullet))
    }

    /// Remove all marked bullets in one pass (O(n) total instead of O(n) per bullet)
    private func flushBulletRemovals() {
        guard !bulletsMarkedForRemoval.isEmpty else { return }
        bullets.removeAll { bulletsMarkedForRemoval.contains(ObjectIdentifier($0)) }
        bulletsMarkedForRemoval.removeAll()
    }

    // MARK: - Game State

    private func checkGameState() {
        // Check win condition - start 5 second delay for power-up collection
        if enemySpawner.allEnemiesDefeated(currentEnemies: enemyTanks) && victoryDelayTimer == 0 && !isGameOver {
            victoryDelayTimer = GameConstants.victoryDelay
            showEffect(text: "VICTORY! Collect power-ups!", color: .green)
        }

        // Check lose condition
        if playerTank.lives <= 0 && !playerTank.isAlive {
            gameOver(won: false)
        }
    }

    private func levelComplete() {
        isGameOver = true
        didWinLevel = true
        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.playVictory()

        // Reset consecutive losses on win (exits easy mode)
        GameScene.consecutiveLosses = 0

        showScoreBreakdown(title: "LEVEL COMPLETE!", titleColor: .green, showRestart: false)

        // Victory animations
        if alienMode {
            // Alien gets picked up by UFO and flies away
            let flyAwayPosition = CGPoint(
                x: base.position.x,
                y: base.position.y + GameConstants.tileSize * 5
            )
            base.playAlienVictoryAnimation(to: flyAwayPosition)
        } else if playerCollectedEasterEgg {
            // Cat plays with toy!
            let playPosition = CGPoint(
                x: base.position.x,
                y: base.position.y + GameConstants.tileSize * 3
            )
            base.playVictoryAnimation(to: playPosition)
        }
    }

    private var pauseOverlay: SKNode?

    private func togglePause() {
        isGamePaused = !isGamePaused

        if isGamePaused {
            // Show pause overlay
            let cameraScale = gameCamera.xScale

            pauseOverlay = SKNode()
            pauseOverlay?.zPosition = 200

            // Dark background
            let background = SKShapeNode(rectOf: CGSize(width: 2000, height: 2000))
            background.fillColor = SKColor.black.withAlphaComponent(0.7)
            background.strokeColor = .clear
            background.name = "pauseBackground"
            pauseOverlay?.addChild(background)

            // Pause text
            let pauseLabel = SKLabelNode(text: "PAUSED")
            pauseLabel.fontName = "Helvetica-Bold"
            pauseLabel.fontSize = 48 * cameraScale
            pauseLabel.fontColor = .white
            pauseLabel.position = CGPoint(x: 0, y: 50 * cameraScale)
            pauseOverlay?.addChild(pauseLabel)

            // Resume button
            let resumeButton = createPauseButton(text: "RESUME", cameraScale: cameraScale)
            resumeButton.position = CGPoint(x: 0, y: -10 * cameraScale)
            resumeButton.name = "resumeButton"
            pauseOverlay?.addChild(resumeButton)

            // Menu button
            let menuButton = createPauseButton(text: "MENU", cameraScale: cameraScale)
            menuButton.position = CGPoint(x: 0, y: -70 * cameraScale)
            menuButton.name = "menuButton"
            pauseOverlay?.addChild(menuButton)

            gameCamera.addChild(pauseOverlay!)
        } else {
            // Remove pause overlay
            pauseOverlay?.removeFromParent()
            pauseOverlay = nil
        }
    }

    private func createPauseButton(text: String, cameraScale: CGFloat) -> SKNode {
        let container = SKNode()

        let background = SKShapeNode(rectOf: CGSize(width: 180 * cameraScale, height: 45 * cameraScale), cornerRadius: 8 * cameraScale)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)

        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 22 * cameraScale
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    func gameOver(won: Bool) {
        isGameOver = true
        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.playGameOver()

        // Track consecutive losses for easy mode
        GameScene.consecutiveLosses += 1

        showScoreBreakdown(title: "GAME OVER", titleColor: .red, showRestart: true)
    }

    /// Show score breakdown screen with tank kill stats
    private func showScoreBreakdown(title: String, titleColor: SKColor, showRestart: Bool) {
        let cameraScale = gameCamera.xScale
        let lineHeight: CGFloat = 28 * cameraScale
        var yPos: CGFloat = 140 * cameraScale

        // Level number at the top
        let levelLabel = SKLabelNode(text: "Level \(level)")
        levelLabel.fontName = "Helvetica-Bold"
        levelLabel.fontSize = 28 * cameraScale
        levelLabel.fontColor = .white
        levelLabel.position = CGPoint(x: 0, y: yPos)
        levelLabel.zPosition = 200
        gameCamera.addChild(levelLabel)
        yPos -= lineHeight * 1.5

        // Title (GAME OVER or LEVEL COMPLETE)
        let titleLabel = SKLabelNode(text: title)
        titleLabel.fontName = "Helvetica-Bold"
        titleLabel.fontSize = 36 * cameraScale
        titleLabel.fontColor = titleColor
        titleLabel.position = CGPoint(x: 0, y: yPos)
        titleLabel.zPosition = 200
        gameCamera.addChild(titleLabel)
        yPos -= lineHeight * 1.5

        // Kill breakdown for each enemy type (only show types with kills)
        let enemyTypes: [Tank.EnemyType] = [.regular, .fast, .armored, .power, .heavy, .boss]
        for type in enemyTypes {
            let count = killsByType[type] ?? 0
            if count > 0 {
                let points = GameConstants.scoreForEnemyType(type) * count
                let row = createKillRow(enemyType: type, count: count, points: points, cameraScale: cameraScale)
                row.position = CGPoint(x: 0, y: yPos)
                row.zPosition = 200
                gameCamera.addChild(row)
                yPos -= lineHeight
            }
        }

        // Separator line
        yPos -= lineHeight * 0.3
        let separator = SKShapeNode(rectOf: CGSize(width: 200 * cameraScale, height: 2 * cameraScale))
        separator.fillColor = .white
        separator.strokeColor = .clear
        separator.position = CGPoint(x: 0, y: yPos)
        separator.zPosition = 200
        gameCamera.addChild(separator)
        yPos -= lineHeight * 0.8

        // Round score
        let roundScore = score - levelStartScore
        let roundScoreLabel = SKLabelNode(text: "Round Score: \(roundScore)")
        roundScoreLabel.fontName = "Helvetica-Bold"
        roundScoreLabel.fontSize = 20 * cameraScale
        roundScoreLabel.fontColor = .yellow
        roundScoreLabel.position = CGPoint(x: 0, y: yPos)
        roundScoreLabel.zPosition = 200
        gameCamera.addChild(roundScoreLabel)
        yPos -= lineHeight

        // Total score
        let totalScoreLabel = SKLabelNode(text: "Total Score: \(score)")
        totalScoreLabel.fontName = "Helvetica-Bold"
        totalScoreLabel.fontSize = 22 * cameraScale
        totalScoreLabel.fontColor = .cyan
        totalScoreLabel.position = CGPoint(x: 0, y: yPos)
        totalScoreLabel.zPosition = 200
        gameCamera.addChild(totalScoreLabel)
        yPos -= lineHeight

        // Highscore check (only on game over, not level complete)
        if showRestart && score > GameScene.highScore {
            GameScene.highScore = score

            let highScoreLabel = SKLabelNode(text: "HIGHSCORE \(score)")
            highScoreLabel.fontName = "Helvetica-Bold"
            highScoreLabel.fontSize = 26 * cameraScale
            highScoreLabel.fontColor = .magenta
            highScoreLabel.position = CGPoint(x: 0, y: yPos)
            highScoreLabel.zPosition = 200
            gameCamera.addChild(highScoreLabel)

            // Blinking animation
            let fadeOut = SKAction.fadeAlpha(to: 0.2, duration: 0.3)
            let fadeIn = SKAction.fadeAlpha(to: 1.0, duration: 0.3)
            let blink = SKAction.sequence([fadeOut, fadeIn])
            highScoreLabel.run(SKAction.repeatForever(blink))

            yPos -= lineHeight
        }
        yPos -= lineHeight * 0.5

        // Buttons
        if showRestart {
            let restartButton = createPauseButton(text: "RESTART", cameraScale: cameraScale)
            restartButton.position = CGPoint(x: 0, y: yPos)
            restartButton.zPosition = 200
            restartButton.name = "restartButton"
            gameCamera.addChild(restartButton)
            yPos -= 60 * cameraScale
        } else {
            let nextButton = createPauseButton(text: "NEXT LEVEL", cameraScale: cameraScale)
            nextButton.position = CGPoint(x: 0, y: yPos)
            nextButton.zPosition = 200
            nextButton.name = "nextLevelButton"
            gameCamera.addChild(nextButton)
            yPos -= 60 * cameraScale
        }

        let menuButton = createPauseButton(text: "MENU", cameraScale: cameraScale)
        menuButton.position = CGPoint(x: 0, y: yPos)
        menuButton.zPosition = 200
        menuButton.name = "menuButton"
        gameCamera.addChild(menuButton)
    }

    /// Create a row showing: [tank icon] x [count] : [points]
    private func createKillRow(enemyType: Tank.EnemyType, count: Int, points: Int, cameraScale: CGFloat) -> SKNode {
        let container = SKNode()
        let iconSize: CGFloat = 20 * cameraScale

        // Tank icon
        let tankIcon = createMiniTankIcon(type: enemyType, size: iconSize)
        tankIcon.position = CGPoint(x: -80 * cameraScale, y: 0)
        container.addChild(tankIcon)

        // "x count"
        let countLabel = SKLabelNode(text: "× \(count)")
        countLabel.fontName = "Helvetica-Bold"
        countLabel.fontSize = 16 * cameraScale
        countLabel.fontColor = .white
        countLabel.horizontalAlignmentMode = .left
        countLabel.verticalAlignmentMode = .center
        countLabel.position = CGPoint(x: -50 * cameraScale, y: 0)
        container.addChild(countLabel)

        // ": points"
        let pointsLabel = SKLabelNode(text: ": \(points)")
        pointsLabel.fontName = "Helvetica-Bold"
        pointsLabel.fontSize = 16 * cameraScale
        pointsLabel.fontColor = .yellow
        pointsLabel.horizontalAlignmentMode = .left
        pointsLabel.verticalAlignmentMode = .center
        pointsLabel.position = CGPoint(x: 20 * cameraScale, y: 0)
        container.addChild(pointsLabel)

        return container
    }

    /// Create a mini tank icon for score breakdown
    private func createMiniTankIcon(type: Tank.EnemyType, size: CGFloat) -> SKNode {
        let container = SKNode()

        // Get color based on enemy type
        let color: SKColor
        switch type {
        case .regular:
            color = SKColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1.0)  // Silver
        case .fast:
            color = SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)  // Light blue
        case .armored:
            color = SKColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)  // Green
        case .power:
            color = SKColor(red: 1.0, green: 0.0, blue: 0.0, alpha: 1.0)  // Red (rainbow simplified)
        case .heavy:
            color = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)  // Dark gray
        case .boss:
            color = SKColor(red: 0.5, green: 0.0, blue: 0.5, alpha: 1.0)  // Purple
        }

        // Tank body
        let body = SKShapeNode(rectOf: CGSize(width: size * 0.6, height: size * 0.5))
        body.fillColor = color
        body.strokeColor = .clear
        container.addChild(body)

        // Tracks
        let trackW = size * 0.15
        let trackH = size * 0.7
        let leftTrack = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH))
        leftTrack.fillColor = color
        leftTrack.strokeColor = .clear
        leftTrack.position = CGPoint(x: -size * 0.35, y: 0)
        container.addChild(leftTrack)

        let rightTrack = SKShapeNode(rectOf: CGSize(width: trackW, height: trackH))
        rightTrack.fillColor = color
        rightTrack.strokeColor = .clear
        rightTrack.position = CGPoint(x: size * 0.35, y: 0)
        container.addChild(rightTrack)

        // Barrel
        let barrel = SKShapeNode(rectOf: CGSize(width: size * 0.15, height: size * 0.4))
        barrel.fillColor = color
        barrel.strokeColor = .clear
        barrel.position = CGPoint(x: 0, y: size * 0.35)
        container.addChild(barrel)

        return container
    }

    private func updateUI() {
        scoreLabel.text = "Score: \(score)"

        // Build power-up data from player tank
        var powerUps = Sidebar.PowerUpData()
        powerUps.starCount = playerTank.starCount
        powerUps.machinegunCount = playerTank.machinegunCount
        powerUps.hasGun = playerTank.bulletPower >= 2
        powerUps.hasShip = playerTank.canSwim
        powerUps.hasSaw = playerTank.canDestroyTrees
        // Calculate speed boosts (each 0.3 increment is one boost)
        powerUps.speedBoosts = Int((playerTank.speedMultiplier - 1.0) / 0.3)

        // Update sidebar with remaining enemies (not yet spawned)
        sidebar.update(
            remainingEnemies: enemySpawner.remainingEnemies,
            playerLives: playerTank.lives,
            level: level,
            powerUps: powerUps
        )
    }

    /// Add score and check for bonus life every 100 points
    func addScore(_ points: Int) {
        let oldMilestone = score / 100
        score += points
        let newMilestone = score / 100

        // Award bonus life for each 100-point milestone reached
        if newMilestone > oldMilestone {
            let bonusLives = newMilestone - oldMilestone
            playerTank.addLives(bonusLives)
            showEffect(text: "+\(bonusLives) LIFE!", color: .magenta)
        }
    }

    // MARK: - Helpers

    private var allTanks: [Tank] {
        if _allTanksDirty {
            _cachedAllTanks = [playerTank].compactMap { $0 } + enemyTanks
            _allTanksDirty = false
        }
        return _cachedAllTanks
    }

    func invalidateAllTanksCache() {
        _allTanksDirty = true
    }

    // MARK: - Touch Handling for Restart

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }

        // Handle pause menu buttons
        if isGamePaused {
            let location = touch.location(in: gameCamera)
            let nodes = gameCamera.nodes(at: location)

            for node in nodes {
                if node.name == "menuButton" || node.parent?.name == "menuButton" {
                    goToMenu()
                    return
                }
                if node.name == "resumeButton" || node.parent?.name == "resumeButton" {
                    togglePause()
                    return
                }
            }
            // Tap on background also resumes
            togglePause()
            return
        }

        // Handle game over buttons
        if isGameOver {
            let location = touch.location(in: gameCamera)
            let nodes = gameCamera.nodes(at: location)

            for node in nodes {
                if node.name == "menuButton" || node.parent?.name == "menuButton" {
                    goToMenu()
                    return
                }
                if node.name == "restartButton" || node.parent?.name == "restartButton" {
                    restartGame()
                    return
                }
                if node.name == "nextLevelButton" || node.parent?.name == "nextLevelButton" {
                    nextLevel()
                    return
                }
            }

            // Tap anywhere else - next level if won, restart if lost
            if didWinLevel {
                nextLevel()
            } else {
                restartGame()
            }
            return
        }
    }

    private func nextLevel() {
        // Keep same session seed for consistent level generation within this game session
        // Carry over player's lives and power-ups to next level
        var powerUps = PlayerPowerUps()
        powerUps.starCount = playerTank.starCount
        powerUps.machinegunCount = playerTank.machinegunCount
        powerUps.bulletPower = playerTank.bulletPower
        powerUps.speedMultiplier = playerTank.speedMultiplier
        powerUps.canSwim = playerTank.canSwim
        powerUps.canDestroyTrees = playerTank.canDestroyTrees

        // If player collected easter egg and cat played, next level gets Gzhel decoration (one level only)
        let earnedGzhel = playerCollectedEasterEgg

        // If UFO escaped this level, next level has alien at base (only one level, then back to cat)
        // If currently in alien mode, alien leaves so next level is normal
        // UFO escaped if: it spawned this level AND wasn't killed (still alive or escaped earlier)
        let ufoEscaped = ufoEscapedThisLevel || (ufoSpawnedThisLevel && !ufoWasKilled)
        let nextAlienMode = ufoEscaped && !alienMode

        let newScene = GameScene(size: size, level: level + 1, score: score, lives: playerTank.lives, sessionSeed: sessionSeed, powerUps: powerUps, gzhelBorder: earnedGzhel, alienMode: nextAlienMode)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func restartGame() {
        // Restart the SAME level with score reset to 0 (high score persists until menu or app close)
        let newScene = GameScene(size: size, level: level, score: 0, sessionSeed: sessionSeed)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func goToMenu() {
        // Reset consecutive losses on menu (exits easy mode)
        GameScene.consecutiveLosses = 0
        // Reset high score when going to menu
        GameScene.highScore = 250

        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.stopBackgroundMusic()
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = scaleMode
        view?.presentScene(menuScene, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Keyboard Support

    #if os(iOS) || os(tvOS)
    // iOS keyboard support (hardware keyboard / simulator)
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }

            switch key.keyCode {
            // Arrow keys
            case .keyboardUpArrow, .keyboardW:
                pressedDirectionKeys.insert(key.keyCode)
                keyboardDirection = .up
            case .keyboardDownArrow, .keyboardS:
                pressedDirectionKeys.insert(key.keyCode)
                keyboardDirection = .down
            case .keyboardLeftArrow, .keyboardA:
                pressedDirectionKeys.insert(key.keyCode)
                keyboardDirection = .left
            case .keyboardRightArrow, .keyboardD:
                pressedDirectionKeys.insert(key.keyCode)
                keyboardDirection = .right

            // Fire: Space or J
            case .keyboardSpacebar, .keyboardJ:
                keyboardFiring = true

            // Pause: Escape or P
            case .keyboardEscape, .keyboardP:
                if !isGameOver {
                    togglePause()
                }

            // Continue/restart on Enter when game over
            case .keyboardReturnOrEnter:
                if isGameOver {
                    if didWinLevel {
                        nextLevel()
                    } else {
                        restartGame()
                    }
                }

            default:
                break
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }

            switch key.keyCode {
            // Direction keys
            case .keyboardUpArrow, .keyboardDownArrow, .keyboardLeftArrow, .keyboardRightArrow,
                 .keyboardW, .keyboardS, .keyboardA, .keyboardD:
                pressedDirectionKeys.remove(key.keyCode)
                keyboardDirection = getDirectionFromPressedKeys()

            // Fire: Space or J
            case .keyboardSpacebar, .keyboardJ:
                keyboardFiring = false

            default:
                break
            }
        }
    }

    private func getDirectionFromPressedKeys() -> Direction? {
        for keyCode in pressedDirectionKeys {
            switch keyCode {
            case .keyboardUpArrow, .keyboardW:
                return .up
            case .keyboardDownArrow, .keyboardS:
                return .down
            case .keyboardLeftArrow, .keyboardA:
                return .left
            case .keyboardRightArrow, .keyboardD:
                return .right
            default:
                continue
            }
        }
        return nil
    }

    #elseif os(macOS)
    // macOS keyboard support
    // Key codes for macOS
    private static let keyW: UInt16 = 13
    private static let keyA: UInt16 = 0
    private static let keyS: UInt16 = 1
    private static let keyD: UInt16 = 2
    private static let keyJ: UInt16 = 38
    private static let keyUp: UInt16 = 126
    private static let keyDown: UInt16 = 125
    private static let keyLeft: UInt16 = 123
    private static let keyRight: UInt16 = 124
    private static let keySpace: UInt16 = 49
    private static let keyReturn: UInt16 = 36
    private static let keyEscape: UInt16 = 53
    private static let keyP: UInt16 = 35

    override func keyDown(with event: NSEvent) {
        // Ignore key repeat
        guard !event.isARepeat else { return }

        let keyCode = event.keyCode

        switch keyCode {
        // Arrow keys and WASD
        case GameScene.keyUp, GameScene.keyW:
            pressedDirectionKeys.insert(keyCode)
            keyboardDirection = .up
        case GameScene.keyDown, GameScene.keyS:
            pressedDirectionKeys.insert(keyCode)
            keyboardDirection = .down
        case GameScene.keyLeft, GameScene.keyA:
            pressedDirectionKeys.insert(keyCode)
            keyboardDirection = .left
        case GameScene.keyRight, GameScene.keyD:
            pressedDirectionKeys.insert(keyCode)
            keyboardDirection = .right

        // Fire: Space or J
        case GameScene.keySpace, GameScene.keyJ:
            keyboardFiring = true

        // Pause: P or Escape
        case GameScene.keyP, GameScene.keyEscape:
            togglePause()

        // Continue/restart on Enter when game over
        case GameScene.keyReturn:
            if isGameOver {
                if didWinLevel {
                    nextLevel()
                } else {
                    restartGame()
                }
            }

        default:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        let keyCode = event.keyCode

        switch keyCode {
        // Direction keys
        case GameScene.keyUp, GameScene.keyDown, GameScene.keyLeft, GameScene.keyRight,
             GameScene.keyW, GameScene.keyS, GameScene.keyA, GameScene.keyD:
            pressedDirectionKeys.remove(keyCode)
            keyboardDirection = getDirectionFromPressedKeys()

        // Fire: Space or J
        case GameScene.keySpace, GameScene.keyJ:
            keyboardFiring = false

        default:
            break
        }
    }

    private func getDirectionFromPressedKeys() -> Direction? {
        for keyCode in pressedDirectionKeys {
            switch keyCode {
            case GameScene.keyUp, GameScene.keyW:
                return .up
            case GameScene.keyDown, GameScene.keyS:
                return .down
            case GameScene.keyLeft, GameScene.keyA:
                return .left
            case GameScene.keyRight, GameScene.keyD:
                return .right
            default:
                continue
            }
        }
        return nil
    }
    #endif
}
