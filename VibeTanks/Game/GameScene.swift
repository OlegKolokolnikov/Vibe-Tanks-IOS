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
    var player2Tank: Tank?  // Two-player mode only

    /// Number of human players (1 or 2), chosen in the menu
    private(set) var playerCount: Int = 1
    var isTwoPlayer: Bool { playerCount == 2 }

    /// All player tanks, including dead ones waiting to respawn (or out of lives)
    var playerTanks: [Tank] {
        if let second = player2Tank {
            return [playerTank, second]
        }
        return [playerTank]
    }
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

    // Gzhel tank: an ally that hunts enemies. It appears on Gzhel levels, and if it survives
    // a level it comes back on the next ones until it is destroyed.
    var gzhelTank: Tank?

    /// Friend's state carried into the next level
    struct FriendCarry {
        var health: Int
        var maxHealth: Int
        var starCount: Int
        var machinegunCount: Int
        var bulletPower: Int
        var speedMultiplier: CGFloat
        var canSwim: Bool
        var canDestroyTrees: Bool
    }
    /// Friend who survived the previous level (appears shortly after this level starts)
    private var returningFriend: FriendCarry?
    private var friendLivesLabel: SKLabelNode?
    private var gzhelSpawnedThisLevel: Bool = false
    private var gzhelSpawnFrame: Int = 0      // Random frame when it tries to appear
    private var gzhelFrameCounter: Int = 0

    // UI
    var touchController: TouchController!
    var touchController2: TouchController?  // Player 2 (two-player mode, touch screens)
    var sidebar: Sidebar!
    var scoreLabel: SKLabelNode!

    // Game state
    /// Each player has their own score (indexed by playerNumber - 1)
    var scores: [Int] = [0, 0]
    /// Player 1's score (the only score in a one-player game)
    var score: Int { scores[0] }
    /// Best score among the players (high score check)
    private var bestScore: Int { scores.prefix(playerCount).max() ?? 0 }
    var level: Int = 1
    private var sessionSeed: UInt64 = 0
    var isGameOver: Bool = false
    var isGamePaused: Bool = false
    var didWinLevel: Bool = false

    // Level stats for score breakdown
    private var levelStartScores: [Int] = [0, 0]
    var killsByType: [Tank.EnemyType: Int] = [:]
    /// Kills per player (indexed by playerNumber - 1), for the two-player statistics
    var killsByPlayer: [[Tank.EnemyType: Int]] = [[:], [:]]

    /// Two-player level bonus: the player with more kills gets one random power-up
    private struct KillBonus {
        let playerIndex: Int
        let type: PowerUp.PowerUpType
    }

    // Freeze effect
    var freezeTimer: Int = 0
    /// Players frozen by an enemy freeze power-up, indexed by playerNumber - 1
    var playerFreezeTimers: [Int] = [0, 0]

    // Victory delay (5 seconds to collect remaining power-ups)
    private var victoryDelayTimer: Int = 0
    /// A bomb killed enemies this level (no soccer ball at the end; neither if a player died)
    private var bombUsedThisLevel = false
    /// Level-clear bonuses were put on the field (the level ends early once they are all taken)
    private var levelBonusesSpawned = false

    // Base protection
    var baseProtectionTimer: Int = 0
    var baseFlashTimer: Int = 0
    var baseIsSteel: Bool = false

    // Keyboard input (for simulator and macOS), indexed by playerNumber - 1.
    // Keys are set per player in Options → Controls (default P1 WASD + Space, P2 arrows + Enter).
    private var keyboardDirection: [Direction?] = [nil, nil]
    private var keyboardFiring: [Bool] = [false, false]
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
    private var initialLives2: Int = 3

    // Power-ups to carry across levels
    struct PlayerPowerUps {
        var starCount: Int = 0
        var machinegunCount: Int = 0
        var bulletPower: Int = 1
        var speedMultiplier: CGFloat = 1.0
        var canSwim: Bool = false
        var canDestroyTrees: Bool = false
        var laserRounds: Int = 0  // LASER: rounds left including the one being started
        var baseSpeedMultiplier: CGFloat = 1.0  // Soccer-ball start speed (until a new game)
        var bossFireBoost: Int = 0  // Faster shooting from defeated bosses (until a new game)
    }
    private var initialPowerUps = PlayerPowerUps()
    private var initialPowerUps2 = PlayerPowerUps()

    // Gzhel decoration (reward for cat victory)
    private var showGzhelBorder: Bool = false

    // Alien mode (when UFO escaped previous level - alien is at base instead of cat)
    private var alienMode: Bool = false
    private var ufoEscapedThisLevel: Bool = false  // Track if UFO escapes to trigger alien mode next level

    // Level initialization
    init(size: CGSize, level: Int = 1, score: Int = 0, lives: Int = 3, sessionSeed: UInt64 = 0, powerUps: PlayerPowerUps = PlayerPowerUps(), gzhelBorder: Bool = false, alienMode: Bool = false,
         playerCount: Int = 1, player2Lives: Int = 3, player2PowerUps: PlayerPowerUps = PlayerPowerUps(), player2Score: Int = 0,
         friend: FriendCarry? = nil) {
        self.returningFriend = friend
        self.level = level
        self.scores = [score, player2Score]
        self.initialLives = lives
        self.initialPowerUps = powerUps
        self.playerCount = playerCount == 2 ? 2 : 1
        self.initialLives2 = player2Lives
        self.initialPowerUps2 = player2PowerUps
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

        #if targetEnvironment(macCatalyst)
        // Listen for pause button from UIKit overlay
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handlePauseRequest),
            name: .gamePauseRequested,
            object: nil
        )
        #endif

        // Auto-pause when the app goes to the background (call, notification center, app switch)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )

        // Play intro sound when game starts
        SoundManager.shared.playIntro()
    }

    #if targetEnvironment(macCatalyst)
    @objc private func handlePauseRequest() {
        if !isGameOver {
            togglePause()
        }
    }
    #endif

    @objc private func handleWillResignActive() {
        // Drop any held keys: their "ended" events may never arrive
        resetKeyboardInput()
        if !isGameOver && !isGamePaused {
            togglePause()
        }
    }

    private func resetKeyboardInput() {
        pressedDirectionKeys.removeAll()
        keyboardDirection = [nil, nil]
        keyboardFiring = [false, false]
    }

    override func willMove(from view: SKView) {
        super.willMove(from: view)
        NotificationCenter.default.removeObserver(self)
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
        levelStartScores = scores
        killsByType = [:]
        killsByPlayer = [[:], [:]]

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
        gameMap = GameMap(level: level, seed: mapSeed, twoPlayers: isTwoPlayer)
        gameLayer.addChild(gameMap)

        // Create sidebar (on right side of game area)
        let mapSize = gameMap.pixelSize
        sidebar = Sidebar(height: mapSize.height, twoPlayers: isTwoPlayer)
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

        // Create player tanks (player 2 starts to the right of the base)
        playerTank = makePlayerTank(number: 1, lives: initialLives, powerUps: initialPowerUps)
        if isTwoPlayer {
            player2Tank = makePlayerTank(number: 2, lives: initialLives2, powerUps: initialPowerUps2)
        }

        // Calculate enemies for this level (easy mode: 18, normal: base 20 + 2 per level)
        let totalEnemies = GameScene.isEasyMode ? 18 : min(20 + (level - 1) * 2, 50)

        // Gzhel tank appears at a random moment, 10-40 seconds into the level
        if returningFriend != nil {
            gzhelSpawnFrame = 60  // The surviving friend rolls in a second after the start
        } else if showGzhelBorder {
            gzhelSpawnFrame = Int.random(in: 600...2400)
        }

        // Setup enemy spawner
        enemySpawner = EnemySpawner(
            totalEnemies: totalEnemies,
            maxOnScreen: GameConstants.maxEnemiesOnScreen,
            hasBoss: level % GameConstants.bossLevelInterval == 0
        )
    }

    /// Create a player tank with lives and power-ups carried from the previous level
    private func makePlayerTank(number: Int, lives: Int, powerUps: PlayerPowerUps) -> Tank {
        let tank = Tank(
            position: GameConstants.spawnPosition(forPlayer: number),
            direction: .up,
            isPlayer: true,
            playerNumber: number
        )
        tank.lives = lives  // Carry lives from previous level

        // Apply power-ups from previous level
        tank.starCount = powerUps.starCount
        tank.machinegunCount = powerUps.machinegunCount
        tank.bulletPower = powerUps.bulletPower
        tank.speedMultiplier = powerUps.speedMultiplier
        tank.canSwim = powerUps.canSwim
        tank.canDestroyTrees = powerUps.canDestroyTrees
        tank.laserRounds = powerUps.laserRounds
        tank.baseSpeedMultiplier = powerUps.baseSpeedMultiplier
        tank.bossFireBoost = powerUps.bossFireBoost

        // Always redraw tank to show power-up indicators
        tank.drawTank()

        // Two players: a player who ran out of lives stays out (a bonus life brings them back)
        if lives <= 0 {
            tank.health = 0
            tank.isHidden = true
        }

        gameLayer.addChild(tank)
        return tank
    }

    /// Carry a player's power-ups into the next level
    private func carriedPowerUps(of tank: Tank) -> PlayerPowerUps {
        var powerUps = PlayerPowerUps()
        powerUps.starCount = tank.starCount
        powerUps.machinegunCount = tank.machinegunCount
        powerUps.bulletPower = tank.bulletPower
        powerUps.speedMultiplier = tank.speedMultiplier
        powerUps.canSwim = tank.canSwim
        powerUps.canDestroyTrees = tank.canDestroyTrees
        powerUps.baseSpeedMultiplier = tank.baseSpeedMultiplier
        powerUps.bossFireBoost = tank.bossFireBoost
        // Laser only carries into one more round (and only if the player still has it)
        powerUps.laserRounds = max(tank.laserRounds - 1, 0)
        return powerUps
    }

    private func setupUI() {
        // Get the camera scale to properly size UI elements
        let cameraScale = gameCamera.xScale

        let visibleSize = CGSize(width: size.width * cameraScale, height: size.height * cameraScale)

        #if targetEnvironment(macCatalyst)
        // On Mac, don't show touch controls or in-game score (use UIKit overlay instead)
        touchController = TouchController()  // Create but don't add to scene
        #else
        // Touch controller - add to camera so it stays on screen
        // Use the visible screen size in camera coordinates
        touchController = TouchController()
        touchController.setupForScreen(size: visibleSize, layout: isTwoPlayer ? .leftPlayer : .single,
                                       firePlacement: GameSettings.shared.firePlacement(player: 0))
        touchController.setGzhelMode(showGzhelBorder)
        gameCamera.addChild(touchController)

        if isTwoPlayer {
            // Player 1 holds the left edge, player 2 the right edge
            touchController.setPlayerMarker(text: "1P", color: GameSettings.shared.playerTankColor.color)
            let controller2 = TouchController()
            controller2.setupForScreen(size: visibleSize, layout: .rightPlayer,
                                       firePlacement: GameSettings.shared.firePlacement(player: 1))
            controller2.setGzhelMode(showGzhelBorder)
            controller2.setPlayerMarker(text: "2P", color: GameSettings.shared.player2TankColor.color)
            gameCamera.addChild(controller2)
            touchController2 = controller2
        }

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
        #endif

        // Freeze countdowns (shown on all platforms)
        setupFreezeLabels()

        // Initial sidebar update
        sidebar.update(
            remainingEnemies: enemySpawner.remainingEnemies,
            playerLives: playerTank.lives,
            player2Lives: player2Tank?.lives ?? 0,
            level: level
        )
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        // Check for pause button press (in two-player mode it's on player 2's controller)
        for controller in [touchController, touchController2].compactMap({ $0 }) where controller.pausePressed {
            controller.resetPausePressed()
            // Pause is meaningless on the game over / level complete screen
            if !isGameOver {
                togglePause()
            }
        }

        guard !isGameOver && !isGamePaused else { return }

        // Update freeze timer (enemies frozen). Visual effect is removed in sync
        // with the frame-based timer, so pausing keeps them consistent.
        if freezeTimer > 0 {
            freezeTimer -= 1
            if freezeTimer == 0 {
                for enemy in enemyTanks {
                    enemy.childNode(withName: "freezeEffect")?.removeFromParent()
                }
            }
        }

        // Update player freeze timers
        for player in playerTanks {
            let index = player.playerNumber - 1
            if playerFreezeTimers[index] > 0 {
                playerFreezeTimers[index] -= 1
                if playerFreezeTimers[index] == 0 {
                    player.childNode(withName: "freezeEffect")?.removeFromParent()
                }
            }
        }

        // Update victory delay timer (5 seconds to collect power-ups)
        if victoryDelayTimer > 0 {
            victoryDelayTimer -= 1
            if victoryDelayTimer == 0 {
                levelComplete()
                return
            }
            // Every bonus item taken: no need to wait the full time
            if levelBonusesSpawned, victoryDelayTimer > 90, !powerUps.contains(where: { $0.type.isLevelBonus }) {
                victoryDelayTimer = 90
            }
        }

        // Update base protection timer
        updateBaseProtection()

        updatePlayers()
        updateEnemies()
        updateBossHealthBar()
        updateGzhelSpawn()
        updateGzhelTank()
        updateBullets()
        flushBulletRemovals()  // Bullets that hit walls must not also hit tanks this frame
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

    private func updatePlayers() {
        for player in playerTanks {
            updatePlayer(player)
        }
    }

    /// Movement and fire input for a player: its touch controller and/or keyboard keys
    private func input(for player: Tank) -> (direction: Direction?, firing: Bool) {
        let index = player.playerNumber - 1
        let controller = player.playerNumber == 2 ? touchController2 : touchController
        let direction = controller?.currentDirection ?? keyboardDirection[index]
        let firing = (controller?.isFiring ?? false) || keyboardFiring[index]
        return (direction, firing)
    }

    /// Fire held last frame, per player (to react to a new press only)
    private var firingLastFrame: [Bool] = [false, false]

    /// The other player of a two-player game
    private func teammate(of player: Tank) -> Tank? {
        guard isTwoPlayer else { return nil }
        return player.playerNumber == 1 ? player2Tank : playerTank
    }

    /// Two players: a player who is out of lives can take one from a teammate who has a spare
    private func canStealLife(_ player: Tank) -> Bool {
        guard let mate = teammate(of: player) else { return false }
        return player.lives <= 0 && !player.isAlive && !player.isWaitingToRespawn && mate.lives >= 2
    }

    private func stealLife(for player: Tank) {
        guard let mate = teammate(of: player), canStealLife(player) else { return }
        mate.lives -= 1
        player.lives = 1  // Respawn starts on the next update
        showEffect(text: "\(player.playerNumber)P TOOK A LIFE!", color: Tank.colorForPlayer(player.playerNumber))
        SoundManager.shared.playPowerUp()
    }

    private func updatePlayer(_ player: Tank) {
        let index = player.playerNumber - 1
        let firingNow = input(for: player).firing
        let firePressed = firingNow && !firingLastFrame[index]
        firingLastFrame[index] = firingNow

        guard player.isAlive else {
            // Out of lives: a new fire press takes a life from the teammate
            if player.lives <= 0 && firePressed {
                stealLife(for: player)
            }
            // Player is dead - handle respawn
            if player.lives > 0 {
                // If not already respawning, start respawn
                if !player.isWaitingToRespawn {
                    player.respawn(at: GameConstants.spawnPosition(forPlayer: player.playerNumber))
                }
                // Hold the last respawn tick while another tank sits on the spawn point;
                // respawning into an overlapping tank would lock both in place.
                if player.respawnTimer == 1 && isPlayerSpawnBlocked(for: player) {
                    return
                }
                player.updateRespawnTimer()
            }
            return
        }

        // Handle movement from touch controller or keyboard
        let (direction, firing) = input(for: player)
        if playerFreezeTimers[player.playerNumber - 1] <= 0 {
            // Normal movement
            if let dir = direction {
                player.move(direction: dir, map: gameMap, allTanks: allTanks)
            } else {
                // No input - continue ice slide if player was on ice
                _ = player.continueIceSlide(map: gameMap, allTanks: allTanks)
            }
        } else if (GameScene.isEasyMode || GameScene.isGzhelActive), let dir = direction {
            // Easy/gzhel mode: can turn while frozen (but not move)
            player.turn(to: dir)
        }

        // Check for forest destruction (SAW power-up)
        if player.canDestroyTrees {
            checkForestDestruction(for: player)
        }

        // Handle shooting from touch or keyboard (allowed even when frozen)
        if firing {
            let newBullets = player.shoot()
            if !newBullets.isEmpty {
                if player.hasLaser {
                    SoundManager.shared.playLaser()
                } else {
                    SoundManager.shared.playShoot()
                }
                addBulletsWithSpawnCheck(newBullets)
            }
        }

        player.update(map: gameMap, allTanks: allTanks)
    }

    private func updateEnemies() {
        for enemy in enemyTanks {
            guard enemy.isAlive else { continue }

            // Skip AI update if frozen (the alien is immune to freeze)
            if freezeTimer > 0 && !enemy.isFreezeImmune { continue }

            // Update AI
            if let ai = enemy.ai {
                let (direction, shouldShoot) = ai.update(
                    map: gameMap,
                    playerTanks: playerTanks,
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
                        if enemy.firesAlienLaser {
                            SoundManager.shared.playLaser()
                        } else {
                            SoundManager.shared.playShoot()
                        }
                        addBulletsWithSpawnCheck(newBullets)
                    }
                }
            }

            enemy.update(map: gameMap, allTanks: allTanks)
        }
    }

    /// True if any other living tank overlaps the player's spawn point
    private func isPlayerSpawnBlocked(for player: Tank) -> Bool {
        let spawn = GameConstants.spawnPosition(forPlayer: player.playerNumber)
        return allTanks.contains { tank in
            tank !== player && tank.isAlive &&
                EnemySpawner.boxesOverlap(spawn, player.size.width, tank.position, tank.size.width)
        }
    }

    // MARK: - Gzhel Tank

    /// Spawn the Gzhel tank once per Gzhel level at its random moment,
    /// or bring back the friend who survived the previous level
    private func updateGzhelSpawn() {
        guard showGzhelBorder || returningFriend != nil, !gzhelSpawnedThisLevel, victoryDelayTimer == 0 else { return }

        gzhelFrameCounter += 1
        guard gzhelFrameCounter >= gzhelSpawnFrame else { return }

        // Random empty tile, not on another tank and not right next to the player.
        // If none fits this frame, try again next frame.
        let size = GameConstants.tankSize
        for _ in 0..<20 {
            let pos = findRandomEmptyPosition()
            guard !gameMap.checkTankCollision(position: pos, size: size) else { continue }
            guard playerTanks.allSatisfy({ pos.distance(to: $0.position) > 120 }) else { continue }
            let blocked = allTanks.contains { $0.isAlive && EnemySpawner.boxesOverlap(pos, size, $0.position, $0.size.width) }
            guard !blocked else { continue }

            let tank = Tank(position: pos, direction: .up, isPlayer: false, playerNumber: 0, enemyType: .gzhel)
            if let carry = returningFriend {
                // Same friend as last level: keeps its remaining hits and upgrades.
                // Another Gzhel level heals it back to at least the full 3 hits (extra hearts are kept).
                let hits = showGzhelBorder ? max(carry.health, GameConstants.friendHits) : carry.health
                tank.health = hits
                tank.maxHealth = max(carry.maxHealth, hits)
                tank.starCount = carry.starCount
                tank.machinegunCount = carry.machinegunCount
                tank.bulletPower = carry.bulletPower
                tank.speedMultiplier = carry.speedMultiplier
                tank.canSwim = carry.canSwim
                tank.canDestroyTrees = carry.canDestroyTrees
                tank.drawTank()
            }
            gzhelTank = tank
            gzhelSpawnedThisLevel = true
            invalidateAllTanksCache()
            gameLayer.addChild(tank)
            showSpawnEffect(at: pos)
            showUFOMessage(returningFriend != nil ? "FRIEND IS BACK!" : "FRIEND!",
                           color: SKColor(red: 0.3, green: 0.55, blue: 1.0, alpha: 1.0))
            return
        }
    }

    /// Gzhel AI: same tank AI, but its targets are the enemies instead of the player
    private func updateGzhelTank() {
        guard let gzhel = gzhelTank, gzhel.isAlive, let ai = gzhel.ai else { return }

        let enemyBullets = bullets.filter { $0.isFromEnemy && !isBulletRemoved($0) }
        let (direction, shouldShoot) = ai.updateFriend(map: gameMap, enemies: enemyTanks, allTanks: allTanks,
                                                       enemyBullets: enemyBullets)

        if let dir = direction {
            gzhel.move(direction: dir, map: gameMap, allTanks: allTanks)
        }
        updateFriendLivesLabel()
        if shouldShoot {
            let newBullets = gzhel.shoot()
            if !newBullets.isEmpty {
                SoundManager.shared.playShoot()
                addBulletsWithSpawnCheck(newBullets)
            }
        }
        gzhel.update(map: gameMap, allTanks: allTanks)
    }

    /// The friend (Gzhel tank) leaves with a colorful farewell:
    /// when enemies have used up its hits (a friend that survives a level stays for the next one)
    func dismissGzhelTank(killed: Bool = false) {
        gzhelSpawnedThisLevel = true  // Appears only once per level
        guard let gzhel = gzhelTank else { return }
        gzhelTank = nil
        friendLivesLabel?.removeFromParent()
        friendLivesLabel = nil
        if killed {
            showUFOMessage("FRIEND LOST!", color: SKColor(red: 0.3, green: 0.55, blue: 1.0, alpha: 1.0))
        }
        gzhel.health = 0  // No longer blocks movement or bullets
        gzhel.ai = nil
        invalidateAllTanksCache()

        // Rainbow tint on the body while it spins, grows, then shrinks away
        let rainbow: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta]
        let tint = SKAction.sequence(rainbow.map { SKAction.colorize(with: $0, colorBlendFactor: 0.85, duration: 0.12) })
        gzhel.childNode(withName: "tankBody")?.run(SKAction.repeat(tint, count: 2))

        let spinAndPop = SKAction.group([
            SKAction.rotate(byAngle: .pi * 4, duration: 1.7),
            SKAction.sequence([
                SKAction.scale(to: 1.5, duration: 0.85),
                SKAction.scale(to: 0.1, duration: 0.85)
            ])
        ])
        let burst = SKAction.run { [weak self, weak gzhel] in
            guard let self = self, let gzhel = gzhel else { return }
            self.showConfettiBurst(at: gzhel.position)
        }
        gzhel.run(SKAction.sequence([spinAndPop, burst, SKAction.removeFromParent()]))
    }

    /// Hearts floating above the friend: one per remaining hit
    private func updateFriendLivesLabel() {
        guard let friend = gzhelTank, friend.isAlive else { return }
        let label: SKLabelNode
        if let existing = friendLivesLabel {
            label = existing
        } else {
            label = SKLabelNode(fontNamed: "Helvetica-Bold")
            label.fontSize = 10
            label.fontColor = SKColor(red: 0.35, green: 0.6, blue: 1.0, alpha: 1.0)
            label.verticalAlignmentMode = .bottom
            label.zPosition = 55
            gameLayer.addChild(label)
            friendLivesLabel = label
        }
        let hits = max(0, friend.health)
        let text = hits <= 5 ? String(repeating: "♥", count: hits) : "♥x\(hits)"
        if label.text != text { label.text = text }
        label.position = CGPoint(x: friend.position.x, y: friend.position.y + friend.size.height / 2 + 2)
    }

    /// Short flash when an enemy bullet hits the friend
    func flashFriendHit(_ friend: Tank) {
        friend.run(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.3, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08),
            SKAction.fadeAlpha(to: 0.3, duration: 0.08),
            SKAction.fadeAlpha(to: 1.0, duration: 0.08)
        ]))
        updateFriendLivesLabel()
    }

    /// The friend picked up a power-up: tank upgrades go to the friend itself,
    /// battlefield effects (freeze, bomb, shovel) work on the player's side. No score.
    private func handleFriendPowerUpCollection(_ powerUp: PowerUp, friend: Tank) {
        let friendBlue = SKColor(red: 0.3, green: 0.55, blue: 1.0, alpha: 1.0)
        switch powerUp.type {
        case .tank:
            friend.health += 1  // Extra life = one more hit
            friend.maxHealth += 1
            showEffect(text: "FRIEND +1 HIT!", color: friendBlue)
        case .freeze:
            freezeTimer = GameConstants.freezeDuration
            addFreezeEffectToEnemies()
            showEffect(text: "FREEZE!", color: .cyan)
        case .bomb:
            destroyAllEnemies()
            showEffect(text: "BOMB!", color: .red)
        case .shovel:
            activateBaseProtection()
            showEffect(text: "STEEL BASE!", color: .white)
        case .gold, .laser:
            break  // Gold is just taken away from the enemies; the laser is never picked up by the friend
        default:
            powerUp.apply(to: friend)
            friend.drawTank()
        }
        updateFriendLivesLabel()
    }

    // MARK: - Boss

    private var bossHealthBar: SKNode?

    /// Health bar floating above the boss (10 segments)
    private func updateBossHealthBar() {
        guard let boss = enemyTanks.first(where: { $0.isAlive && $0.enemyType == .boss }) else {
            bossHealthBar?.removeFromParent()
            bossHealthBar = nil
            return
        }
        let width: CGFloat = 34, height: CGFloat = 5
        let bar: SKNode
        if let existing = bossHealthBar {
            bar = existing
        } else {
            bar = SKNode()
            bar.zPosition = 55
            let back = SKSpriteNode(color: SKColor(white: 0.1, alpha: 0.85), size: CGSize(width: width + 2, height: height + 2))
            bar.addChild(back)
            let fill = SKSpriteNode(color: .red, size: CGSize(width: width, height: height))
            fill.anchorPoint = CGPoint(x: 0, y: 0.5)
            fill.position = CGPoint(x: -width / 2, y: 0)
            fill.name = "fill"
            bar.addChild(fill)
            gameLayer.addChild(bar)
            bossHealthBar = bar
        }
        let fraction = CGFloat(max(boss.health, 0)) / CGFloat(max(boss.maxHealth, 1))
        if let fill = bar.childNode(withName: "fill") as? SKSpriteNode {
            fill.size.width = width * fraction
            fill.color = fraction > 0.5 ? .red : (fraction > 0.2 ? .orange : .yellow)
        }
        bar.position = CGPoint(x: boss.position.x, y: boss.position.y + boss.size.height / 2 + 6)
    }

    /// The boss flashes white when hit
    func flashBossHit(_ boss: Tank) {
        boss.childNode(withName: "tankBody")?.run(SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 0.8, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
        ]))
    }

    /// Boss destroyed: chain of explosions, fireworks, a big title and the winning fanfare
    func showBossDefeated(at position: CGPoint) {
        SoundManager.shared.playBossDefeated()

        // Reward: both players shoot faster until a new game; every 10th boss also adds a bullet per shot
        for player in [playerTank, player2Tank].compactMap({ $0 }) {
            player.bossFireBoost += 1
            player.drawTank()
        }
        bossHealthBar?.removeFromParent()
        bossHealthBar = nil

        // White flash over the battlefield
        let cs = gameCamera.xScale
        let flash = SKSpriteNode(color: .white, size: CGSize(width: size.width * cs * 2, height: size.height * cs * 2))
        flash.zPosition = 140
        flash.alpha = 0.7
        gameCamera.addChild(flash)
        flash.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.4), SKAction.removeFromParent()]))

        // Chain of explosions around the wreck
        let blasts = SKNode()
        blasts.zPosition = 60
        gameLayer.addChild(blasts)
        var chain: [SKAction] = []
        for i in 0..<8 {
            chain.append(SKAction.run { [weak self, weak blasts] in
                guard let self = self, let blasts = blasts else { return }
                let offset = i == 0 ? CGPoint.zero : CGPoint(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: -30...30))
                self.addBossBlast(to: blasts, at: CGPoint(x: position.x + offset.x, y: position.y + offset.y), big: i == 0)
            })
            chain.append(SKAction.wait(forDuration: 0.1))
        }
        chain.append(SKAction.wait(forDuration: 1.0))
        chain.append(SKAction.removeFromParent())
        blasts.run(SKAction.sequence(chain))

        // Fireworks all over the map
        let fireworks = SKNode()
        fireworks.zPosition = 61
        gameLayer.addChild(fireworks)
        var shots: [SKAction] = [SKAction.wait(forDuration: 0.6)]
        for _ in 0..<7 {
            shots.append(SKAction.run { [weak self, weak fireworks] in
                guard let self = self, let fireworks = fireworks else { return }
                let point = CGPoint(x: CGFloat.random(in: 120...(GameConstants.gameWidth - 120)),
                                    y: CGFloat.random(in: 160...(GameConstants.gameHeight - 120)))
                self.addFireworkBurst(to: fireworks, at: point)
            })
            shots.append(SKAction.wait(forDuration: 0.35))
        }
        shots.append(SKAction.wait(forDuration: 1.5))
        shots.append(SKAction.removeFromParent())
        fireworks.run(SKAction.sequence(shots))

        // Big title: pops in, cycles colors, then fades
        let title = SKLabelNode(text: "☠ BOSS DEFEATED! ☠")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 46 * cs
        title.fontColor = .yellow
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: 0, y: 140 * cs)
        title.zPosition = 160
        title.setScale(0.1)
        gameCamera.addChild(title)

        let shadow = SKLabelNode(text: title.text)
        shadow.fontName = title.fontName
        shadow.fontSize = title.fontSize
        shadow.fontColor = SKColor(white: 0, alpha: 0.7)
        shadow.verticalAlignmentMode = .center
        shadow.position = CGPoint(x: 3 * cs, y: -3 * cs)
        shadow.zPosition = -1
        title.addChild(shadow)

        let pop = SKAction.sequence([
            SKAction.scale(to: 1.3, duration: 0.25),
            SKAction.scale(to: 1.0, duration: 0.15)
        ])
        let colors: [SKColor] = [.yellow, .orange, .red, .magenta, .cyan, .green]
        let cycle = SKAction.repeat(SKAction.sequence(colors.map { color in
            SKAction.sequence([SKAction.run { title.fontColor = color }, SKAction.wait(forDuration: 0.12)])
        }), count: 5)
        let wobble = SKAction.repeat(SKAction.sequence([
            SKAction.rotate(toAngle: 0.05, duration: 0.15),
            SKAction.rotate(toAngle: -0.05, duration: 0.15)
        ]), count: 6)
        let extraBullet = (playerTank?.bossFireBoost ?? 0) % GameConstants.bossesPerExtraBullet == 0
        let reward = SKLabelNode(text: extraBullet ? "🔥 FASTER SHOOTING + 1 BULLET! 🔥" : "🔥 FASTER SHOOTING! 🔥")
        reward.fontName = "Helvetica-Bold"
        reward.fontSize = 20 * cs
        reward.fontColor = .white
        reward.verticalAlignmentMode = .center
        reward.position = CGPoint(x: 0, y: -44 * cs)
        title.addChild(reward)

        title.run(SKAction.sequence([
            pop,
            SKAction.group([cycle, wobble]),
            SKAction.rotate(toAngle: 0, duration: 0.1),
            SKAction.group([SKAction.fadeOut(withDuration: 0.6), SKAction.scale(to: 1.6, duration: 0.6)]),
            SKAction.removeFromParent()
        ]))
    }

    private func addBossBlast(to parent: SKNode, at point: CGPoint, big: Bool) {
        SoundManager.shared.playExplosion()
        let radius: CGFloat = big ? 22 : 12
        for (color, scale, delay) in [(SKColor.yellow, 3.5, 0.0), (SKColor.orange, 2.8, 0.05), (SKColor.red, 2.0, 0.1)] {
            let ball = SKShapeNode(circleOfRadius: radius)
            ball.fillColor = color
            ball.strokeColor = .clear
            ball.position = point
            ball.setScale(0.2)
            parent.addChild(ball)
            ball.run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.group([SKAction.scale(to: CGFloat(scale) * (big ? 1.4 : 1), duration: 0.35),
                                SKAction.fadeOut(withDuration: 0.45)]),
                SKAction.removeFromParent()
            ]))
        }
        if big {
            let ring = SKShapeNode(circleOfRadius: 16)
            ring.strokeColor = .white
            ring.lineWidth = 4
            ring.position = point
            parent.addChild(ring)
            ring.run(SKAction.sequence([
                SKAction.group([SKAction.scale(to: 9, duration: 0.7), SKAction.fadeOut(withDuration: 0.7)]),
                SKAction.removeFromParent()
            ]))
        }
    }

    private func addFireworkBurst(to parent: SKNode, at point: CGPoint) {
        let color = SKColor(hue: CGFloat.random(in: 0...1), saturation: 0.9, brightness: 1, alpha: 1)
        let count = 22
        for i in 0..<count {
            let spark = SKSpriteNode(color: i % 4 == 0 ? .white : color, size: CGSize(width: 4, height: 4))
            spark.position = point
            parent.addChild(spark)
            let angle = CGFloat(i) / CGFloat(count) * .pi * 2
            let distance = CGFloat.random(in: 50...80)
            let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.7)
            fly.timingMode = .easeOut
            let fall = SKAction.moveBy(x: 0, y: -18, duration: 0.5)
            spark.run(SKAction.sequence([
                SKAction.group([fly, SKAction.sequence([SKAction.wait(forDuration: 0.4), SKAction.fadeOut(withDuration: 0.8)])]),
                fall,
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Colorful confetti and a blue ring (Gzhel tank farewell)
    private func showConfettiBurst(at position: CGPoint) {
        let colors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .magenta, .white]
        for i in 0..<36 {
            let piece = SKSpriteNode(color: colors[i % colors.count], size: CGSize(width: 5, height: 5))
            piece.position = position
            piece.zPosition = 60
            piece.zRotation = CGFloat.random(in: 0...(.pi))
            gameLayer.addChild(piece)

            let angle = CGFloat(i) / 36 * .pi * 2 + CGFloat.random(in: -0.1...0.1)
            let distance = CGFloat.random(in: 40...90)
            let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.9)
            fly.timingMode = .easeOut
            piece.run(SKAction.sequence([
                SKAction.group([fly, SKAction.rotate(byAngle: .pi * 3, duration: 0.9), SKAction.fadeOut(withDuration: 0.9)]),
                SKAction.removeFromParent()
            ]))
        }

        let ring = SKShapeNode(circleOfRadius: 10)
        ring.strokeColor = SKColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1.0)
        ring.lineWidth = 3
        ring.position = position
        ring.zPosition = 59
        gameLayer.addChild(ring)
        ring.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 6, duration: 0.6), SKAction.fadeOut(withDuration: 0.6)]),
            SKAction.removeFromParent()
        ]))
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

            // Laser light passes through walls
            if bullet.isLaser { continue }

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
            // Laser light is never blocked by walls
            if bullet.isLaser {
                bullets.append(bullet)
                gameLayer.addChild(bullet)
                continue
            }

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
        // Spawn regular enemies (don't spawn on players or the friend)
        let nonEnemyTanks = [gzhelTank, player2Tank].compactMap { $0 }
        if let newEnemy = enemySpawner.update(existingEnemies: enemyTanks, playerTank: playerTank, map: gameMap, otherTanks: nonEnemyTanks) {
            enemyTanks.append(newEnemy)
            invalidateAllTanksCache()
            gameLayer.addChild(newEnemy)
            showSpawnEffect(at: newEnemy.position)
            if newEnemy.enemyType == .boss {
                // Every next boss is one hit tougher: level 10 → 10 HP, level 20 → 11, level 30 → 12...
                let bossNumber = max(level / GameConstants.bossLevelInterval, 1)
                newEnemy.health = GameConstants.bossBaseHealth + bossNumber - 1
                newEnemy.maxHealth = newEnemy.health
                showEffect(text: "☠ BOSS IS COMING! ☠", color: .red)
            }
        }

        // Spawn extra enemies (from tank power-up collection, don't spawn on player)
        if let extraEnemy = enemySpawner.spawnExtraEnemy(existingEnemies: enemyTanks, playerTank: playerTank, map: gameMap, otherTanks: nonEnemyTanks) {
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
            if playerTanks.contains(where: { $0.machinegunCount > 0 }) && playerKills >= GameConstants.ufoKillsRequired {
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
        if let player = playerTanks.first(where: { $0.isAlive && egg.collidesWith($0) }) {
            // Player collected the easter egg!
            egg.collect()
            easterEgg = nil
            playerCollectedEasterEgg = true

            // Give that player 3 extra lives
            player.addLives(GameConstants.easterEggLivesBonus)

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
            // Check player collision. Dead (hidden) players waiting to respawn can't collect power-ups
            let collector = playerTanks.first { player in
                let collisionDist = (player.size.width + powerUp.size.width) / 2
                return player.isAlive &&
                    abs(player.position.x - powerUp.position.x) < collisionDist &&
                    abs(player.position.y - powerUp.position.y) < collisionDist
            }
            if let player = collector {
                handlePowerUpCollection(powerUp, by: player)
                powerUpsToRemove.append(powerUp)
                SoundManager.shared.playPowerUp()
                continue
            }

            // The friend collects power-ups too (except the player's laser)
            if let friend = gzhelTank, friend.isAlive, powerUp.type != .laser, !powerUp.type.isLevelBonus {
                let friendDist = (friend.size.width + powerUp.size.width) / 2
                if abs(friend.position.x - powerUp.position.x) < friendDist &&
                    abs(friend.position.y - powerUp.position.y) < friendDist {
                    handleFriendPowerUpCollection(powerUp, friend: friend)
                    powerUpsToRemove.append(powerUp)
                    SoundManager.shared.playPowerUp()
                    continue
                }
            }

            // Check enemy collisions (the laser is the player's reward: enemies can't take it)
            for enemy in enemyTanks where powerUp.type != .laser && !powerUp.type.isLevelBonus {
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
            // Freeze all players for 30 seconds (can still shoot)
            for player in playerTanks where player.isAlive {
                playerFreezeTimers[player.playerNumber - 1] = playerFreezeDuration
                addFreezeEffect(to: player)
            }
            showEffect(text: isTwoPlayer ? "PLAYERS FROZEN!" : "PLAYER FROZEN!", color: .red)
        case .bomb:
            // Kills all players instantly! Bypasses ship AND shield protection.
            // No effect on a player who is already dead and waiting to respawn.
            for player in playerTanks where player.isAlive {
                player.damage(bypassShip: true, bypassShield: true)
                if !player.isAlive {
                    player.deathsThisLevel -= 1  // A bomb death doesn't cost the soccer ball
                    handlePlayerKilled(player)
                }
            }
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
        case .laser, .strawberry, .banana, .ball:
            break  // Never collected by enemies
        }
    }

    /// Handle enemy collecting gold - major upgrade
    private func handleEnemyGoldCollection(_ enemy: Tank) {
        switch enemy.enemyType {
        case .power:
            // Power tank → Heavy tank
            enemy.convertToType(.heavy)
            showEffect(text: "GOLD HEAVY!", color: .red)
        case .alien:
            // Alien stays an alien, but shoots more
            enemy.machinegunCount = 2
            showEffect(text: "GOLD ALIEN!", color: .red)
        case .boss:
            // The boss stays the boss: fully healed and shoots more
            enemy.health = enemy.maxHealth
            enemy.machinegunCount = 2
            showEffect(text: "GOLD BOSS!", color: .red)
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
        case .heavy, .boss, .alien, .gzhel:
            // Already at max (or can't change type), just heal
            enemy.health = enemy.maxHealth
            showEffect(text: "ENEMY HEALED!", color: .red)
        }
    }

    /// How long an enemy freeze holds the players: easy 10s, Gzhel / alien levels 15s, normal 20s
    private var playerFreezeDuration: Int {
        if GameScene.isEasyMode { return GameConstants.playerFreezeEasy }
        if showGzhelBorder || alienMode { return GameConstants.playerFreezeSpecial }
        return GameConstants.playerFreezeNormal
    }

    /// Add freeze visual effect to a player
    private func addFreezeEffect(to player: Tank) {
        // Remove any existing freeze effect
        player.childNode(withName: "freezeEffect")?.removeFromParent()

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
                x: cos(angle) * player.size.width * 0.5,
                y: sin(angle) * player.size.height * 0.5
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

        player.addChild(freezeNode)
        // Removed in update() when the player's freeze timer reaches 0
    }

    private func handlePowerUpCollection(_ powerUp: PowerUp, by player: Tank) {
        // Gold gives 99 points, others give 1
        if powerUp.type == .gold {
            addScore(99, for: player)
            showEffect(text: "+99 GOLD!", color: .yellow)
            return
        }
        switch powerUp.type {
        case .strawberry:
            addScore(GameConstants.strawberryPoints, for: player)
            showEffect(text: "+\(GameConstants.strawberryPoints) STRAWBERRY!", color: .red)
            return
        case .banana:
            addScore(GameConstants.bananaPoints, for: player)
            showEffect(text: "+\(GameConstants.bananaPoints) BANANA!", color: .yellow)
            return
        case .ball:
            addScore(GameConstants.ballPoints, for: player)
            powerUp.apply(to: player)
            player.drawTank()
            showEffect(text: "+\(GameConstants.ballPoints) GOAL! SPEED UP!", color: .white)
            return
        default:
            break
        }

        addScore(1, for: player)

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
            player.canDestroyTrees = true
            showEffect(text: "SAW!", color: .green)
        case .laser:
            powerUp.apply(to: player)
            showEffect(text: "LASER!", color: .cyan)
        default:
            powerUp.apply(to: player)
        }
    }

    /// Add freeze visual effect to all enemies
    private func addFreezeEffectToEnemies() {
        for enemy in enemyTanks where enemy.isAlive && !enemy.isFreezeImmune {
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
        // Removed in update() when freezeTimer reaches 0
    }

    private func destroyAllEnemies() {
        // The boss is too tough for a bomb: it just takes one hit
        var survivors: [Tank] = []
        for enemy in enemyTanks where enemy.isAlive && enemy.enemyType == .boss {
            bombUsedThisLevel = true
            enemy.damage(bypassShip: true, bypassShield: true)
            if enemy.isAlive {
                flashBossHit(enemy)
                survivors.append(enemy)
            } else {
                showBossDefeated(at: enemy.position)
            }
        }
        for enemy in enemyTanks where !survivors.contains(where: { $0 === enemy }) {
            if enemy.isAlive {
                bombUsedThisLevel = true
                // No score or kill credit for bomb kills
                // Force kill - keep damaging until dead (for heavy tanks with multiple health)
                while enemy.isAlive {
                    enemy.damage(bypassShip: true, bypassShield: true)
                }
            }
            // Remove from scene
            enemy.removeFromParent()
        }
        enemyTanks = survivors
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

    /// Level cleared: strawberry for crossing 250 points this level, banana for crossing 500,
    /// soccer ball when no bomb was used and no player died (enemy bomb deaths don't count).
    /// Returns true if anything appeared.
    private func spawnLevelBonuses() -> Bool {
        var bonuses: [PowerUp.PowerUpType] = []
        for index in 0..<playerCount {
            let before = levelStartScores[index], now = scores[index]
            if before < GameConstants.strawberryScoreThreshold && now >= GameConstants.strawberryScoreThreshold {
                bonuses.append(.strawberry)
            }
            if before < GameConstants.bananaScoreThreshold && now >= GameConstants.bananaScoreThreshold {
                bonuses.append(.banana)
            }
        }
        let playerDied = [playerTank, player2Tank].compactMap { $0 }.contains { $0.deathsThisLevel > 0 }
        if !bombUsedThisLevel && !playerDied {
            bonuses.append(.ball)
        }
        for type in bonuses {
            spawnPowerUp(at: .zero, type: type)
        }
        levelBonusesSpawned = !bonuses.isEmpty
        return levelBonusesSpawned
    }

    func spawnPowerUp(at position: CGPoint, type: PowerUp.PowerUpType? = nil) {
        // Find random empty position instead of spawning at enemy location
        let spawnPosition = findRandomEmptyPosition()
        let powerUp = PowerUp(position: spawnPosition, type: type)
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

        // Keep clear of tanks (an enemy would grab it at once) and of other power-ups
        let clearance = GameConstants.tileSize * 2
        let tanks = allTanks.filter { $0.isAlive }
        func isClear(_ p: CGPoint) -> Bool {
            !tanks.contains { abs($0.position.x - p.x) < clearance && abs($0.position.y - p.y) < clearance } &&
            !powerUps.contains { abs($0.position.x - p.x) < GameConstants.tileSize && abs($0.position.y - p.y) < GameConstants.tileSize }
        }
        if let randomPosition = emptyPositions.filter(isClear).randomElement() {
            return randomPosition
        }
        // Crowded field: take the empty spot farthest from any tank
        if let farthest = emptyPositions.max(by: { a, b in
            let da = tanks.map { a.distance(to: $0.position) }.min() ?? .infinity
            let db = tanks.map { b.distance(to: $0.position) }.min() ?? .infinity
            return da < db
        }) {
            return farthest
        }

        // Fallback - should rarely happen
        return CGPoint(
            x: 13 * tileSize + tileSize / 2,
            y: 13 * tileSize + tileSize / 2
        )
    }

    func showEffect(text: String, color: SKColor) {
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
        // Idempotent: a bullet can only be destroyed once, so its owner's
        // active-bullet count is decremented exactly once.
        let id = ObjectIdentifier(bullet)
        guard !bulletsMarkedForRemoval.contains(id) else { return }
        // Mark for batch removal instead of O(n) removeAll per bullet
        bulletsMarkedForRemoval.insert(id)
        bullet.owner?.bulletDestroyed(hitObstacle: hitObstacle)
        bullet.removeFromParent()
    }

    /// True if the bullet was already destroyed this frame (still in `bullets` until flushed)
    func isBulletRemoved(_ bullet: Bullet) -> Bool {
        return bulletsMarkedForRemoval.contains(ObjectIdentifier(bullet))
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
            if spawnLevelBonuses() {
                victoryDelayTimer = GameConstants.levelBonusVictoryDelay
            }
            // The friend stays (it comes along to the next level); one that hasn't appeared yet won't now
            gzhelSpawnedThisLevel = true
        }

        // Check lose condition: every player is out of lives
        if playerTanks.allSatisfy({ $0.lives <= 0 && !$0.isAlive }) {
            gameOver(won: false)
        }
    }

    private func levelComplete() {
        isGameOver = true
        didWinLevel = true
        hideFreezeLabels()
        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.playVictory()

        // Reset consecutive losses on win (exits easy mode)
        GameScene.consecutiveLosses = 0

        let bonus = awardKillBonus()
        showScoreBreakdown(title: "LEVEL COMPLETE!", titleColor: .green, showRestart: false, bonus: bonus)

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
        // Freeze SKActions in the game world too (explosions, effects, animations);
        // the pause overlay lives on the camera and keeps running.
        gameLayer.isPaused = isGamePaused

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
            pauseLabel.position = CGPoint(x: 0, y: 80 * cameraScale)
            pauseOverlay?.addChild(pauseLabel)

            // Resume button
            let resumeButton = createPauseButton(text: "RESUME", cameraScale: cameraScale)
            resumeButton.position = CGPoint(x: 0, y: 20 * cameraScale)
            resumeButton.name = "resumeButton"
            pauseOverlay?.addChild(resumeButton)

            // Sound on/off button
            let muteButton = createPauseButton(text: muteButtonTitle, cameraScale: cameraScale)
            muteButton.position = CGPoint(x: 0, y: -40 * cameraScale)
            muteButton.name = "muteButton"
            pauseOverlay?.addChild(muteButton)

            // Menu button
            let menuButton = createPauseButton(text: "MENU", cameraScale: cameraScale)
            menuButton.position = CGPoint(x: 0, y: -100 * cameraScale)
            menuButton.name = "menuButton"
            pauseOverlay?.addChild(menuButton)

            gameCamera.addChild(pauseOverlay!)
        } else {
            // Remove pause overlay
            pauseOverlay?.removeFromParent()
            pauseOverlay = nil
        }
    }

    private var muteButtonTitle: String {
        SoundManager.shared.isMuted ? "SOUND: OFF" : "SOUND: ON"
    }

    /// Toggle mute from the pause menu and refresh the button label
    private func toggleMute() {
        SoundManager.shared.isMuted.toggle()
        if let button = pauseOverlay?.childNode(withName: "muteButton"),
           let label = button.children.compactMap({ $0 as? SKLabelNode }).first {
            label.text = muteButtonTitle
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
        // Base hit and last life lost can both trigger in the same frame
        guard !isGameOver else { return }
        isGameOver = true
        hideFreezeLabels()
        SoundManager.shared.stopGameplaySounds()

        // Track consecutive losses for easy mode
        GameScene.consecutiveLosses += 1

        isNewHighScore = bestScore > GameScene.highScore
        if isNewHighScore {
            GameScene.highScore = bestScore
        }

        showGameOverScreen()
    }

    // MARK: - Game Over Screen

    /// Beat a high score this game (shown on the game over screen and the statistics)
    private var isNewHighScore = false
    private var gameOverScreen: SKNode?
    private var isShowingGameOverScreen: Bool { gameOverScreen != nil }
    private static let gameOverScreenSeconds = 10

    /// Big "GAME OVER" with score and high score for 10 seconds (with its tune),
    /// then the statistics. A tap or Enter skips it.
    private func showGameOverScreen() {
        let cs = gameCamera.xScale
        let screen = SKNode()
        screen.zPosition = 300  // Above touch controls and the pause button
        screen.alpha = 0
        gameCamera.addChild(screen)
        gameOverScreen = screen

        let background = SKShapeNode(rectOf: CGSize(width: size.width * cs * 1.5, height: size.height * cs * 1.5))
        background.fillColor = SKColor.black.withAlphaComponent(0.88)
        background.strokeColor = .clear
        screen.addChild(background)
        screen.run(SKAction.fadeIn(withDuration: 0.4))

        // "GAME OVER": letters drop in one by one and bounce, then glow
        let text = Array("GAME OVER")
        let spacing: CGFloat = 46 * cs
        let lettersY: CGFloat = 70 * cs
        for (i, char) in text.enumerated() where char != " " {
            let letter = SKLabelNode(text: String(char))
            letter.fontName = "Helvetica-Bold"
            letter.fontSize = 66 * cs
            letter.fontColor = .red
            letter.verticalAlignmentMode = .center
            letter.position = CGPoint(x: (CGFloat(i) - CGFloat(text.count - 1) / 2) * spacing, y: lettersY + 300 * cs)
            letter.alpha = 0
            screen.addChild(letter)

            let drop = SKAction.moveTo(y: lettersY, duration: 0.45)
            drop.timingMode = .easeIn
            let bounce = SKAction.sequence([
                SKAction.moveBy(x: 0, y: 18 * cs, duration: 0.12),
                SKAction.moveBy(x: 0, y: -18 * cs, duration: 0.12)
            ])
            let glow = SKAction.repeatForever(SKAction.sequence([
                SKAction.run { letter.fontColor = SKColor(red: 1.0, green: 0.25, blue: 0.2, alpha: 1) },
                SKAction.scale(to: 1.08, duration: 0.5),
                SKAction.run { letter.fontColor = SKColor(red: 0.6, green: 0.0, blue: 0.0, alpha: 1) },
                SKAction.scale(to: 1.0, duration: 0.5)
            ]))
            letter.run(SKAction.sequence([
                SKAction.wait(forDuration: 0.3 + Double(i) * 0.12),
                SKAction.group([SKAction.fadeIn(withDuration: 0.2), drop]),
                bounce,
                glow
            ]))
        }

        // Score and high score fade in after the title
        let infoDelay = 0.3 + Double(text.count) * 0.12 + 0.4
        func addInfo(_ string: String, fontSize: CGFloat, color: SKColor, y: CGFloat, delay: Double) -> SKLabelNode {
            let label = SKLabelNode(text: string)
            label.fontName = "Helvetica-Bold"
            label.fontSize = fontSize * cs
            label.fontColor = color
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: 0, y: y * cs)
            label.alpha = 0
            screen.addChild(label)
            label.run(SKAction.sequence([SKAction.wait(forDuration: delay), SKAction.fadeIn(withDuration: 0.4)]))
            return label
        }
        let scoreText = isTwoPlayer ? "1P: \(scores[0])    2P: \(scores[1])" : "SCORE: \(score)"
        _ = addInfo(scoreText, fontSize: 28, color: .white, y: -10, delay: infoDelay)
        _ = addInfo("HIGH SCORE: \(GameScene.highScore)", fontSize: 30,
                    color: SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1), y: -55, delay: infoDelay + 0.3)

        if isNewHighScore {
            let record = addInfo("NEW HIGH SCORE!", fontSize: 26, color: .magenta, y: -100, delay: infoDelay + 0.6)
            record.run(SKAction.sequence([
                SKAction.wait(forDuration: infoDelay + 1.0),
                SKAction.run { [weak self] in
                    self?.showBonusStars(at: CGPoint(x: 0, y: -100 * cs), cameraScale: cs, zPosition: 310)
                },
                SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.25, duration: 0.3),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.3)
                ]))
            ]))
        }

        // Countdown until the statistics appear
        var secondsLeft = GameScene.gameOverScreenSeconds
        let countdown = addInfo("Tap to continue  \(secondsLeft)", fontSize: 16, color: .lightGray, y: -155, delay: infoDelay + 0.6)
        let tick = SKAction.sequence([
            SKAction.wait(forDuration: 1.0),
            SKAction.run {
                secondsLeft -= 1
                countdown.text = "Tap to continue  \(max(secondsLeft, 0))"
            }
        ])
        screen.run(SKAction.repeat(tick, count: GameScene.gameOverScreenSeconds), withKey: "countdown")
        screen.run(SKAction.sequence([
            SKAction.wait(forDuration: TimeInterval(GameScene.gameOverScreenSeconds)),
            SKAction.run { [weak self] in self?.finishGameOverScreen() }
        ]), withKey: "finish")

        SoundManager.shared.playGameOver()
    }

    /// Leave the game over screen (after 10 seconds or when skipped) and show the statistics
    private func finishGameOverScreen() {
        guard let screen = gameOverScreen else { return }
        gameOverScreen = nil
        SoundManager.shared.stopGameOver()

        screen.removeAllActions()
        screen.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.3), SKAction.removeFromParent()]))
        showScoreBreakdown(title: "GAME OVER", titleColor: .red, showRestart: true)
    }

    /// Two players: the one with more kills this level gets a random power-up
    /// (speed, machinegun, laser or gun), carried into the next level. No bonus on a tie.
    private func awardKillBonus() -> KillBonus? {
        guard isTwoPlayer, let player2 = player2Tank else { return nil }
        let kills1 = killsByPlayer[0].values.reduce(0, +)
        let kills2 = killsByPlayer[1].values.reduce(0, +)
        guard kills1 != kills2 else { return nil }

        let winnerIndex = kills1 > kills2 ? 0 : 1
        let winner = winnerIndex == 0 ? playerTank! : player2

        // Prefer a power-up the winner can still use (e.g. not a 4th machinegun)
        let candidates: [PowerUp.PowerUpType] = [.car, .machinegun, .laser, .gun]
        let useful = candidates.filter { type in
            switch type {
            case .car: return winner.speedMultiplier < 2.5
            case .machinegun: return winner.machinegunCount < 3
            case .gun: return winner.bulletPower < 2
            default: return true
            }
        }
        let type = (useful.isEmpty ? candidates : useful).randomElement() ?? .car

        PowerUp(position: .zero, type: type).apply(to: winner)
        winner.drawTank()
        return KillBonus(playerIndex: winnerIndex, type: type)
    }

    private func bonusDescription(_ type: PowerUp.PowerUpType) -> String {
        switch type {
        case .car: return "🚗 SPEED"
        case .machinegun: return "💥 MACHINEGUN"
        case .laser: return "🔦 LASER"
        case .gun: return "🔫 GUN"
        default: return ""
        }
    }

    /// Kill rows ([tank icon] × count : points) for one set of kills; returns the next free Y
    private func addKillRows(_ kills: [Tank.EnemyType: Int], x: CGFloat, y: CGFloat,
                             lineHeight: CGFloat, cameraScale: CGFloat) -> CGFloat {
        var yPos = y
        let enemyTypes: [Tank.EnemyType] = [.regular, .fast, .armored, .power, .heavy, .alien, .boss]
        for type in enemyTypes {
            let count = kills[type] ?? 0
            if count > 0 {
                let points = GameConstants.scoreForEnemyType(type) * count
                let row = createKillRow(enemyType: type, count: count, points: points, cameraScale: cameraScale)
                row.position = CGPoint(x: x, y: yPos)
                row.zPosition = 200
                gameCamera.addChild(row)
                yPos -= lineHeight
            }
        }
        return yPos
    }

    private func addBreakdownLabel(_ text: String, fontSize: CGFloat, color: SKColor, at position: CGPoint) -> SKLabelNode {
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = fontSize
        label.fontColor = color
        label.position = position
        label.zPosition = 200
        gameCamera.addChild(label)
        return label
    }

    /// Two-player statistics: one column of kills per player, plus the kill bonus.
    /// Returns the next free Y below both columns.
    private func addTwoPlayerKillColumns(y: CGFloat, lineHeight: CGFloat, cameraScale: CGFloat, bonus: KillBonus?) -> CGFloat {
        let columnX: [CGFloat] = [-140 * cameraScale, 140 * cameraScale]
        let colors = [GameSettings.shared.playerTankColor.color, GameSettings.shared.player2TankColor.color]
        var columnEnds: [CGFloat] = []

        for index in 0..<2 {
            var yPos = y
            let x = columnX[index]
            let total = killsByPlayer[index].values.reduce(0, +)
            _ = addBreakdownLabel("\(index + 1)P: \(total) KILLS", fontSize: 20 * cameraScale, color: colors[index],
                                  at: CGPoint(x: x, y: yPos))
            yPos -= lineHeight * 1.1

            yPos = addKillRows(killsByPlayer[index], x: x, y: yPos, lineHeight: lineHeight, cameraScale: cameraScale)

            // Bonus sits beside the winner's column (outer side) so the screen doesn't get taller
            if let bonus = bonus, bonus.playerIndex == index {
                let side: CGFloat = index == 0 ? -1 : 1
                showBonusAnimation(text: bonusDescription(bonus.type),
                                   at: CGPoint(x: x + side * 190 * cameraScale, y: y - lineHeight * 1.2),
                                   lineHeight: lineHeight, cameraScale: cameraScale)
            }
            columnEnds.append(yPos)
        }
        return columnEnds.min() ?? y
    }

    /// "BONUS!" pops in under the winner's kills, then keeps pulsing in rainbow colors
    private func showBonusAnimation(text: String, at position: CGPoint, lineHeight: CGFloat, cameraScale: CGFloat) {
        let container = SKNode()
        container.position = position
        container.zPosition = 210
        container.setScale(0.01)
        container.alpha = 0
        gameCamera.addChild(container)

        let bonusLabel = SKLabelNode(text: "BONUS!")
        bonusLabel.fontName = "Helvetica-Bold"
        bonusLabel.fontSize = 26 * cameraScale
        bonusLabel.fontColor = .yellow
        container.addChild(bonusLabel)

        let powerUpLabel = SKLabelNode(text: text)
        powerUpLabel.fontName = "Helvetica-Bold"
        powerUpLabel.fontSize = 18 * cameraScale
        powerUpLabel.fontColor = .white
        powerUpLabel.position = CGPoint(x: 0, y: -lineHeight)
        container.addChild(powerUpLabel)

        // Rainbow color cycle on "BONUS!"
        let rainbow: [SKColor] = [.yellow, .orange, .red, .magenta, .cyan, .green]
        let cycle = SKAction.sequence(rainbow.flatMap { color in
            [SKAction.run { bonusLabel.fontColor = color }, SKAction.wait(forDuration: 0.12)]
        })
        bonusLabel.run(SKAction.repeatForever(cycle))

        let popIn = SKAction.group([
            SKAction.fadeIn(withDuration: 0.25),
            SKAction.sequence([
                SKAction.scale(to: 1.4, duration: 0.25),
                SKAction.scale(to: 1.0, duration: 0.15)
            ])
        ])
        let pulse = SKAction.repeatForever(SKAction.sequence([
            SKAction.scale(to: 1.12, duration: 0.4),
            SKAction.scale(to: 1.0, duration: 0.4)
        ]))
        let burst = SKAction.run { [weak self] in
            SoundManager.shared.playPowerUp()
            self?.showBonusStars(at: CGPoint(x: position.x, y: position.y + 8 * cameraScale), cameraScale: cameraScale)
        }
        // Appears after a short pause so the statistics are read first
        container.run(SKAction.sequence([SKAction.wait(forDuration: 0.8), burst, popIn, pulse]))
    }

    /// Stars flying out of the bonus label
    private func showBonusStars(at position: CGPoint, cameraScale: CGFloat, zPosition: CGFloat = 205) {
        for i in 0..<12 {
            let star = SKLabelNode(text: "★")
            star.fontSize = 16 * cameraScale
            star.fontColor = [SKColor.yellow, .orange, .cyan, .magenta][i % 4]
            star.verticalAlignmentMode = .center
            star.position = position
            star.zPosition = zPosition
            gameCamera.addChild(star)

            let angle = CGFloat(i) / 12 * .pi * 2
            let distance = CGFloat.random(in: 50...80) * cameraScale
            let fly = SKAction.moveBy(x: cos(angle) * distance, y: sin(angle) * distance, duration: 0.7)
            fly.timingMode = .easeOut
            star.run(SKAction.sequence([
                SKAction.group([fly, SKAction.rotate(byAngle: .pi * 2, duration: 0.7), SKAction.fadeOut(withDuration: 0.7)]),
                SKAction.removeFromParent()
            ]))
        }
    }

    /// Show score breakdown screen with tank kill stats
    private func showScoreBreakdown(title: String, titleColor: SKColor, showRestart: Bool, bonus: KillBonus? = nil) {
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

        // Kill breakdown for each enemy type (only show types with kills);
        // two players get a column each
        if isTwoPlayer {
            yPos = addTwoPlayerKillColumns(y: yPos, lineHeight: lineHeight, cameraScale: cameraScale, bonus: bonus)
        } else {
            yPos = addKillRows(killsByType, x: 0, y: yPos, lineHeight: lineHeight, cameraScale: cameraScale)
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

        // Round and total score (two players: one pair per column)
        let scoreColumns: [(x: CGFloat, index: Int)] = isTwoPlayer
            ? [(-140 * cameraScale, 0), (140 * cameraScale, 1)]
            : [(0, 0)]
        for column in scoreColumns {
            let roundScore = scores[column.index] - levelStartScores[column.index]
            _ = addBreakdownLabel("Round Score: \(roundScore)", fontSize: 20 * cameraScale, color: .yellow,
                                  at: CGPoint(x: column.x, y: yPos))
            _ = addBreakdownLabel("Total Score: \(scores[column.index])", fontSize: 22 * cameraScale, color: .cyan,
                                  at: CGPoint(x: column.x, y: yPos - lineHeight))
        }
        yPos -= lineHeight * 2

        // Highscore (only on game over, not level complete; recorded in gameOver())
        if showRestart && isNewHighScore {
            let highScoreLabel = SKLabelNode(text: "HIGHSCORE \(bestScore)")
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

        addBreakdownBackground(top: 140 * cameraScale + 40 * cameraScale,
                               bottom: yPos - 40 * cameraScale, cameraScale: cameraScale)
    }

    /// Dim the game behind the statistics and put them on a framed panel so they're easy to read
    private func addBreakdownBackground(top: CGFloat, bottom: CGFloat, cameraScale: CGFloat) {
        let screenSize = CGSize(width: size.width * cameraScale, height: size.height * cameraScale)

        let dim = SKShapeNode(rectOf: CGSize(width: screenSize.width * 1.5, height: screenSize.height * 1.5))
        dim.fillColor = SKColor.black.withAlphaComponent(0.6)
        dim.strokeColor = .clear
        dim.zPosition = 198
        gameCamera.addChild(dim)

        // Two players: wide enough for both columns and the bonus beside them
        let wanted: CGFloat = (isTwoPlayer ? 840 : 380) * cameraScale
        let width = min(wanted, screenSize.width * 0.96)
        let height = top - bottom
        let panel = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 14 * cameraScale)
        panel.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.12, alpha: 0.95)
        panel.strokeColor = showGzhelBorder ? .blue : .yellow
        panel.lineWidth = 3 * cameraScale
        panel.position = CGPoint(x: 0, y: (top + bottom) / 2)
        panel.zPosition = 199
        gameCamera.addChild(panel)
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
        case .alien:
            color = SKColor(red: 0.4, green: 0.9, blue: 0.4, alpha: 1.0)  // Alien green
        case .gzhel:
            color = SKColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1.0)  // Gzhel blue
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

    // MARK: - Freeze Countdown HUD

    private var playerFreezeLabels: [SKLabelNode] = []  // One per player
    private var enemyFreezeLabel: SKLabelNode?
    private var shownPlayerFreezeSeconds = [-1, -1]
    private var shownEnemyFreezeSeconds = -1

    private func setupFreezeLabels() {
        let playerColor = SKColor(red: 1.0, green: 0.45, blue: 0.45, alpha: 1.0)
        playerFreezeLabels = (0..<playerCount).map { _ in makeFreezeLabel(color: playerColor) }
        enemyFreezeLabel = makeFreezeLabel(color: .cyan)
        if isTwoPlayer {
            lifeHintLabels = (1...2).map { number in
                let label = makeFreezeLabel(color: Tank.colorForPlayer(number))
                label.text = "\(number)P: PRESS FIRE TO TAKE A LIFE"
                label.run(SKAction.repeatForever(SKAction.sequence([
                    SKAction.fadeAlpha(to: 0.35, duration: 0.4),
                    SKAction.fadeAlpha(to: 1.0, duration: 0.4)
                ])))
                return label
            }
        }
    }

    /// Two players: "1P: PRESS FIRE TO TAKE A LIFE" while that player is out and the teammate has a spare
    private var lifeHintLabels: [SKLabelNode] = []

    private func makeFreezeLabel(color: SKColor) -> SKLabelNode {
        let label = SKLabelNode(text: "")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 20 * gameCamera.xScale
        label.fontColor = color
        label.verticalAlignmentMode = .top
        label.zPosition = 150  // Below pause / game over overlays
        label.isHidden = true
        gameCamera.addChild(label)
        return label
    }

    /// Show "YOU ARE FROZEN 27s" (two players: "1P FROZEN 27s") / "ENEMIES FROZEN 12s"
    /// at the top of the screen. Active countdowns stack from the top; text only changes once per second.
    private func updateFreezeLabels() {
        let hintsWanted = playerTanks.map { canStealLife($0) }
        guard playerFreezeTimers.contains(where: { $0 > 0 }) || freezeTimer > 0 || hintsWanted.contains(true) ||
              playerFreezeLabels.contains(where: { !$0.isHidden }) || enemyFreezeLabel?.isHidden == false ||
              lifeHintLabels.contains(where: { !$0.isHidden }) else { return }

        var y = cameraY(forPointsBelowVisibleTop: 10)

        for (index, label) in playerFreezeLabels.enumerated() {
            let title = isTwoPlayer ? "\(index + 1)P FROZEN" : "YOU ARE FROZEN"
            updateFreezeLabel(label, timer: playerFreezeTimers[index], title: title,
                              shownSeconds: &shownPlayerFreezeSeconds[index], y: &y)
        }
        if let label = enemyFreezeLabel {
            updateFreezeLabel(label, timer: freezeTimer, title: "ENEMIES FROZEN",
                              shownSeconds: &shownEnemyFreezeSeconds, y: &y)
        }
        for (index, label) in lifeHintLabels.enumerated() {
            let wanted = index < hintsWanted.count && hintsWanted[index]
            label.isHidden = !wanted
            if wanted {
                label.position = CGPoint(x: 0, y: y)
                y -= label.fontSize * 1.3
            }
        }
    }

    private func updateFreezeLabel(_ label: SKLabelNode, timer: Int, title: String,
                                   shownSeconds: inout Int, y: inout CGFloat) {
        guard timer > 0 else {
            label.isHidden = true
            shownSeconds = -1
            return
        }

        let seconds = (timer + 59) / 60  // Round up: 1..60 frames left shows "1s"
        if seconds != shownSeconds {
            shownSeconds = seconds
            label.text = "\u{2744} \(title) \(seconds)s"
        }
        label.position = CGPoint(x: 0, y: y)
        label.isHidden = false
        y -= label.fontSize * 1.3  // Next line (font size is already in camera units)
    }

    /// Camera-space Y for a point `points` below the top of the screen area the
    /// player can actually see: below the safe area (Mac title bar, iPad status
    /// area) and below any letterbox bars from aspect-fit scaling.
    private func cameraY(forPointsBelowVisibleTop points: CGFloat) -> CGFloat {
        guard let view = view, size.width > 0, size.height > 0 else {
            return (size.height / 2 - points) * gameCamera.xScale
        }

        let viewSize = view.bounds.size
        let fit: CGFloat
        switch scaleMode {
        case .aspectFit: fit = min(viewSize.width / size.width, viewSize.height / size.height)
        case .aspectFill: fit = max(viewSize.width / size.width, viewSize.height / size.height)
        default: fit = viewSize.height / size.height
        }
        let letterboxTop = max((viewSize.height - size.height * fit) / 2, 0)
        let visibleTop = max(view.safeAreaInsets.top, letterboxTop)

        // View → scene → camera coordinates (handles camera position and zoom)
        let scenePoint = convertPoint(fromView: CGPoint(x: view.bounds.midX, y: visibleTop + points))
        return gameCamera.convert(scenePoint, from: self).y
    }

    private func hideFreezeLabels() {
        playerFreezeLabels.forEach { $0.isHidden = true }
        enemyFreezeLabel?.isHidden = true
        lifeHintLabels.forEach { $0.isHidden = true }
    }

    private func updateUI() {
        updateFreezeLabels()

        #if targetEnvironment(macCatalyst)
        // Post notification for UIKit overlay to update
        NotificationCenter.default.post(name: .gameScoreDidChange, object: nil,
                                        userInfo: ["score": score, "text": scoreText])
        #else
        let text = scoreText
        if scoreLabel.text != text { scoreLabel.text = text }
        #endif

        // Build power-up data from the player tanks
        var powerUps = sidebarPowerUps(of: playerTank)
        if let friend = gzhelTank, friend.isAlive {
            powerUps.friendHits = friend.health
        }
        let powerUps2 = player2Tank.map { sidebarPowerUps(of: $0) } ?? Sidebar.PowerUpData()

        // Update sidebar with remaining enemies (not yet spawned)
        sidebar.update(
            remainingEnemies: enemySpawner.remainingEnemies,
            playerLives: playerTank.lives,
            player2Lives: player2Tank?.lives ?? 0,
            level: level,
            powerUps: powerUps,
            powerUps2: powerUps2
        )
    }

    private func sidebarPowerUps(of player: Tank) -> Sidebar.PowerUpData {
        var powerUps = Sidebar.PowerUpData()
        powerUps.starCount = player.starCount
        powerUps.bossFireBoost = player.bossFireBoost
        powerUps.machinegunCount = player.machinegunCount
        powerUps.hasGun = player.bulletPower >= 2
        powerUps.hasShip = player.canSwim
        powerUps.hasSaw = player.canDestroyTrees
        powerUps.hasLaser = player.hasLaser
        // Calculate speed boosts (each 0.3 increment is one boost)
        powerUps.speedBoosts = Int((player.speedMultiplier - 1.0) / 0.3)
        return powerUps
    }

    /// Score line at the top: "Score: 12", two players "1P: 12   2P: 7"
    private var scoreText: String {
        isTwoPlayer ? "1P: \(scores[0])   2P: \(scores[1])" : "Score: \(score)"
    }

    /// Add score to a player (player 1 if unknown) and check for their bonus life every 100 points
    func addScore(_ points: Int, for player: Tank?) {
        let index = player?.playerNumber == 2 ? 1 : 0
        let oldMilestone = scores[index] / 100
        scores[index] += points
        let newMilestone = scores[index] / 100

        // Award bonus life for each 100-point milestone of this player's own score
        // (also brings back a player who ran out of lives)
        if newMilestone > oldMilestone {
            let bonusLives = newMilestone - oldMilestone
            (index == 1 ? player2Tank : playerTank)?.addLives(bonusLives)
            showEffect(text: "+\(bonusLives) LIFE!", color: .magenta)
        }
    }

    // MARK: - Helpers

    private var allTanks: [Tank] {
        if _allTanksDirty {
            _cachedAllTanks = [playerTank, player2Tank].compactMap { $0 } + enemyTanks + [gzhelTank].compactMap { $0 }
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
                if node.name == "muteButton" || node.parent?.name == "muteButton" {
                    toggleMute()  // Stay paused
                    return
                }
            }
            // Tap on background also resumes
            togglePause()
            return
        }

        // Game over screen: a tap skips to the statistics
        if isShowingGameOverScreen {
            finishGameOverScreen()
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
        // Carry over players' lives and power-ups to next level
        let powerUps = carriedPowerUps(of: playerTank)
        let powerUps2 = player2Tank.map { carriedPowerUps(of: $0) } ?? PlayerPowerUps()

        // If player collected easter egg and cat played, next level gets Gzhel decoration (one level only)
        let earnedGzhel = playerCollectedEasterEgg

        // If UFO escaped this level, next level has alien at base (only one level, then back to cat)
        // If currently in alien mode, alien leaves so next level is normal
        // UFO escaped if: it spawned this level AND wasn't killed (still alive or escaped earlier)
        let ufoEscaped = ufoEscapedThisLevel || (ufoSpawnedThisLevel && !ufoWasKilled)
        let nextAlienMode = ufoEscaped && !alienMode

        // A friend who survived the level comes along
        let friend = gzhelTank.flatMap { tank -> FriendCarry? in
            guard tank.isAlive else { return nil }
            return FriendCarry(health: tank.health, maxHealth: tank.maxHealth, starCount: tank.starCount,
                               machinegunCount: tank.machinegunCount, bulletPower: tank.bulletPower,
                               speedMultiplier: tank.speedMultiplier, canSwim: tank.canSwim,
                               canDestroyTrees: tank.canDestroyTrees)
        }

        let newScene = GameScene(size: size, level: level + 1, score: score, lives: playerTank.lives, sessionSeed: sessionSeed, powerUps: powerUps, gzhelBorder: earnedGzhel, alienMode: nextAlienMode,
                                 playerCount: playerCount, player2Lives: player2Tank?.lives ?? 3, player2PowerUps: powerUps2,
                                 player2Score: scores[1], friend: friend)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func restartGame() {
        SoundManager.shared.stopGameOver()
        // Restart the SAME level with score reset to 0 (high score persists until menu or app close)
        let newScene = GameScene(size: size, level: level, score: 0, sessionSeed: sessionSeed, playerCount: playerCount)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func goToMenu() {
        SoundManager.shared.stopGameOver()
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

    /// Key → (player, direction or nil for fire), from the keys chosen in Options → Controls.
    /// One player: both players' keys control the single tank.
    private lazy var keyMap: [UIKeyboardHIDUsage: (player: Int, direction: Direction?)] = {
        var map: [UIKeyboardHIDUsage: (player: Int, direction: Direction?)] = [:]
        for player in 0..<2 {
            for action in GameSettings.KeyAction.allCases {
                let key = GameSettings.shared.key(for: action, player: player)
                if map[key] == nil {
                    map[key] = (isTwoPlayer ? player : 0, action.direction)
                }
            }
        }
        return map
    }()

    /// What a key does: move or fire for a player (0 = player 1, 1 = player 2)
    private func keyBinding(_ code: UIKeyboardHIDUsage) -> (player: Int, direction: Direction?)? {
        return keyMap[code]
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key else { continue }

            // Continue/restart on Enter when game over
            if key.keyCode == .keyboardReturnOrEnter && isGameOver {
                if isShowingGameOverScreen {
                    finishGameOverScreen()  // Skip to the statistics
                } else if didWinLevel {
                    nextLevel()
                } else {
                    restartGame()
                }
                continue
            }

            // Pause: Escape or P
            if key.keyCode == .keyboardEscape || key.keyCode == .keyboardP {
                if !isGameOver {
                    togglePause()
                }
                continue
            }

            guard let binding = keyBinding(key.keyCode) else { continue }
            if let direction = binding.direction {
                pressedDirectionKeys.insert(key.keyCode)
                keyboardDirection[binding.player] = direction
            } else {
                keyboardFiring[binding.player] = true
            }
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses {
            guard let key = press.key, let binding = keyBinding(key.keyCode) else { continue }

            if binding.direction != nil {
                pressedDirectionKeys.remove(key.keyCode)
                keyboardDirection[binding.player] = getDirectionFromPressedKeys(player: binding.player)
            } else {
                keyboardFiring[binding.player] = false
            }
        }
    }

    // Keys can be cancelled (app switch, Cmd-Tab) without an "ended" event
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        pressesEnded(presses, with: event)
    }

    /// Direction of a still-held key of this player (after another key was released)
    private func getDirectionFromPressedKeys(player: Int) -> Direction? {
        for keyCode in pressedDirectionKeys {
            if let binding = keyBinding(keyCode), binding.player == player, let direction = binding.direction {
                return direction
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

    private static let keyRightShift: UInt16 = 60

    /// Same bindings as on iOS: see the iOS `keyBinding`
    private func keyBinding(_ code: UInt16) -> (player: Int, direction: Direction?)? {
        let p2 = isTwoPlayer ? 1 : 0
        switch code {
        case GameScene.keyW: return (0, .up)
        case GameScene.keyS: return (0, .down)
        case GameScene.keyA: return (0, .left)
        case GameScene.keyD: return (0, .right)
        case GameScene.keyUp: return (p2, .up)
        case GameScene.keyDown: return (p2, .down)
        case GameScene.keyLeft: return (p2, .left)
        case GameScene.keyRight: return (p2, .right)
        case GameScene.keySpace, GameScene.keyJ: return (0, nil)
        case GameScene.keyReturn, GameScene.keyRightShift:
            return isTwoPlayer ? (1, nil) : nil
        default: return nil
        }
    }

    override func keyDown(with event: NSEvent) {
        // Ignore key repeat
        guard !event.isARepeat else { return }

        let keyCode = event.keyCode

        // Continue/restart on Enter when game over
        if keyCode == GameScene.keyReturn && isGameOver {
            if isShowingGameOverScreen {
                finishGameOverScreen()  // Skip to the statistics
            } else if didWinLevel {
                nextLevel()
            } else {
                restartGame()
            }
            return
        }

        // Pause: P or Escape
        if keyCode == GameScene.keyP || keyCode == GameScene.keyEscape {
            togglePause()
            return
        }

        guard let binding = keyBinding(keyCode) else { return }
        if let direction = binding.direction {
            pressedDirectionKeys.insert(keyCode)
            keyboardDirection[binding.player] = direction
        } else {
            keyboardFiring[binding.player] = true
        }
    }

    override func keyUp(with event: NSEvent) {
        let keyCode = event.keyCode
        guard let binding = keyBinding(keyCode) else { return }

        if binding.direction != nil {
            pressedDirectionKeys.remove(keyCode)
            keyboardDirection[binding.player] = getDirectionFromPressedKeys(player: binding.player)
        } else {
            keyboardFiring[binding.player] = false
        }
    }

    private func getDirectionFromPressedKeys(player: Int) -> Direction? {
        for keyCode in pressedDirectionKeys {
            if let binding = keyBinding(keyCode), binding.player == player, let direction = binding.direction {
                return direction
            }
        }
        return nil
    }
    #endif
}

// MARK: - Notification Names

extension Notification.Name {
    static let gameScoreDidChange = Notification.Name("gameScoreDidChange")
    static let gamePauseRequested = Notification.Name("gamePauseRequested")
}
