import SpriteKit

/// Tank entity - player or enemy
class Tank: SKSpriteNode {

    enum EnemyType: Int, CaseIterable {
        case regular = 0
        case fast = 1
        case armored = 2
        case power = 3
        case heavy = 4
        case boss = 5
    }

    // Properties
    var isPlayer: Bool
    var playerNumber: Int
    var enemyType: EnemyType
    var direction: Direction = .up

    // Stats
    var health: Int = 1
    var maxHealth: Int = 1
    var lives: Int = 3
    var speed: CGFloat

    // Combat
    var bulletPower: Int = 1
    var activeBullets: Int = 0
    var maxBullets: Int = GameConstants.maxBulletsPerTank
    var shootCooldown: Int = 0

    // Power-ups
    var hasShield: Bool = false
    var shieldTimer: Int = 0
    var hasRapidFire: Bool = false
    var speedMultiplier: CGFloat = 1.0

    // Respawn
    var respawnTimer: Int = 0
    var pendingRespawnPosition: CGPoint?

    // Animation
    private var trackFrame: Int = 0

    // AI (for enemies)
    var ai: TankAI?

    init(position: CGPoint, direction: Direction, isPlayer: Bool, playerNumber: Int, enemyType: EnemyType = .regular) {
        self.isPlayer = isPlayer
        self.playerNumber = playerNumber
        self.enemyType = enemyType

        // Set speed based on type
        if isPlayer {
            self.speed = GameConstants.tankSpeed
        } else {
            switch enemyType {
            case .fast:
                self.speed = GameConstants.enemyTankSpeed * 1.5
            case .boss:
                self.speed = GameConstants.enemyTankSpeed * 0.6
            default:
                self.speed = GameConstants.enemyTankSpeed
            }
        }

        // Set health based on type
        switch enemyType {
        case .armored:
            self.health = 2
            self.maxHealth = 2
        case .power:
            self.health = 2
            self.maxHealth = 2
            self.bulletPower = 2
        case .heavy:
            self.health = 3
            self.maxHealth = 3
            self.bulletPower = 2
        case .boss:
            self.health = GameConstants.bossBaseHealth
            self.maxHealth = GameConstants.bossBaseHealth
        default:
            self.health = 1
            self.maxHealth = 1
        }

        // Create tank texture
        let size = enemyType == .boss ? GameConstants.bossTankSize : GameConstants.tankSize
        let color = isPlayer ? SKColor.yellow : SKColor.gray

        super.init(texture: nil, color: color, size: CGSize(width: size, height: size))

        self.position = position
        self.direction = direction
        self.zRotation = direction.rotation
        self.zPosition = 10

        // Setup physics body for collision detection
        self.physicsBody = SKPhysicsBody(rectangleOf: self.size)
        self.physicsBody?.isDynamic = true
        self.physicsBody?.affectedByGravity = false
        self.physicsBody?.allowsRotation = false
        self.physicsBody?.categoryBitMask = isPlayer ? PhysicsCategory.player : PhysicsCategory.enemy
        self.physicsBody?.contactTestBitMask = PhysicsCategory.bullet | PhysicsCategory.wall
        self.physicsBody?.collisionBitMask = PhysicsCategory.wall | PhysicsCategory.player | PhysicsCategory.enemy

        // Initialize AI for enemy tanks
        if !isPlayer {
            ai = TankAI(tank: self)
        }

        drawTank()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Drawing

    private func drawTank() {
        // Remove old children
        removeAllChildren()

        let tankSize = self.size.width
        let bodySize = tankSize * 0.7
        let trackWidth = tankSize * 0.15
        let gunLength = tankSize * 0.5
        let gunWidth = tankSize * 0.12

        // Tank body
        let body = SKShapeNode(rectOf: CGSize(width: bodySize, height: bodySize))
        body.fillColor = isPlayer ? playerColor : enemyColor
        body.strokeColor = .black
        body.lineWidth = 1
        addChild(body)

        // Left track
        let leftTrack = SKShapeNode(rectOf: CGSize(width: trackWidth, height: tankSize))
        leftTrack.position = CGPoint(x: -(bodySize/2 + trackWidth/2), y: 0)
        leftTrack.fillColor = .darkGray
        leftTrack.strokeColor = .black
        addChild(leftTrack)

        // Right track
        let rightTrack = SKShapeNode(rectOf: CGSize(width: trackWidth, height: tankSize))
        rightTrack.position = CGPoint(x: bodySize/2 + trackWidth/2, y: 0)
        rightTrack.fillColor = .darkGray
        rightTrack.strokeColor = .black
        addChild(rightTrack)

        // Gun
        let gun = SKShapeNode(rectOf: CGSize(width: gunWidth, height: gunLength))
        gun.position = CGPoint(x: 0, y: bodySize/2 + gunLength/2 - 5)
        gun.fillColor = isPlayer ? playerColor.darker() : enemyColor.darker()
        gun.strokeColor = .black
        addChild(gun)

        // Shield indicator
        if hasShield {
            let shield = SKShapeNode(circleOfRadius: tankSize * 0.6)
            shield.strokeColor = .cyan
            shield.lineWidth = 2
            shield.fillColor = SKColor.cyan.withAlphaComponent(0.2)
            shield.name = "shield"
            addChild(shield)
        }
    }

    private var playerColor: SKColor {
        switch playerNumber {
        case 1: return SKColor(hex: "#FFD700") // Gold
        case 2: return SKColor(hex: "#00FF00") // Green
        case 3: return SKColor(hex: "#FF6600") // Orange
        case 4: return SKColor(hex: "#FF00FF") // Magenta
        default: return .yellow
        }
    }

    private var enemyColor: SKColor {
        switch enemyType {
        case .regular: return .lightGray
        case .fast: return SKColor(hex: "#87CEEB") // Light blue
        case .armored: return SKColor(hex: "#228B22") // Forest green
        case .power: return SKColor(hex: "#FF4444") // Red
        case .heavy: return SKColor(hex: "#8B0000") // Dark red
        case .boss: return SKColor(hex: "#4B0082") // Indigo
        }
    }

    // MARK: - Movement

    func move(direction: Direction, map: GameMap, allTanks: [Tank]) {
        self.direction = direction
        self.zRotation = direction.rotation

        let velocity = direction.velocity
        let moveSpeed = speed * speedMultiplier
        let newX = position.x + velocity.dx * moveSpeed
        let newY = position.y + velocity.dy * moveSpeed

        let newPosition = CGPoint(x: newX, y: newY)

        // Check collision with map
        if !map.checkTankCollision(position: newPosition, size: self.size.width) {
            // Check collision with other tanks
            var canMove = true
            for tank in allTanks {
                if tank !== self && tank.isAlive {
                    if checkCollision(with: tank, at: newPosition) {
                        canMove = false
                        break
                    }
                }
            }

            if canMove {
                position = newPosition
            }
        }

        // Animate tracks
        trackFrame = (trackFrame + 1) % 4
    }

    private func checkCollision(with other: Tank, at newPosition: CGPoint) -> Bool {
        let mySize = self.size.width / 2
        let otherSize = other.size.width / 2
        let minDist = mySize + otherSize

        let dx = abs(newPosition.x - other.position.x)
        let dy = abs(newPosition.y - other.position.y)

        return dx < minDist && dy < minDist
    }

    // MARK: - Combat

    var canShoot: Bool {
        return activeBullets < maxBullets && shootCooldown <= 0 && isAlive
    }

    func shoot() -> Bullet? {
        guard canShoot else { return nil }

        activeBullets += 1
        shootCooldown = hasRapidFire ? 10 : 20

        let bulletOffset: CGFloat = size.width / 2 + GameConstants.bulletSize / 2
        let bulletPosition = CGPoint(
            x: position.x + direction.velocity.dx * bulletOffset,
            y: position.y + direction.velocity.dy * bulletOffset
        )

        return Bullet(
            position: bulletPosition,
            direction: direction,
            owner: self,
            power: bulletPower
        )
    }

    func bulletDestroyed() {
        activeBullets = max(0, activeBullets - 1)
    }

    func damage() {
        if hasShield { return }

        health -= 1
        if health <= 0 {
            die()
        } else {
            // Flash red
            let flash = SKAction.sequence([
                SKAction.colorize(with: .red, colorBlendFactor: 1.0, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
            ])
            run(flash)
        }
    }

    private func die() {
        if isPlayer {
            lives -= 1
            isHidden = true
            if lives > 0 {
                // Will respawn
            }
        } else {
            // Enemy death handled by game scene
        }
    }

    var isAlive: Bool {
        return health > 0
    }

    var isWaitingToRespawn: Bool {
        return respawnTimer > 0
    }

    func respawn(at position: CGPoint) {
        pendingRespawnPosition = position
        respawnTimer = GameConstants.respawnDelay
    }

    func updateRespawnTimer() {
        if respawnTimer > 0 {
            respawnTimer -= 1
            if respawnTimer == 0 {
                completeRespawn()
            }
        }
    }

    private func completeRespawn() {
        guard let pos = pendingRespawnPosition else { return }
        position = pos
        health = maxHealth
        isHidden = false
        hasShield = true
        shieldTimer = 180 // 3 seconds of shield
        drawTank()
    }

    // MARK: - Update

    func update(map: GameMap, allTanks: [Tank]) {
        // Update cooldowns
        if shootCooldown > 0 {
            shootCooldown -= 1
        }

        // Update shield
        if hasShield {
            shieldTimer -= 1
            if shieldTimer <= 0 {
                hasShield = false
                childNode(withName: "shield")?.removeFromParent()
            }
        }

        // Update respawn
        updateRespawnTimer()
    }
}

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none: UInt32 = 0
    static let player: UInt32 = 0b1
    static let enemy: UInt32 = 0b10
    static let bullet: UInt32 = 0b100
    static let wall: UInt32 = 0b1000
    static let powerUp: UInt32 = 0b10000
    static let base: UInt32 = 0b100000
}

// MARK: - Color Extensions

extension SKColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }

    func darker(by percentage: CGFloat = 0.3) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: max(r - percentage, 0),
                       green: max(g - percentage, 0),
                       blue: max(b - percentage, 0),
                       alpha: a)
    }
}
