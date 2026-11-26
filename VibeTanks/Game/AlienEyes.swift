import SpriteKit

/// Alien levels: on random empty (black) tiles, eyes open and close (red alien)
/// or small stars twinkle (green alien). Pure decoration: they block nothing, and a player's
/// bullet makes one go away at once (the bullet flies on). At most three at a time;
/// one eye per level may be red, stars come in white, yellow, red and blue.
class AlienEyes: SKNode {
    private static let maxEyes = 3
    private static let eyeZ: CGFloat = 1  // Under tanks (10), bullets (5) and forest (15)

    private var eyes: [AlienDecoration] = []
    private var spawnTimer = Int.random(in: 60...600)
    private var redEyeUsed = false
    /// Stars instead of eyes (green alien)
    private let stars: Bool

    init(stars: Bool = false) {
        self.stars = stars
        super.init()
        zPosition = AlienEyes.eyeZ
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Called once per game frame
    func update(map: GameMap, tanks: [Tank], playerBullets: [Bullet]) {
        eyes.removeAll { $0.parent == nil }

        // A player's bullet over an open eye shuts it
        for eye in eyes where !eye.isClosing {
            let half = GameConstants.tileSize * 0.45  // Eye size plus a little
            let rect = CGRect(x: eye.position.x - half, y: eye.position.y - half, width: half * 2, height: half * 2)
            if playerBullets.contains(where: { rect.contains($0.position) }) {
                eye.close(fast: true)
            }
        }

        spawnTimer -= 1
        guard spawnTimer <= 0 else { return }
        spawnTimer = Int.random(in: 60...600)  // Next one in 1-10 seconds
        guard eyes.count < AlienEyes.maxEyes, let spot = randomSpot(map: map, tanks: tanks) else { return }

        let eye: AlienDecoration
        if stars {
            eye = AlienStar()
        } else {
            // One red eye per level at most, at a random moment
            let red = !redEyeUsed && Int.random(in: 1...4) == 1
            if red { redEyeUsed = true }
            eye = AlienEye(red: red)
        }
        eye.position = spot
        addChild(eye)
        eyes.append(eye)
        eye.open()
    }

    /// A random empty tile away from tanks, other eyes and the base
    private func randomSpot(map: GameMap, tanks: [Tank]) -> CGPoint? {
        let tileSize = GameConstants.tileSize
        var spots: [CGPoint] = []
        for row in 0..<GameConstants.mapHeight {
            for col in 0..<GameConstants.mapWidth {
                // Base and its protection walls (rows 23-24, cols 12-14)
                if (23...25).contains(row) && (11...15).contains(col) { continue }
                let p = CGPoint(x: CGFloat(col) * tileSize + tileSize / 2,
                                y: CGFloat(GameConstants.mapHeight - 1 - row) * tileSize + tileSize / 2)
                guard map.getTile(at: p) == .empty else { continue }
                if tanks.contains(where: { $0.isAlive && Self.near($0.position, p, tileSize * 1.5) }) { continue }
                if eyes.contains(where: { Self.near($0.position, p, tileSize * 2) }) { continue }
                spots.append(p)
            }
        }
        return spots.randomElement()
    }

    private static func near(_ a: CGPoint, _ b: CGPoint, _ distance: CGFloat) -> Bool {
        abs(a.x - b.x) < distance && abs(a.y - b.y) < distance
    }
}

/// One eye or star: appears, lives a few seconds, goes away (at once when shot)
private class AlienDecoration: SKNode {
    var isClosing = false
    func open() {}
    func close(fast: Bool) {}
}

/// A small star: pops up, twinkles, fades out
private class AlienStar: AlienDecoration {
    private let star: SKShapeNode

    override init() {
        let outer = GameConstants.tileSize * CGFloat.random(in: 0.18...0.28)
        let inner = outer * 0.4
        let path = CGMutablePath()
        for i in 0..<10 {
            let r = i % 2 == 0 ? outer : inner
            let angle = CGFloat(i) * .pi / 5 + .pi / 2
            let p = CGPoint(x: cos(angle) * r, y: sin(angle) * r)
            if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
        }
        path.closeSubpath()
        star = SKShapeNode(path: path)
        let colors: [SKColor] = [
            .white,
            SKColor(red: 1, green: 0.9, blue: 0.2, alpha: 1),
            SKColor(red: 1, green: 0.25, blue: 0.25, alpha: 1),
            SKColor(red: 0.35, green: 0.6, blue: 1, alpha: 1)
        ]
        let color = colors.randomElement()!
        star.fillColor = color
        star.strokeColor = color.withAlphaComponent(0.5)
        star.lineWidth = 1
        star.glowWidth = 1.5
        star.setScale(0.01)
        star.zRotation = CGFloat.random(in: 0...(2 * .pi / 5))
        super.init()
        addChild(star)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func open() {
        let life = Double.random(in: 2...6)
        let appear = SKAction.scale(to: 1, duration: 0.3)
        appear.timingMode = .easeOut
        let twinkle = SKAction.repeatForever(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 0.6, duration: 0.35), SKAction.fadeAlpha(to: 0.55, duration: 0.35)]),
            SKAction.group([SKAction.scale(to: 1, duration: 0.35), SKAction.fadeAlpha(to: 1, duration: 0.35)])
        ]))
        star.run(SKAction.repeatForever(SKAction.rotate(byAngle: .pi / 3, duration: 1)), withKey: "spin")
        star.run(SKAction.sequence([
            appear,
            SKAction.run { [weak self] in self?.star.run(twinkle, withKey: "twinkle") },
            SKAction.wait(forDuration: life),
            SKAction.run { [weak self] in self?.close(fast: false) }
        ]), withKey: "life")
    }

    override func close(fast: Bool) {
        guard !isClosing else { return }
        isClosing = true
        star.removeAction(forKey: "life")
        star.removeAction(forKey: "twinkle")
        let vanish = SKAction.group([
            SKAction.scale(to: 0.01, duration: fast ? 0.08 : 0.4),
            SKAction.fadeOut(withDuration: fast ? 0.08 : 0.4)
        ])
        star.run(SKAction.sequence([vanish, SKAction.run { [weak self] in self?.removeFromParent() }]))
    }
}

/// One eye: opens, looks around, blinks maybe, closes and goes away
private class AlienEye: AlienDecoration {
    private let lid = SKNode()  // Scaled vertically to open/close the eye
    private let pupil: SKShapeNode

    init(red: Bool) {
        let size = CGSize(width: GameConstants.tileSize * 0.8, height: GameConstants.tileSize * 0.5)
        let white = SKShapeNode(ellipseOf: size)
        white.fillColor = red ? SKColor(red: 0.9, green: 0.1, blue: 0.1, alpha: 1)
                              : SKColor(white: 0.95, alpha: 1)
        white.strokeColor = .clear

        pupil = SKShapeNode(circleOfRadius: size.height * 0.32)
        pupil.fillColor = .black
        pupil.strokeColor = .clear
        let shine = SKShapeNode(circleOfRadius: size.height * 0.08)
        shine.fillColor = SKColor(white: 1, alpha: 0.8)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: size.height * 0.1, y: size.height * 0.1)
        pupil.addChild(shine)

        super.init()
        lid.addChild(white)
        lid.addChild(pupil)
        lid.yScale = 0.01
        addChild(lid)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func open() {
        let openTime = Double.random(in: 2...6)
        let open = SKAction.scaleY(to: 1, duration: 0.3)
        open.timingMode = .easeOut

        // Glance around while open, with a blink now and then
        var looks: [SKAction] = []
        var elapsed = 0.0
        while elapsed < openTime {
            let step = Double.random(in: 0.5...1.4)
            let target = CGPoint(x: CGFloat.random(in: -5...5), y: CGFloat.random(in: -2...2))
            looks.append(SKAction.run { [weak self] in
                self?.pupil.run(SKAction.move(to: target, duration: 0.15))
            })
            if Int.random(in: 1...4) == 1 {
                looks.append(SKAction.sequence([
                    SKAction.scaleY(to: 0.05, duration: 0.08),
                    SKAction.scaleY(to: 1, duration: 0.1)
                ]))
            }
            looks.append(SKAction.wait(forDuration: step))
            elapsed += step
        }

        lid.run(SKAction.sequence([open] + looks + [SKAction.run { [weak self] in self?.close(fast: false) }]),
                withKey: "life")
    }

    override func close(fast: Bool) {
        guard !isClosing else { return }
        isClosing = true
        lid.removeAction(forKey: "life")
        let shut = SKAction.scaleY(to: 0.01, duration: fast ? 0.06 : 0.3)
        shut.timingMode = .easeIn
        lid.run(SKAction.sequence([shut, SKAction.run { [weak self] in self?.removeFromParent() }]))
    }
}
