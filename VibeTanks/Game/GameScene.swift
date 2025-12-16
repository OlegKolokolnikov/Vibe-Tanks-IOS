import SpriteKit

/// Main game scene
class GameScene: SKScene {

    // Game objects
    private var gameMap: GameMap!
    private var playerTank: Tank!
    private var enemyTanks: [Tank] = []
    private var bullets: [Bullet] = []
    private var base: Base!

    // UI
    private var touchController: TouchController!
    private var scoreLabel: SKLabelNode!
    private var livesLabel: SKLabelNode!

    // Game state
    private var score: Int = 0
    private var isGameOver: Bool = false
    private var isPaused: Bool = false

    // Spawning
    private var enemySpawner: EnemySpawner!

    // Camera for scrolling (if needed)
    private var gameCamera: SKCameraNode!
    private var gameLayer: SKNode!

    override func didMove(to view: SKView) {
        backgroundColor = .black

        setupGame()
        setupUI()
        setupCamera()
    }

    // MARK: - Setup

    private func setupGame() {
        // Create game layer
        gameLayer = SKNode()
        addChild(gameLayer)

        // Create map
        gameMap = GameMap()
        gameLayer.addChild(gameMap)

        // Create base
        let basePosition = CGPoint(
            x: CGFloat(GameConstants.mapWidth / 2) * GameConstants.tileSize,
            y: GameConstants.tileSize * 1.5
        )
        base = Base(position: basePosition)
        gameLayer.addChild(base)

        // Create player tank
        let playerSpawnPos = CGPoint(
            x: GameConstants.tileSize * 4,
            y: GameConstants.tileSize * 2
        )
        playerTank = Tank(
            position: playerSpawnPos,
            direction: .up,
            isPlayer: true,
            playerNumber: 1
        )
        gameLayer.addChild(playerTank)

        // Setup enemy spawner
        enemySpawner = EnemySpawner(
            totalEnemies: GameConstants.totalEnemies,
            maxOnScreen: GameConstants.maxEnemiesOnScreen
        )
    }

    private func setupUI() {
        // Touch controller
        touchController = TouchController()
        touchController.setupForScreen(size: size)
        addChild(touchController)

        // Score label
        scoreLabel = SKLabelNode(text: "Score: 0")
        scoreLabel.fontName = "Helvetica-Bold"
        scoreLabel.fontSize = 20
        scoreLabel.fontColor = .white
        scoreLabel.horizontalAlignmentMode = .left
        scoreLabel.position = CGPoint(x: 20, y: size.height - 40)
        scoreLabel.zPosition = 100
        addChild(scoreLabel)

        // Lives label
        livesLabel = SKLabelNode(text: "Lives: 3")
        livesLabel.fontName = "Helvetica-Bold"
        livesLabel.fontSize = 20
        livesLabel.fontColor = .yellow
        livesLabel.horizontalAlignmentMode = .right
        livesLabel.position = CGPoint(x: size.width - 20, y: size.height - 40)
        livesLabel.zPosition = 100
        addChild(livesLabel)
    }

    private func setupCamera() {
        gameCamera = SKCameraNode()
        camera = gameCamera
        addChild(gameCamera)

        // Center camera on game area
        let mapSize = gameMap.pixelSize
        gameCamera.position = CGPoint(x: mapSize.width / 2, y: mapSize.height / 2)

        // Scale to fit
        let scaleX = size.width / mapSize.width
        let scaleY = size.height / mapSize.height
        let scale = min(scaleX, scaleY) * 0.9
        gameCamera.setScale(1 / scale)
    }

    // MARK: - Game Loop

    override func update(_ currentTime: TimeInterval) {
        guard !isGameOver && !isPaused else { return }

        updatePlayer()
        updateEnemies()
        updateBullets()
        updateSpawner()
        checkCollisions()
        checkGameState()
        updateUI()
    }

    private func updatePlayer() {
        guard playerTank.isAlive else {
            playerTank.updateRespawnTimer()
            return
        }

        // Handle movement from touch controller
        if let direction = touchController.currentDirection {
            playerTank.move(direction: direction, map: gameMap, allTanks: allTanks)
        }

        // Handle shooting
        if touchController.isFiring {
            if let bullet = playerTank.shoot() {
                bullets.append(bullet)
                gameLayer.addChild(bullet)
            }
        }

        playerTank.update(map: gameMap, allTanks: allTanks)
    }

    private func updateEnemies() {
        for enemy in enemyTanks {
            guard enemy.isAlive else { continue }

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

                if shouldShoot, let bullet = enemy.shoot() {
                    bullets.append(bullet)
                    gameLayer.addChild(bullet)
                }
            }

            enemy.update(map: gameMap, allTanks: allTanks)
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

    private func updateSpawner() {
        if let newEnemy = enemySpawner.update(existingEnemies: enemyTanks, map: gameMap) {
            enemyTanks.append(newEnemy)
            gameLayer.addChild(newEnemy)
        }
    }

    // MARK: - Collision Detection

    private func checkCollisions() {
        checkBulletTankCollisions()
        checkBulletBulletCollisions()
        checkBulletBaseCollision()
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
                        }
                        break
                    }
                }
            }
            // Enemy bullets hit player
            else {
                if playerTank.isAlive && !playerTank.hasShield && bullet.collidesWith(playerTank) {
                    playerTank.damage()
                    bulletsToRemove.append(bullet)

                    if !playerTank.isAlive && playerTank.lives > 0 {
                        playerTank.respawn(at: CGPoint(
                            x: GameConstants.tileSize * 4,
                            y: GameConstants.tileSize * 2
                        ))
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
                gameOver(won: false)
                break
            }
        }
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
            gameOver(won: true)
        }

        // Check lose condition
        if playerTank.lives <= 0 && !playerTank.isAlive {
            gameOver(won: false)
        }
    }

    private func gameOver(won: Bool) {
        isGameOver = true

        let message = won ? "VICTORY!" : "GAME OVER"
        let label = SKLabelNode(text: message)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 48
        label.fontColor = won ? .green : .red
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        label.zPosition = 200
        addChild(label)

        // Restart button
        let restartLabel = SKLabelNode(text: "Tap to Restart")
        restartLabel.fontName = "Helvetica"
        restartLabel.fontSize = 24
        restartLabel.fontColor = .white
        restartLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 - 50)
        restartLabel.zPosition = 200
        restartLabel.name = "restart"
        addChild(restartLabel)
    }

    private func updateUI() {
        scoreLabel.text = "Score: \(score)"
        livesLabel.text = "Lives: \(playerTank.lives)"
    }

    // MARK: - Helpers

    private var allTanks: [Tank] {
        return [playerTank] + enemyTanks
    }

    // MARK: - Touch Handling for Restart

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if isGameOver {
            for touch in touches {
                let location = touch.location(in: self)
                if let node = atPoint(location) as? SKLabelNode, node.name == "restart" {
                    restartGame()
                }
            }
        }
    }

    private func restartGame() {
        let newScene = GameScene(size: size)
        newScene.scaleMode = scaleMode
        view?.presentScene(newScene, transition: .fade(withDuration: 0.5))
    }
}
