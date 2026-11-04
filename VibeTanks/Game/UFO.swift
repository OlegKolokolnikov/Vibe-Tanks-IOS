import SpriteKit

/// UFO that flies across the screen and drops easter eggs when destroyed
class UFO: SKNode {

    private static let size: CGFloat = 48

    /// How the UFO gets around: a new style every time one shows up
    private enum FlightStyle: CaseIterable {
        case cruise   // Smooth glide through a few points
        case wave     // Weaves side to side along its way
        case zigzag   // Many short, sharp legs
        case hover    // Stops and hangs over spots before moving on
    }

    private let style: FlightStyle
    private let flySpeed: CGFloat
    private let mapSize: CGSize
    /// Points to fly through; the last one is off the map (where it escapes)
    private var waypoints: [CGPoint] = []
    private var pauseTimer: Int = 0
    private var wavePhase: CGFloat = 0
    private var health: Int = 3
    private var lifetime: Int
    private var shootCooldown: Int
    private var leaving = false

    private let bodyNode: SKShapeNode
    private let domeNode: SKShapeNode
    private let lightsNode: SKNode
    private var lightFrame: Int = 0

    var isAlive: Bool = true

    /// Comes in from a random side (left, right or top) and leaves through a random side
    init(mapSize: CGSize) {
        self.mapSize = mapSize
        self.style = FlightStyle.allCases.randomElement()!
        self.flySpeed = CGFloat.random(in: 1.2...2.2)
        self.lifetime = GameConstants.ufoLifetime
        self.shootCooldown = GameConstants.ufoShootCooldown

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

        self.position = UFO.offMapPoint(mapSize: mapSize, edge: Int.random(in: 0..<3))
        self.zPosition = 100
        planRoute()

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

    /// A point just outside the map: 0 = left, 1 = right, 2 = top, 3 = bottom
    private static func offMapPoint(mapSize: CGSize, edge: Int) -> CGPoint {
        let margin = size + 10
        switch edge {
        case 0: return CGPoint(x: -margin, y: CGFloat.random(in: 120...(mapSize.height - 80)))
        case 1: return CGPoint(x: mapSize.width + margin, y: CGFloat.random(in: 120...(mapSize.height - 80)))
        case 2: return CGPoint(x: CGFloat.random(in: 80...(mapSize.width - 80)), y: mapSize.height + margin)
        default: return CGPoint(x: CGFloat.random(in: 80...(mapSize.width - 80)), y: -margin)
        }
    }

    /// Random point over the battlefield (anywhere from just above the base to the top)
    private func randomFieldPoint() -> CGPoint {
        CGPoint(x: CGFloat.random(in: 60...(mapSize.width - 60)),
                y: CGFloat.random(in: 110...(mapSize.height - 60)))
    }

    private func planRoute() {
        waypoints = []
        switch style {
        case .cruise, .wave:
            for _ in 0..<Int.random(in: 2...3) { waypoints.append(randomFieldPoint()) }
        case .zigzag:
            var point = randomFieldPoint()
            waypoints.append(point)
            for _ in 0..<Int.random(in: 5...8) {
                point = CGPoint(x: min(max(point.x + CGFloat.random(in: -220...220), 60), mapSize.width - 60),
                                y: min(max(point.y + CGFloat.random(in: -180...180), 110), mapSize.height - 60))
                waypoints.append(point)
            }
        case .hover:
            for _ in 0..<Int.random(in: 2...4) { waypoints.append(randomFieldPoint()) }
        }
        // Escape through any side except the bottom (the base is there)
        waypoints.append(UFO.offMapPoint(mapSize: mapSize, edge: Int.random(in: 0..<3)))
    }

    /// Short time left: skip the remaining points and head for the exit
    private func leaveNow() {
        guard !leaving, let exit = waypoints.last else { return }
        leaving = true
        pauseTimer = 0
        waypoints = [exit]
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

        // Time is up: head straight for the exit (it never vanishes in the middle of the map)
        lifetime -= 1
        if lifetime <= 0 {
            leaveNow()
        }

        if pauseTimer > 0 {
            pauseTimer -= 1  // Hanging over a spot
        } else if let target = waypoints.first {
            let dx = target.x - position.x, dy = target.y - position.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance <= flySpeed * 2 + 4 {
                waypoints.removeFirst()
                if waypoints.isEmpty {
                    isAlive = false  // Flew off the map: escaped
                    return []
                }
                if style == .hover && waypoints.count >= 1 && !leaving {
                    pauseTimer = Int.random(in: 50...120)
                }
            } else {
                var vx = dx / distance * flySpeed, vy = dy / distance * flySpeed
                if style == .wave {
                    // Sideways swing across the direction of travel
                    wavePhase += 0.06
                    let swing = cos(wavePhase) * 1.6
                    vx += -dy / distance * swing
                    vy += dx / distance * swing
                }
                position.x += vx
                position.y += vy
            }
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
        guard isAlive, !bullet.isEnemy, !bullet.isFromGzhel else { return false }  // Player bullets only

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
