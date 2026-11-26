import SpriteKit

/// Red-alien levels: eyes open and close on random empty (black) tiles.
/// Pure decoration: they block nothing, and a player's bullet makes an eye shut at once
/// (the bullet flies on). At most three are open at a time; one eye per level may be red.
class AlienEyes: SKNode {
    private static let maxEyes = 3
    private static let eyeZ: CGFloat = 1  // Under tanks (10), bullets (5) and forest (15)

    private var eyes: [AlienEye] = []
    private var spawnTimer = Int.random(in: 60...600)
    private var redEyeUsed = false

    override init() {
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

        // One red eye per level at most, at a random moment
        let red = !redEyeUsed && Int.random(in: 1...4) == 1
        if red { redEyeUsed = true }
        let eye = AlienEye(red: red)
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

/// One eye: opens, looks around, blinks maybe, closes and goes away
private class AlienEye: SKNode {
    private let lid = SKNode()  // Scaled vertically to open/close the eye
    private let pupil: SKShapeNode
    private(set) var isClosing = false

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

    func open() {
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

    func close(fast: Bool) {
        guard !isClosing else { return }
        isClosing = true
        lid.removeAction(forKey: "life")
        let shut = SKAction.scaleY(to: 0.01, duration: fast ? 0.06 : 0.3)
        shut.timingMode = .easeIn
        lid.run(SKAction.sequence([shut, SKAction.run { [weak self] in self?.removeFromParent() }]))
    }
}
