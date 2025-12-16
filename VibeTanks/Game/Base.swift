import SpriteKit

/// The base/eagle that players must protect
class Base: SKSpriteNode {

    private var isDestroyed: Bool = false
    private let baseSize: CGFloat = 32

    init(position: CGPoint) {
        super.init(texture: nil, color: .clear, size: CGSize(width: baseSize, height: baseSize))

        self.position = position
        self.zPosition = 5

        drawBase()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawBase() {
        removeAllChildren()

        if isDestroyed {
            // Draw destroyed base
            let destroyed = SKShapeNode(rectOf: CGSize(width: baseSize, height: baseSize))
            destroyed.fillColor = .darkGray
            destroyed.strokeColor = .black
            addChild(destroyed)
        } else {
            // Draw eagle/phoenix shape
            let body = SKShapeNode(rectOf: CGSize(width: baseSize * 0.8, height: baseSize * 0.8))
            body.fillColor = SKColor(hex: "#FFD700") // Gold
            body.strokeColor = SKColor(hex: "#B8860B")
            body.lineWidth = 2
            addChild(body)

            // Wings
            let leftWing = SKShapeNode(path: createWingPath(left: true))
            leftWing.fillColor = SKColor(hex: "#FFA500") // Orange
            leftWing.strokeColor = SKColor(hex: "#B8860B")
            addChild(leftWing)

            let rightWing = SKShapeNode(path: createWingPath(left: false))
            rightWing.fillColor = SKColor(hex: "#FFA500")
            rightWing.strokeColor = SKColor(hex: "#B8860B")
            addChild(rightWing)

            // Head
            let head = SKShapeNode(circleOfRadius: baseSize * 0.2)
            head.position = CGPoint(x: 0, y: baseSize * 0.3)
            head.fillColor = SKColor(hex: "#FFD700")
            head.strokeColor = SKColor(hex: "#B8860B")
            addChild(head)
        }
    }

    private func createWingPath(left: Bool) -> CGPath {
        let path = CGMutablePath()
        let xDir: CGFloat = left ? -1 : 1

        path.move(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: xDir * baseSize * 0.5, y: baseSize * 0.2))
        path.addLine(to: CGPoint(x: xDir * baseSize * 0.4, y: -baseSize * 0.2))
        path.closeSubpath()

        return path
    }

    func checkCollision(bulletPosition: CGPoint) -> Bool {
        guard !isDestroyed else { return false }

        let halfSize = baseSize / 2
        let dx = abs(bulletPosition.x - position.x)
        let dy = abs(bulletPosition.y - position.y)

        return dx < halfSize && dy < halfSize
    }

    func destroy() {
        isDestroyed = true
        drawBase()

        // Explosion effect
        let explosion = SKEmitterNode()
        explosion.particleColor = .orange
        explosion.particleBirthRate = 100
        explosion.particleLifetime = 0.5
        explosion.particleSpeed = 50
        explosion.particleSpeedRange = 30
        explosion.emissionAngleRange = .pi * 2
        explosion.position = .zero
        addChild(explosion)

        run(SKAction.sequence([
            SKAction.wait(forDuration: 0.5),
            SKAction.run { explosion.removeFromParent() }
        ]))
    }

    var alive: Bool {
        return !isDestroyed
    }
}
