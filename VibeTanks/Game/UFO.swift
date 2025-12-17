import SpriteKit

/// UFO that flies across the screen and drops easter eggs when destroyed
class UFO: SKNode {

    private static let size: CGFloat = 48
    private static let speed: CGFloat = 1.5

    private var dx: CGFloat = 0
    private var dy: CGFloat = 0
    private var movingRight: Bool
    private var health: Int = 3
    private var lifetime: Int
    private var shootCooldown: Int
    private var directionChangeTimer: Int

    private let bodyNode: SKShapeNode
    private let domeNode: SKShapeNode
    private let lightsNode: SKNode
    private var lightFrame: Int = 0

    var isAlive: Bool = true

    init(startX: CGFloat, startY: CGFloat, movingRight: Bool) {
        self.movingRight = movingRight
        self.lifetime = GameConstants.ufoLifetime
        self.shootCooldown = GameConstants.ufoShootCooldown
        self.directionChangeTimer = GameConstants.ufoDirectionChange

        // Create body (metallic gray ellipse)
        bodyNode = SKShapeNode(ellipseOf: CGSize(width: UFO.size, height: UFO.size * 0.4))
        bodyNode.fillColor = SKColor(red: 0.47, green: 0.47, blue: 0.55, alpha: 1.0)
        bodyNode.strokeColor = SKColor(red: 0.31, green: 0.31, blue: 0.39, alpha: 1.0)
        bodyNode.lineWidth = 2
        bodyNode.position = CGPoint(x: 0, y: -UFO.size * 0.1)

        // Create dome (glass-like)
        domeNode = SKShapeNode(ellipseOf: CGSize(width: UFO.size * 0.5, height: UFO.size * 0.5))
        domeNode.fillColor = SKColor(red: 0.59, green: 0.78, blue: 1.0, alpha: 0.7)
        domeNode.strokeColor = .clear
        domeNode.position = CGPoint(x: 0, y: UFO.size * 0.15)

        // Lights container
        lightsNode = SKNode()

        super.init()

        self.position = CGPoint(x: startX, y: startY)
        self.zPosition = 100

        addChild(bodyNode)
        addChild(domeNode)
        addChild(lightsNode)

        // Add dome highlight
        let highlight = SKShapeNode(ellipseOf: CGSize(width: UFO.size * 0.2, height: UFO.size * 0.2))
        highlight.fillColor = SKColor(red: 0.78, green: 0.9, blue: 1.0, alpha: 0.5)
        highlight.strokeColor = .clear
        highlight.position = CGPoint(x: -UFO.size * 0.1, y: UFO.size * 0.25)
        addChild(highlight)

        // Create rotating lights
        createLights()

        // Add health indicator
        updateHealthIndicator()

        // Set initial direction
        dx = movingRight ? UFO.speed : -UFO.speed
        dy = 0
        randomizeDirection()

        // Start hover animation
        let hoverUp = SKAction.moveBy(x: 0, y: 3, duration: 0.3)
        let hoverDown = SKAction.moveBy(x: 0, y: -3, duration: 0.3)
        let hover = SKAction.sequence([hoverUp, hoverDown])
        run(SKAction.repeatForever(hover))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func createLights() {
        lightsNode.removeAllChildren()
        let colors: [SKColor] = [.red, .yellow, .green, .cyan]

        for i in 0..<4 {
            let light = SKShapeNode(circleOfRadius: 3)
            light.fillColor = colors[(lightFrame + i) % 4]
            light.strokeColor = .clear

            let angle = CGFloat(i) * .pi / 2
            let radius = UFO.size * 0.35
            light.position = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * UFO.size * 0.1 - UFO.size * 0.1
            )
            lightsNode.addChild(light)
        }
    }

    private func randomizeDirection() {
        let baseX = movingRight ? UFO.speed : -UFO.speed
        let randomY = (CGFloat.random(in: 0...1) - 0.5) * UFO.speed * 1.5

        dx = baseX + (CGFloat.random(in: 0...1) - 0.5) * 0.5
        dy = randomY

        // Normalize to maintain consistent speed
        let magnitude = sqrt(dx * dx + dy * dy)
        if magnitude > 0 {
            dx = (dx / magnitude) * UFO.speed
            dy = (dy / magnitude) * UFO.speed
        }

        // Ensure still moving in general direction
        if movingRight && dx < 0.3 { dx = 0.5 }
        if !movingRight && dx > -0.3 { dx = -0.5 }
    }

    private func updateHealthIndicator() {
        // Remove old health dots
        children.filter { $0.name == "health" }.forEach { $0.removeFromParent() }

        // Add health dots
        for i in 0..<health {
            let dot = SKShapeNode(circleOfRadius: 3)
            dot.fillColor = .green
            dot.strokeColor = .clear
            dot.position = CGPoint(x: CGFloat(i - 1) * 8, y: UFO.size * 0.4)
            dot.name = "health"
            addChild(dot)
        }
    }

    func update(mapWidth: CGFloat, mapHeight: CGFloat) -> [Bullet] {
        guard isAlive else { return [] }

        var newBullets: [Bullet] = []

        lifetime -= 1
        if lifetime <= 0 {
            isAlive = false
            return []
        }

        // Change direction periodically
        directionChangeTimer -= 1
        if directionChangeTimer <= 0 {
            randomizeDirection()
            directionChangeTimer = GameConstants.ufoDirectionChange + Int.random(in: 0..<60)
        }

        // Move
        position.x += dx
        position.y += dy

        // Keep within vertical bounds (bounce)
        if position.y < 50 {
            position.y = 50
            dy = abs(dy)
        }
        if position.y > mapHeight - UFO.size - 50 {
            position.y = mapHeight - UFO.size - 50
            dy = -abs(dy)
        }

        // Check if reached other side
        if movingRight && position.x > mapWidth {
            isAlive = false
            return []
        }
        if !movingRight && position.x < -UFO.size {
            isAlive = false
            return []
        }

        // Shooting
        shootCooldown -= 1
        if shootCooldown <= 0 {
            let bullet = shoot()
            newBullets.append(bullet)
            shootCooldown = GameConstants.ufoShootCooldown + Int.random(in: 0..<30)
        }

        // Update lights animation
        lightFrame = (lightFrame + 1) % 8
        if lightFrame % 2 == 0 {
            createLights()
        }

        return newBullets
    }

    private func shoot() -> Bullet {
        let bulletX = position.x
        let bulletY = position.y - UFO.size / 2
        return Bullet(
            x: bulletX,
            y: bulletY,
            direction: .down,
            isEnemy: true
        )
    }

    func damage() -> Bool {
        health -= 1
        updateHealthIndicator()

        // Flash effect
        let flash = SKAction.sequence([
            SKAction.colorize(with: .white, colorBlendFactor: 1.0, duration: 0.05),
            SKAction.colorize(withColorBlendFactor: 0, duration: 0.05)
        ])
        bodyNode.run(flash)

        if health <= 0 {
            isAlive = false
            return true // Destroyed
        }
        return false
    }

    func collidesWith(_ bullet: Bullet) -> Bool {
        guard isAlive, !bullet.isEnemy else { return false }

        let bx = bullet.position.x
        let by = bullet.position.y
        let bs = GameConstants.bulletSize
        let halfSize = UFO.size / 2

        return abs(bx - position.x) < halfSize + bs / 2 &&
               abs(by - position.y) < halfSize + bs / 2
    }

    func createDestroyEffect() {
        guard let parent = self.parent else { return }

        // Explosion effect
        for _ in 0..<20 {
            let particle = SKShapeNode(circleOfRadius: CGFloat.random(in: 2...6))
            particle.fillColor = [.red, .orange, .yellow, .cyan][Int.random(in: 0..<4)]
            particle.strokeColor = .clear
            particle.position = position
            particle.zPosition = 150
            parent.addChild(particle)

            let dx = CGFloat.random(in: -50...50)
            let dy = CGFloat.random(in: -50...50)
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.5)
            let fade = SKAction.fadeOut(withDuration: 0.5)
            let remove = SKAction.removeFromParent()
            particle.run(SKAction.sequence([SKAction.group([move, fade]), remove]))
        }
    }
}
