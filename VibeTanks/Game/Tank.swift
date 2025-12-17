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
    var moveSpeed: CGFloat

    // Combat
    var bulletPower: Int = 1
    var activeBullets: Int = 0
    var maxBullets: Int = GameConstants.maxBulletsPerTank
    var shootCooldown: Int = 0

    // Power-ups
    var hasShield: Bool = false
    var shieldTimer: Int = 0
    var speedMultiplier: CGFloat = 1.0
    var starCount: Int = 0           // Faster shooting (stackable)
    var canSwim: Bool = false         // SHIP power-up
    var canDestroyTrees: Bool = false // SAW power-up
    var machinegunCount: Int = 0      // Extra bullets (stackable)

    // Respawn
    var respawnTimer: Int = 0
    var pendingRespawnPosition: CGPoint?

    // Track animation
    private var trackFrame: Int = 0
    private var cachedTextures: [SKTexture] = []

    // Ice sliding
    private var isOnIce: Bool = false
    private var slideDirection: Direction?
    private var slideDistance: CGFloat = 0
    private let iceSlideDistance: CGFloat = 32  // One tile
    private let iceSpeedBoost: CGFloat = 1.3    // 30% faster on ice

    // AI (for enemies)
    var ai: TankAI?

    init(position: CGPoint, direction: Direction, isPlayer: Bool, playerNumber: Int, enemyType: EnemyType = .regular) {
        self.isPlayer = isPlayer
        self.playerNumber = playerNumber
        self.enemyType = enemyType

        // Set speed based on type
        if isPlayer {
            self.moveSpeed = GameConstants.tankSpeed
        } else {
            switch enemyType {
            case .fast:
                self.moveSpeed = GameConstants.enemyTankSpeed * 1.5
            case .boss:
                self.moveSpeed = GameConstants.enemyTankSpeed * 0.6
            default:
                self.moveSpeed = GameConstants.enemyTankSpeed
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
            // POWER tanks don't have bulletPower 2 - only player gets that from GUN power-up
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
        cachedTextures.removeAll()

        let tankSize = self.size.width

        // Get colors based on type
        let (mainColor, darkColor) = getTankColors()

        // Pre-render 2 frames for track animation (alternating)
        let scale = tankSize / GameConstants.tankSize
        for i in 0..<2 {
            let offset = CGFloat(i) * 2.5 * scale
            let texture = Tank.renderTankTexture(
                size: tankSize,
                mainColor: mainColor,
                darkColor: darkColor,
                isPlayer: isPlayer,
                enemyType: enemyType,
                trackOffset: offset
            )
            cachedTextures.append(texture)
        }

        // Use single sprite with first frame
        let tankSprite = SKSpriteNode(texture: cachedTextures[0])
        tankSprite.size = CGSize(width: tankSize, height: tankSize)
        tankSprite.name = "tankBody"
        addChild(tankSprite)

        // === Shield indicator ===
        if hasShield {
            addShieldEffect(tankSize: tankSize)
        }

        // === SHIP indicator (can swim) ===
        if canSwim {
            addShipIndicator(tankSize: tankSize)
        }

        // === Start rainbow animation for POWER tanks ===
        if !isPlayer && enemyType == .power {
            startRainbowAnimation()
        }
    }

    /// Render tank to texture for better performance (no SKShapeNodes at runtime)
    private static func renderTankTexture(size: CGFloat, mainColor: SKColor, darkColor: SKColor, isPlayer: Bool, enemyType: EnemyType, trackOffset: CGFloat = 0) -> SKTexture {
        let scale = size / GameConstants.tankSize

        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            let center = size / 2

            // Flip coordinate system to match SpriteKit (origin at bottom-left)
            ctx.translateBy(x: 0, y: size)
            ctx.scaleBy(x: 1, y: -1)

            // === TRACKS (simple blocky style) ===
            let trackWidth: CGFloat = 6 * scale

            // Track background
            ctx.setFillColor(darkColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: trackWidth, height: size))
            ctx.fill(CGRect(x: size - trackWidth, y: 0, width: trackWidth, height: size))

            // Track treads (animated)
            let treadColor = UIColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            ctx.setFillColor(treadColor.cgColor)
            let treadSpacing: CGFloat = 4 * scale
            let treadHeight: CGFloat = 2 * scale
            let numTreads = Int(size / treadSpacing) + 2

            for i in 0..<numTreads {
                let baseY = CGFloat(i) * treadSpacing + trackOffset
                let y = baseY.truncatingRemainder(dividingBy: size + treadSpacing) - treadSpacing
                if y >= 0 && y <= size {
                    ctx.fill(CGRect(x: 1 * scale, y: y, width: trackWidth - 2 * scale, height: treadHeight))
                    ctx.fill(CGRect(x: size - trackWidth + 1 * scale, y: y, width: trackWidth - 2 * scale, height: treadHeight))
                }
            }

            // === HULL (main body - simple rectangle) ===
            let hullLeft = trackWidth
            let hullRight = size - trackWidth
            let hullWidth = hullRight - hullLeft
            let hullBottom: CGFloat = 2 * scale
            let hullTop = size - 2 * scale

            // Hull body
            ctx.setFillColor(mainColor.cgColor)
            ctx.fill(CGRect(x: hullLeft, y: hullBottom, width: hullWidth, height: hullTop - hullBottom))

            // Hull outline
            ctx.setStrokeColor(darkColor.cgColor)
            ctx.setLineWidth(1 * scale)
            ctx.stroke(CGRect(x: hullLeft, y: hullBottom, width: hullWidth, height: hullTop - hullBottom))

            // === TURRET (simple circle) ===
            let turretRadius: CGFloat = 6 * scale
            let turretCenterY = center - 1 * scale

            ctx.setFillColor(mainColor.cgColor)
            ctx.fillEllipse(in: CGRect(
                x: center - turretRadius,
                y: turretCenterY - turretRadius,
                width: turretRadius * 2,
                height: turretRadius * 2
            ))

            // Turret outline
            ctx.setStrokeColor(darkColor.cgColor)
            ctx.setLineWidth(1.5 * scale)
            ctx.strokeEllipse(in: CGRect(
                x: center - turretRadius,
                y: turretCenterY - turretRadius,
                width: turretRadius * 2,
                height: turretRadius * 2
            ))

            // === GUN BARREL ===
            let barrelWidth: CGFloat = 4 * scale
            let barrelLength: CGFloat = size / 2 + 2 * scale
            let barrelStartY = turretCenterY + turretRadius - 2 * scale

            // Barrel
            ctx.setFillColor(darkColor.cgColor)
            ctx.fill(CGRect(
                x: center - barrelWidth / 2,
                y: barrelStartY,
                width: barrelWidth,
                height: barrelLength
            ))

            // Barrel highlight
            ctx.setFillColor(mainColor.darker(by: 0.1).cgColor)
            ctx.fill(CGRect(
                x: center - barrelWidth / 2 + 1 * scale,
                y: barrelStartY,
                width: barrelWidth - 2 * scale,
                height: barrelLength - 2 * scale
            ))

            // === ENEMY TYPE MARKINGS ===
            if !isPlayer {
                switch enemyType {
                case .fast:
                    // White stripe
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
                    ctx.fill(CGRect(x: center - 1 * scale, y: hullBottom + 3 * scale, width: 2 * scale, height: 6 * scale))
                case .armored:
                    // Side plates
                    ctx.setFillColor(UIColor.gray.cgColor)
                    ctx.fill(CGRect(x: hullLeft + 1 * scale, y: center - 3 * scale, width: 2 * scale, height: 6 * scale))
                    ctx.fill(CGRect(x: hullRight - 3 * scale, y: center - 3 * scale, width: 2 * scale, height: 6 * scale))
                case .heavy:
                    // Cross mark
                    ctx.setFillColor(UIColor.white.withAlphaComponent(0.4).cgColor)
                    ctx.fill(CGRect(x: center - 4 * scale, y: turretCenterY - 0.5 * scale, width: 8 * scale, height: 1 * scale))
                    ctx.fill(CGRect(x: center - 0.5 * scale, y: turretCenterY - 4 * scale, width: 1 * scale, height: 8 * scale))
                case .boss:
                    // Red star
                    ctx.setFillColor(UIColor.red.cgColor)
                    ctx.fillEllipse(in: CGRect(x: center - 3 * scale, y: turretCenterY - 3 * scale, width: 6 * scale, height: 6 * scale))
                default:
                    break
                }
            } else {
                // Player star
                ctx.setFillColor(UIColor.white.withAlphaComponent(0.5).cgColor)
                ctx.fillEllipse(in: CGRect(
                    x: center - 2 * scale,
                    y: hullBottom + 3 * scale,
                    width: 4 * scale,
                    height: 4 * scale
                ))
            }
        }

        return SKTexture(image: image)
    }

    private func getTankColors() -> (main: SKColor, dark: SKColor) {
        if isPlayer {
            let main = playerColor
            return (main, main.darker())
        } else {
            switch enemyType {
            case .regular:
                return (.red, SKColor(red: 0.55, green: 0, blue: 0, alpha: 1))
            case .armored:
                return (SKColor(red: 0.55, green: 0, blue: 0, alpha: 1), SKColor(red: 0.31, green: 0, blue: 0, alpha: 1))
            case .fast:
                return (SKColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1), SKColor(red: 0.78, green: 0.24, blue: 0.24, alpha: 1))
            case .power:
                // Start with red, rainbow animation will be added separately
                return (.red, SKColor(red: 0.55, green: 0, blue: 0, alpha: 1))
            case .boss:
                // Pulsing red/orange
                let pulse = (sin(CACurrentMediaTime() * 4) + 1) / 2
                let red = 0.59 + pulse * 0.41
                let green = pulse * 0.2
                return (SKColor(red: red, green: green, blue: 0, alpha: 1), SKColor(red: red * 0.6, green: 0, blue: 0, alpha: 1))
            case .heavy:
                return (.darkGray, .black)
            }
        }
    }

    private func startRainbowAnimation() {
        // Rainbow colors for POWER tanks
        let rainbowColors: [SKColor] = [.red, .orange, .yellow, .green, .cyan, .blue, .purple]

        // Create color cycling action
        var colorActions: [SKAction] = []
        for color in rainbowColors {
            let changeColor = SKAction.run { [weak self] in
                self?.updateTankTexture(mainColor: color, darkColor: color.darker())
            }
            let wait = SKAction.wait(forDuration: 0.5)
            colorActions.append(changeColor)
            colorActions.append(wait)
        }

        let rainbowCycle = SKAction.sequence(colorActions)
        let repeatForever = SKAction.repeatForever(rainbowCycle)
        run(repeatForever, withKey: "rainbowAnimation")
    }

    private func updateTankTexture(mainColor: SKColor, darkColor: SKColor) {
        let tankSize = self.size.width

        // Re-render texture with new colors
        let texture = Tank.renderTankTexture(
            size: tankSize,
            mainColor: mainColor,
            darkColor: darkColor,
            isPlayer: isPlayer,
            enemyType: enemyType,
            trackOffset: 0
        )

        // Update the tank sprite
        if let tankSprite = childNode(withName: "tankBody") as? SKSpriteNode {
            tankSprite.texture = texture
        }
    }



    private func addShieldEffect(tankSize: CGFloat) {
        let shieldContainer = SKNode()
        shieldContainer.name = "shield"

        // Create waving shield effect with multiple circles
        let radius = tankSize * 0.65

        // Main shield circle
        let shield1 = SKShapeNode(circleOfRadius: radius)
        shield1.strokeColor = .cyan
        shield1.lineWidth = 2
        shield1.fillColor = .clear
        shieldContainer.addChild(shield1)

        // Second circle slightly offset for wave effect
        let shield2 = SKShapeNode(circleOfRadius: radius)
        shield2.strokeColor = SKColor.cyan.withAlphaComponent(0.6)
        shield2.lineWidth = 2
        shield2.fillColor = .clear
        shieldContainer.addChild(shield2)

        // Third circle
        let shield3 = SKShapeNode(circleOfRadius: radius)
        shield3.strokeColor = SKColor.white.withAlphaComponent(0.4)
        shield3.lineWidth = 1
        shield3.fillColor = .clear
        shieldContainer.addChild(shield3)

        // Waving animation - circles pulse at different phases
        let wave1 = SKAction.sequence([
            SKAction.scale(to: 1.1, duration: 0.15),
            SKAction.scale(to: 0.95, duration: 0.15)
        ])
        shield1.run(SKAction.repeatForever(wave1))

        let wave2 = SKAction.sequence([
            SKAction.scale(to: 0.95, duration: 0.15),
            SKAction.scale(to: 1.1, duration: 0.15)
        ])
        shield2.run(SKAction.repeatForever(wave2))

        let wave3 = SKAction.sequence([
            SKAction.scale(to: 1.05, duration: 0.1),
            SKAction.scale(to: 1.0, duration: 0.1)
        ])
        shield3.run(SKAction.repeatForever(wave3))

        // Rotate the whole shield
        let rotate = SKAction.rotate(byAngle: .pi * 2, duration: 1.0)
        shieldContainer.run(SKAction.repeatForever(rotate))

        addChild(shieldContainer)
    }

    private func addShipIndicator(tankSize: CGFloat) {
        let shipContainer = SKNode()
        shipContainer.name = "shipIndicator"

        // Create triangle around tank
        let triangleSize = tankSize * 0.8
        let triangle = SKShapeNode()
        let path = CGMutablePath()

        // Triangle pointing up, surrounding the tank
        path.move(to: CGPoint(x: 0, y: triangleSize))           // Top
        path.addLine(to: CGPoint(x: -triangleSize * 0.7, y: -triangleSize * 0.5))  // Bottom left
        path.addLine(to: CGPoint(x: triangleSize * 0.7, y: -triangleSize * 0.5))   // Bottom right
        path.closeSubpath()

        triangle.path = path
        triangle.fillColor = SKColor.blue.withAlphaComponent(0.2)
        triangle.strokeColor = .cyan
        triangle.lineWidth = 2
        triangle.glowWidth = 1
        shipContainer.addChild(triangle)

        // Subtle bobbing animation
        let bob = SKAction.sequence([
            SKAction.moveBy(x: 0, y: 2, duration: 0.3),
            SKAction.moveBy(x: 0, y: -2, duration: 0.3)
        ])
        shipContainer.run(SKAction.repeatForever(bob))

        addChild(shipContainer)
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
        case .regular: return SKColor(hex: "#FF0000") // Red
        case .fast: return SKColor(hex: "#FF6666") // Light red
        case .armored: return SKColor(hex: "#8B0000") // Dark red
        case .power: return SKColor(hex: "#FF0000") // Red (will be rainbow animated)
        case .heavy: return SKColor(hex: "#505050") // Dark gray
        case .boss: return SKColor(hex: "#FF4500") // Orange-red
        }
    }

    // MARK: - Movement

    func move(direction: Direction, map: GameMap, allTanks: [Tank]) {
        // Check if on ice
        let wasOnIce = isOnIce
        isOnIce = map.isIceTile(at: position)

        // If we were sliding and now changing direction or on ice with new input
        if isOnIce && slideDirection != nil && slideDirection != direction {
            // Player is trying to change direction while sliding - start new slide
            slideDirection = direction
            slideDistance = 0
        }

        // First, update direction and rotation
        self.direction = direction
        self.zRotation = direction.rotation

        let velocity = direction.velocity
        // Speed boost on ice
        let iceMultiplier: CGFloat = isOnIce ? iceSpeedBoost : 1.0
        let actualMoveSpeed = moveSpeed * speedMultiplier * iceMultiplier
        let newX = position.x + velocity.dx * actualMoveSpeed
        let newY = position.y + velocity.dy * actualMoveSpeed

        let newPosition = CGPoint(x: newX, y: newY)

        var didMove = false
        var finalPosition = newPosition

        // Check collision with map
        if !map.checkTankCollision(position: newPosition, size: self.size.width, canSwim: canSwim) {
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
                finalPosition = newPosition
                didMove = true
            }
        }

        // If blocked, try sliding to align with tile grid (like original Battle City)
        if !didMove {
            if let slidePos = trySlideMove(direction: direction, map: map, allTanks: allTanks) {
                finalPosition = slidePos
                didMove = true
            }
        }

        if didMove {
            position = finalPosition
            animateTracks()

            // Track ice sliding
            if isOnIce {
                slideDirection = direction
                slideDistance = 0  // Reset since we're actively moving
            }
        }

        // If just stepped onto ice, start tracking slide
        if isOnIce && !wasOnIce {
            slideDirection = direction
            slideDistance = 0
        }
    }

    /// Continue sliding on ice when player stops input
    func continueIceSlide(map: GameMap, allTanks: [Tank]) -> Bool {
        guard isOnIce || slideDistance < iceSlideDistance else {
            slideDirection = nil
            slideDistance = 0
            return false
        }

        guard let dir = slideDirection else { return false }

        // Check if still on ice or still have slide distance remaining
        let stillOnIce = map.isIceTile(at: position)
        if !stillOnIce && slideDistance >= iceSlideDistance {
            slideDirection = nil
            slideDistance = 0
            isOnIce = false
            return false
        }

        let velocity = dir.velocity
        let slideSpeed = moveSpeed * speedMultiplier * iceSpeedBoost
        let newX = position.x + velocity.dx * slideSpeed
        let newY = position.y + velocity.dy * slideSpeed

        let newPosition = CGPoint(x: newX, y: newY)

        // Check collision
        if !map.checkTankCollision(position: newPosition, size: self.size.width, canSwim: canSwim) {
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
                slideDistance += slideSpeed
                animateTracks()

                // Update ice status
                isOnIce = map.isIceTile(at: position)

                // Stop sliding if we've slid enough and left the ice
                if !isOnIce && slideDistance >= iceSlideDistance {
                    slideDirection = nil
                    slideDistance = 0
                    return false
                }
                return true
            }
        }

        // Hit something, stop sliding
        slideDirection = nil
        slideDistance = 0
        return false
    }

    /// Check if tank is currently sliding on ice
    var isSliding: Bool {
        return slideDirection != nil && (isOnIce || slideDistance < iceSlideDistance)
    }

    private func animateTracks() {
        guard cachedTextures.count >= 2 else { return }
        // Alternate between 2 frames every 4 movement updates
        trackFrame = (trackFrame + 1) % 8
        let textureIndex = (trackFrame / 4) % 2
        if let tankSprite = childNode(withName: "tankBody") as? SKSpriteNode {
            tankSprite.texture = cachedTextures[textureIndex]
        }
    }

    /// Try to slide perpendicular to movement direction to align with a gap (like original Battle City)
    private func trySlideMove(direction: Direction, map: GameMap, allTanks: [Tank]) -> CGPoint? {
        let tileSize = GameConstants.tileSize

        // Very subtle slide amount - same as original game (max 0.5 pixels per frame)
        let slideAmount = min(moveSpeed * speedMultiplier, 0.5)

        // Calculate offset from tile CENTER (not edge)
        // Tank position is its center, gaps are at tile centers
        let tileCenterX = (floor(position.x / tileSize) + 0.5) * tileSize
        let tileCenterY = (floor(position.y / tileSize) + 0.5) * tileSize
        let offsetFromCenterX = position.x - tileCenterX  // Negative = left of center, Positive = right of center
        let offsetFromCenterY = position.y - tileCenterY  // Negative = below center, Positive = above center

        switch direction {
        case .left, .right:
            // Moving horizontally - try to slide vertically to align with tile center
            if abs(offsetFromCenterY) > 1 {
                // Slide toward tile center
                let slideDir: CGFloat = offsetFromCenterY > 0 ? -1 : 1  // If above center, slide down; if below, slide up
                let slideY = position.y + slideDir * min(slideAmount, abs(offsetFromCenterY))
                let testPos = CGPoint(x: position.x, y: slideY)

                if !map.checkTankCollision(position: testPos, size: self.size.width, canSwim: canSwim) &&
                   !checkCollisionWithTanks(at: testPos, allTanks: allTanks) {
                    return testPos
                }
            }

        case .up, .down:
            // Moving vertically - try to slide horizontally to align with tile center
            if abs(offsetFromCenterX) > 1 {
                // Slide toward tile center
                let slideDir: CGFloat = offsetFromCenterX > 0 ? -1 : 1  // If right of center, slide left; if left, slide right
                let slideX = position.x + slideDir * min(slideAmount, abs(offsetFromCenterX))
                let testPos = CGPoint(x: slideX, y: position.y)

                if !map.checkTankCollision(position: testPos, size: self.size.width, canSwim: canSwim) &&
                   !checkCollisionWithTanks(at: testPos, allTanks: allTanks) {
                    return testPos
                }
            }
        }

        return nil
    }

    private func checkCollisionWithTanks(at testPosition: CGPoint, allTanks: [Tank]) -> Bool {
        for tank in allTanks {
            if tank !== self && tank.isAlive {
                if checkCollision(with: tank, at: testPosition) {
                    return true
                }
            }
        }
        return false
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

    func shoot() -> [Bullet] {
        guard canShoot else { return [] }

        var bullets: [Bullet] = []

        // Number of bullets based on machinegun power-up (1 + machinegunCount, max 4)
        let bulletCount = min(1 + machinegunCount, 4)

        // Base cooldown reduced by star power-ups (min 5 frames)
        let baseCooldown = max(5, 30 - (starCount * 5))
        shootCooldown = baseCooldown

        let bulletOffset: CGFloat = size.width / 2 + GameConstants.bulletSize / 2
        let bulletSpacing: CGFloat = GameConstants.bulletSize * 2

        for i in 0..<bulletCount {
            let spacing = CGFloat(i) * bulletSpacing
            let bulletPosition = CGPoint(
                x: position.x + direction.velocity.dx * (bulletOffset + spacing),
                y: position.y + direction.velocity.dy * (bulletOffset + spacing)
            )

            let bullet = Bullet(
                position: bulletPosition,
                direction: direction,
                owner: self,
                power: bulletPower
            )
            bullets.append(bullet)
            activeBullets += 1
        }

        return bullets
    }

    func bulletDestroyed() {
        activeBullets = max(0, activeBullets - 1)
        // Reset cooldown so player can shoot immediately when bullet is destroyed
        // This matches original Battle City behavior
        if activeBullets == 0 {
            shootCooldown = 0
        }
    }

    func damage() {
        if hasShield { return }

        // Ship acts as extra protection - first shot removes ship
        if canSwim {
            canSwim = false
            drawTank()  // Remove ship indicator
            // Flash to indicate ship was lost
            let flash = SKAction.sequence([
                SKAction.colorize(with: .cyan, colorBlendFactor: 1.0, duration: 0.1),
                SKAction.colorize(withColorBlendFactor: 0, duration: 0.1)
            ])
            run(flash)
            return
        }

        health -= 1
        if health <= 0 {
            die()
        } else {
            // Enemy tank type transformation when damaged
            if !isPlayer {
                if enemyType == .heavy {
                    // HEAVY → ARMORED (bulletPower becomes 1)
                    enemyType = .armored
                    bulletPower = 1
                    drawTank()
                } else if enemyType == .armored {
                    // ARMORED → REGULAR
                    enemyType = .regular
                    drawTank()
                }
            }

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
            health = 0  // Ensure health is 0
            createExplosion()
        } else {
            // Enemy death handled by game scene
            health = 0
        }
    }

    private func createExplosion() {
        guard let parent = self.parent else { return }

        let explosion = SKNode()
        explosion.position = self.position
        explosion.zPosition = 100

        // Create expanding circles for explosion effect
        for i in 0..<3 {
            let circle = SKShapeNode(circleOfRadius: 5)
            circle.fillColor = [SKColor.red, SKColor.orange, SKColor.yellow][i]
            circle.strokeColor = .clear
            explosion.addChild(circle)

            let delay = Double(i) * 0.05
            let expand = SKAction.scale(to: 3.0 - CGFloat(i) * 0.5, duration: 0.3)
            let fade = SKAction.fadeOut(withDuration: 0.3)
            let group = SKAction.group([expand, fade])
            let sequence = SKAction.sequence([SKAction.wait(forDuration: delay), group])
            circle.run(sequence)
        }

        // Add particles
        for _ in 0..<8 {
            let particle = SKShapeNode(circleOfRadius: 3)
            particle.fillColor = [SKColor.red, SKColor.orange, SKColor.yellow].randomElement()!
            particle.strokeColor = .clear
            explosion.addChild(particle)

            let angle = CGFloat.random(in: 0...(.pi * 2))
            let distance: CGFloat = CGFloat.random(in: 20...40)
            let dx = cos(angle) * distance
            let dy = sin(angle) * distance

            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.4)
            let fade = SKAction.fadeOut(withDuration: 0.4)
            let group = SKAction.group([move, fade])
            particle.run(group)
        }

        parent.addChild(explosion)

        // Remove explosion after animation
        explosion.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.removeFromParent()
        ]))
    }

    var isAlive: Bool {
        return health > 0
    }

    var tankSize: CGFloat {
        return enemyType == .boss ? GameConstants.bossTankSize : GameConstants.tankSize
    }

    var isWaitingToRespawn: Bool {
        return respawnTimer > 0
    }

    func respawn(at position: CGPoint) {
        pendingRespawnPosition = position
        respawnTimer = GameConstants.respawnDelay
        // Player stays hidden until respawn completes
    }

    func updateRespawnTimer() {
        guard respawnTimer > 0 else { return }

        respawnTimer -= 1
        if respawnTimer == 0 {
            completeRespawn()
        }
    }

    private func completeRespawn() {
        // Set position (use pending or default spawn point)
        let spawnPos = pendingRespawnPosition ?? CGPoint(
            x: GameConstants.tileSize * 8,
            y: GameConstants.tileSize * 2
        )
        position = spawnPos

        // Restore health and visibility
        health = maxHealth
        isHidden = false
        alpha = 1.0

        // Reset all power-ups on respawn
        resetPowerUps()

        // Give temporary shield after respawn
        hasShield = true
        shieldTimer = 180 // 3 seconds of shield
        drawTank()

        // Clear pending position
        pendingRespawnPosition = nil
    }

    /// Reset all power-ups (called when player dies)
    func resetPowerUps() {
        starCount = 0
        bulletPower = 1
        speedMultiplier = 1.0
        canSwim = false
        canDestroyTrees = false
        machinegunCount = 0
        moveSpeed = isPlayer ? GameConstants.tankSpeed : GameConstants.enemyTankSpeed
    }

    func addLives(_ count: Int) {
        lives += count
    }

    func activateShield(duration: Int) {
        hasShield = true
        shieldTimer = duration
        // Redraw to show shield effect
        drawTank()
    }

    func activateShip() {
        canSwim = true
        // Redraw to show ship indicator
        drawTank()
    }

    func convertToType(_ newType: EnemyType) {
        guard !isPlayer else { return }

        // Stop any existing rainbow animation
        removeAction(forKey: "rainbowAnimation")

        self.enemyType = newType

        // Update stats based on new type
        switch newType {
        case .fast:
            self.moveSpeed = GameConstants.enemyTankSpeed * 1.5
            self.health = 1
            self.maxHealth = 1
            self.bulletPower = 1
        case .armored:
            self.moveSpeed = GameConstants.enemyTankSpeed
            self.health = 2
            self.maxHealth = 2
            self.bulletPower = 1
        case .power:
            self.moveSpeed = GameConstants.enemyTankSpeed
            self.health = 2
            self.maxHealth = 2
            self.bulletPower = 1  // Enemies can't destroy steel
        case .heavy:
            self.moveSpeed = GameConstants.enemyTankSpeed * 0.8
            self.health = 3
            self.maxHealth = 3
            self.bulletPower = 2
        default:
            self.moveSpeed = GameConstants.enemyTankSpeed
            self.health = 1
            self.maxHealth = 1
            self.bulletPower = 1
        }

        // Redraw tank with new appearance (this will start rainbow animation for POWER)
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

    func lighter(by percentage: CGFloat = 0.2) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: min(r + percentage, 1),
                       green: min(g + percentage, 1),
                       blue: min(b + percentage, 1),
                       alpha: a)
    }
}
