import SpriteKit

/// Main game scene
class GameScene: SKScene {

    // Game objects
    private var gameMap: GameMap!
    private var playerTank: Tank!
    private var enemyTanks: [Tank] = []
    private var bullets: [Bullet] = []
    private var powerUps: [PowerUp] = []
    private var base: Base!

    // UFO and Easter Egg
    private var ufo: UFO?
    private var easterEgg: EasterEgg?
    private var ufoSpawnedThisLevel: Bool = false
    private var ufoWasKilled: Bool = false
    private var playerKills: Int = 0
    private var ufoMessageTimer: Int = 0
    private var ufoMessageLabel: SKLabelNode?

    // UI
    private var touchController: TouchController!
    private var sidebar: Sidebar!
    private var scoreLabel: SKLabelNode!

    // Game state
    private var score: Int = 0
    private var level: Int = 1
    private var sessionSeed: UInt64 = 0
    private var isGameOver: Bool = false
    private var isGamePaused: Bool = false
    private var didWinLevel: Bool = false

    // Freeze effect
    private var freezeTimer: Int = 0
    private var playerFreezeTimer: Int = 0  // Player frozen by enemy power-up

    // Base protection
    private var baseProtectionTimer: Int = 0
    private var baseFlashTimer: Int = 0
    private var baseIsSteel: Bool = false

    // Keyboard input (for simulator)
    private var keyboardDirection: Direction?
    private var keyboardFiring: Bool = false
    private var pressedDirectionKeys: Set<UIKeyboardHIDUsage> = []

    // Spawning
    private var enemySpawner: EnemySpawner!

    // Camera for scrolling (if needed)
    private var gameCamera: SKCameraNode!
    private var gameLayer: SKNode!

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

    // Level initialization
    init(size: CGSize, level: Int = 1, score: Int = 0, lives: Int = 3, sessionSeed: UInt64 = 0, powerUps: PlayerPowerUps = PlayerPowerUps()) {
        self.level = level
        self.score = score
        self.initialLives = lives
        self.initialPowerUps = powerUps
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

    private func setupGame() {
        // Create game layer
        gameLayer = SKNode()
        addChild(gameLayer)

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
        base = Base(position: basePosition)
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

        gameLayer.addChild(playerTank)

        // Calculate enemies for this level (base 20 + 2 per level)
        let totalEnemies = min(20 + (level - 1) * 2, 50)

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
        gameCamera.addChild(touchController)

        // Score label - positioned at top left with safe margin
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 18
        scoreLabel.fontColor = .white
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

        // Update base protection timer
        updateBaseProtection()

        updatePlayer()
        updateEnemies()
        updateBullets()
        updatePowerUps()
        updateSpawner()
        updateUFO()
        updateEasterEgg()
        checkCollisions()
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

        // Handle movement from touch controller or keyboard (only if not frozen)
        if playerFreezeTimer <= 0 {
            let direction = touchController.currentDirection ?? keyboardDirection
            if let dir = direction {
                playerTank.move(direction: dir, map: gameMap, allTanks: allTanks)
            } else {
                // No input - continue ice slide if player was on ice
                _ = playerTank.continueIceSlide(map: gameMap, allTanks: allTanks)
            }
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
                for bullet in newBullets {
                    bullets.append(bullet)
                    gameLayer.addChild(bullet)
                }
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
                        for bullet in newBullets {
                            bullets.append(bullet)
                            gameLayer.addChild(bullet)
                        }
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
        var bulletsToRemove: [Bullet] = []

        for bullet in bullets {
            bullet.update()

            // Check out of bounds
            if bullet.isOutOfBounds(mapSize: gameMap.pixelSize) {
                bulletsToRemove.append(bullet)
                continue
            }

            // Check map collision
            let (hit, _) = gameMap.checkBulletCollision(
                position: bullet.position,
                power: bullet.power
            )
            if hit {
                bulletsToRemove.append(bullet)
            }
        }

        // Remove bullets
        for bullet in bulletsToRemove {
            removeBullet(bullet)
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
        // Spawn regular enemies
        if let newEnemy = enemySpawner.update(existingEnemies: enemyTanks, map: gameMap) {
            enemyTanks.append(newEnemy)
            gameLayer.addChild(newEnemy)
            showSpawnEffect(at: newEnemy.position)
        }

        // Spawn extra enemies (from tank power-up collection)
        if let extraEnemy = enemySpawner.spawnExtraEnemy(existingEnemies: enemyTanks, map: gameMap) {
            enemyTanks.append(extraEnemy)
            gameLayer.addChild(extraEnemy)
            showSpawnEffect(at: extraEnemy.position)
        }
    }

    /// Show electricity/lightning effect when enemy spawns
    private func showSpawnEffect(at position: CGPoint) {
        let effectNode = SKNode()
        effectNode.position = position
        effectNode.zPosition = 50

        // Create multiple lightning bolts
        for i in 0..<6 {
            let bolt = createLightningBolt()
            bolt.zRotation = CGFloat(i) * .pi / 3  // Spread around 360 degrees
            effectNode.addChild(bolt)
        }

        // Add center flash
        let flash = SKShapeNode(circleOfRadius: 15)
        flash.fillColor = .white
        flash.strokeColor = .cyan
        flash.lineWidth = 2
        flash.glowWidth = 5
        effectNode.addChild(flash)

        gameLayer.addChild(effectNode)

        // Animate: quick flash then fade
        let scaleUp = SKAction.scale(to: 1.3, duration: 0.1)
        let fadeOut = SKAction.fadeOut(withDuration: 0.2)
        let remove = SKAction.removeFromParent()

        effectNode.run(SKAction.sequence([scaleUp, fadeOut, remove]))
    }

    /// Create a single lightning bolt shape
    private func createLightningBolt() -> SKShapeNode {
        let bolt = SKShapeNode()
        let path = CGMutablePath()

        // Zigzag lightning pattern
        path.move(to: CGPoint(x: 0, y: 5))
        path.addLine(to: CGPoint(x: 3, y: 12))
        path.addLine(to: CGPoint(x: -2, y: 18))
        path.addLine(to: CGPoint(x: 4, y: 28))
        path.addLine(to: CGPoint(x: -1, y: 22))
        path.addLine(to: CGPoint(x: 2, y: 15))
        path.addLine(to: CGPoint(x: -3, y: 8))

        bolt.path = path
        bolt.strokeColor = .cyan
        bolt.lineWidth = 2
        bolt.glowWidth = 3
        bolt.lineCap = .round

        return bolt
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

        // Check UFO spawn conditions
        if !ufoSpawnedThisLevel && ufo == nil {
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

    private func showUFOMessage(_ text: String, color: SKColor) {
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

    // MARK: - Collision Detection

    private func checkCollisions() {
        checkBulletTankCollisions()
        checkBulletBulletCollisions()
        checkBulletBaseCollision()
        checkBulletUFOCollisions()
        checkPowerUpCollisions()
        checkEasterEggCollisions()
    }

    private func checkBulletTankCollisions() {
        var bulletsToRemove: [Bullet] = []
        var enemiesToRemove: [Tank] = []

        for bullet in bullets {
            // Player bullets hit enemies
            if !bullet.isFromEnemy {
                for enemy in enemyTanks {
                    if enemy.isAlive && bullet.collidesWith(enemy) {
                        enemy.damage()
                        bulletsToRemove.append(bullet)

                        if !enemy.isAlive {
                            enemiesToRemove.append(enemy)
                            score += GameConstants.scoreForEnemyType(enemy.enemyType)
                            playerKills += 1
                            SoundManager.shared.playExplosion()

                            // Power enemies drop power-ups
                            if enemy.enemyType == .power {
                                spawnPowerUp(at: enemy.position)
                            }
                        }
                        break
                    }
                }
            }
            // Enemy bullets hit player
            else {
                if playerTank.isAlive && bullet.collidesWith(playerTank) {
                    if playerTank.hasShield {
                        // Bullet hits shield - destroy bullet but don't damage player
                        bulletsToRemove.append(bullet)
                        // Optional: play shield hit sound
                    } else {
                        // No shield - damage player
                        playerTank.damage()
                        bulletsToRemove.append(bullet)

                        if !playerTank.isAlive {
                            SoundManager.shared.playPlayerDeath()
                        }

                        if !playerTank.isAlive && playerTank.lives > 0 {
                            playerTank.respawn(at: CGPoint(
                                x: GameConstants.tileSize * 8,
                                y: GameConstants.tileSize * 2
                            ))
                        }
                    }
                }
            }
        }

        // Remove destroyed bullets
        for bullet in bulletsToRemove {
            removeBullet(bullet)
        }

        // Remove destroyed enemies
        for enemy in enemiesToRemove {
            enemy.removeFromParent()
            enemyTanks.removeAll { $0 === enemy }
        }
    }

    private func checkBulletBulletCollisions() {
        guard bullets.count >= 2 else { return }

        var bulletsToRemove: Set<Bullet> = []

        for i in 0..<bullets.count {
            for j in (i+1)..<bullets.count {
                if bullets[i].collidesWith(bullets[j]) {
                    bulletsToRemove.insert(bullets[i])
                    bulletsToRemove.insert(bullets[j])
                }
            }
        }

        for bullet in bulletsToRemove {
            removeBullet(bullet)
        }
    }

    private func checkBulletBaseCollision() {
        for bullet in bullets {
            if base.checkCollision(bulletPosition: bullet.position) {
                base.destroy()
                removeBullet(bullet)
                SoundManager.shared.playBaseDestroyed()
                gameOver(won: false)
                break
            }
        }
    }

    private func checkBulletUFOCollisions() {
        guard let currentUFO = ufo, currentUFO.isAlive else { return }

        for bullet in bullets {
            if currentUFO.collidesWith(bullet) {
                removeBullet(bullet)

                if currentUFO.damage() {
                    // UFO destroyed - spawn easter egg at random empty position
                    ufoWasKilled = true
                    currentUFO.createDestroyEffect()
                    currentUFO.removeFromParent()

                    // Spawn easter egg at random empty position (like original game)
                    let eggPosition = findRandomEmptyPosition()
                    easterEgg = EasterEgg(x: eggPosition.x, y: eggPosition.y)
                    gameLayer.addChild(easterEgg!)

                    showUFOMessage("UFO DESTROYED!", color: .green)
                    ufo = nil
                }
                break
            }
        }
    }

    private func checkEasterEggCollisions() {
        guard let egg = easterEgg, !egg.isCollected else { return }

        // Check player collision
        if playerTank.isAlive && egg.collidesWith(playerTank) {
            // Player collected the easter egg!
            egg.collect()
            easterEgg = nil

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
            playerFreezeTimer = 1800  // 30 seconds at 60fps
            addFreezeEffectToPlayer()
            showEffect(text: "PLAYER FROZEN!", color: .red)
        case .bomb:
            // Damages player!
            if !playerTank.hasShield {
                playerTank.damage()
                showEffect(text: "PLAYER HIT!", color: .red)
            }
        case .shovel:
            // Enemy removes base protection
            removeBaseProtection()
            showEffect(text: "BASE EXPOSED!", color: .red)
        case .saw:
            // Enemy can break forest
            enemy.canDestroyTrees = true
            showEffect(text: "ENEMY SAW!", color: .red)
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
        switch powerUp.type {
        case .freeze:
            // Freeze enemies for 30 seconds with animation
            freezeTimer = 1800  // 30 seconds at 60fps
            addFreezeEffectToEnemies()
            showEffect(text: "FREEZE!", color: .cyan)
        case .bomb:
            destroyAllEnemies()
            showEffect(text: "BOMB!", color: .red)
        case .shovel:
            // Base gets steel protection for 60 seconds
            activateBaseProtection()
            showEffect(text: "STEEL BASE!", color: .gray)
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
                score += GameConstants.scoreForEnemyType(enemy.enemyType)
                enemy.removeFromParent()
            }
        }
        enemyTanks.removeAll()
    }

    // MARK: - Base Protection

    /// Activate steel protection around base for 60 seconds
    private func activateBaseProtection() {
        baseProtectionTimer = 3600  // 60 seconds at 60fps
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

    private func spawnPowerUp(at position: CGPoint) {
        // Find random empty position instead of spawning at enemy location
        let spawnPosition = findRandomEmptyPosition()
        let powerUp = PowerUp(position: spawnPosition)
        powerUps.append(powerUp)
        gameLayer.addChild(powerUp)
        SoundManager.shared.playPowerUpSpawn()
    }

    private func findRandomEmptyPosition() -> CGPoint {
        let tileSize = GameConstants.tileSize
        let maxAttempts = 100

        for _ in 0..<maxAttempts {
            // Random position within playable area (avoiding borders)
            let col = 2 + Int.random(in: 0..<22) // 2 to 23
            let row = 2 + Int.random(in: 0..<22)

            // Check if position is clear (only spawn on empty tiles)
            let checkPosition = CGPoint(
                x: CGFloat(col) * tileSize + tileSize / 2,
                y: CGFloat(GameConstants.mapHeight - 1 - row) * tileSize + tileSize / 2
            )

            if gameMap.getTile(at: checkPosition) == .empty {
                return checkPosition
            }
        }

        // Fallback to center if no valid position found
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

    private func removeBullet(_ bullet: Bullet) {
        bullet.owner?.bulletDestroyed()
        bullet.removeFromParent()
        bullets.removeAll { $0 === bullet }
    }

    // MARK: - Game State

    private func checkGameState() {
        // Check win condition
        if enemySpawner.allEnemiesDefeated(currentEnemies: enemyTanks) {
            levelComplete()
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

        let cameraScale = gameCamera.xScale

        let label = SKLabelNode(text: "LEVEL \(level) COMPLETE!")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 36 * cameraScale
        label.fontColor = .green
        label.position = CGPoint(x: 0, y: 50 * cameraScale)
        label.zPosition = 200
        gameCamera.addChild(label)

        // Score
        let scoreText = SKLabelNode(text: "Score: \(score)")
        scoreText.fontName = "Helvetica-Bold"
        scoreText.fontSize = 20 * cameraScale
        scoreText.fontColor = .yellow
        scoreText.position = CGPoint(x: 0, y: 10 * cameraScale)
        scoreText.zPosition = 200
        gameCamera.addChild(scoreText)

        // Next level button
        let nextButton = createPauseButton(text: "NEXT LEVEL", cameraScale: cameraScale)
        nextButton.position = CGPoint(x: 0, y: -40 * cameraScale)
        nextButton.zPosition = 200
        nextButton.name = "nextLevelButton"
        gameCamera.addChild(nextButton)

        // Menu button
        let menuButton = createPauseButton(text: "MENU", cameraScale: cameraScale)
        menuButton.position = CGPoint(x: 0, y: -100 * cameraScale)
        menuButton.zPosition = 200
        menuButton.name = "menuButton"
        gameCamera.addChild(menuButton)
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

    private func gameOver(won: Bool) {
        isGameOver = true
        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.playGameOver()

        let cameraScale = gameCamera.xScale

        let message = won ? "VICTORY!" : "GAME OVER"
        let label = SKLabelNode(text: message)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 48 * cameraScale
        label.fontColor = won ? .green : .red
        label.position = CGPoint(x: 0, y: 50 * cameraScale)
        label.zPosition = 200
        gameCamera.addChild(label)

        // Show final score
        let scoreText = SKLabelNode(text: "Final Score: \(score)")
        scoreText.fontName = "Helvetica-Bold"
        scoreText.fontSize = 24 * cameraScale
        scoreText.fontColor = .yellow
        scoreText.position = CGPoint(x: 0, y: 0 * cameraScale)
        scoreText.zPosition = 200
        gameCamera.addChild(scoreText)

        // Restart button
        let restartButton = createPauseButton(text: "RESTART", cameraScale: cameraScale)
        restartButton.position = CGPoint(x: 0, y: -50 * cameraScale)
        restartButton.zPosition = 200
        restartButton.name = "restartButton"
        gameCamera.addChild(restartButton)

        // Menu button
        let menuButton = createPauseButton(text: "MENU", cameraScale: cameraScale)
        menuButton.position = CGPoint(x: 0, y: -110 * cameraScale)
        menuButton.zPosition = 200
        menuButton.name = "menuButton"
        gameCamera.addChild(menuButton)
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

    // MARK: - Helpers

    private var allTanks: [Tank] {
        return [playerTank] + enemyTanks
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

        let newScene = GameScene(size: size, level: level + 1, score: score, lives: playerTank.lives, sessionSeed: sessionSeed, powerUps: powerUps)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func restartGame() {
        // Keep same session seed so level 1 is the same as when we started
        let newScene = GameScene(size: size, level: 1, score: 0, sessionSeed: sessionSeed)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }

    private func goToMenu() {
        SoundManager.shared.stopGameplaySounds()
        SoundManager.shared.stopBackgroundMusic()
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = scaleMode
        view?.presentScene(menuScene, transition: .fade(withDuration: 0.5))
    }

    // MARK: - Keyboard Support (for Simulator)

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

            // Restart on Enter when game over
            case .keyboardReturnOrEnter:
                if isGameOver {
                    restartGame()
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
                // Update direction based on remaining pressed keys
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
        // Return direction based on any still-pressed direction key
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
}
