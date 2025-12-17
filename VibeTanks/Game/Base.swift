import SpriteKit

/// The base/eagle that players must protect (Battle City style)
class Base: SKSpriteNode {

    private var isDestroyed: Bool = false
    private let baseSize: CGFloat = GameConstants.tileSize // Match tile size so it fits in protection

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
            // Draw destroyed base - rubble
            let background = SKShapeNode(rectOf: CGSize(width: baseSize, height: baseSize))
            background.fillColor = SKColor(red: 0.31, green: 0.19, blue: 0, alpha: 1) // Dark brown
            background.strokeColor = .clear
            addChild(background)

            // Rubble pieces
            let rubble1 = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            rubble1.position = CGPoint(x: -8, y: 8)
            rubble1.fillColor = SKColor(red: 0.47, green: 0.28, blue: 0, alpha: 1)
            rubble1.strokeColor = .clear
            addChild(rubble1)

            let rubble2 = SKShapeNode(rectOf: CGSize(width: 10, height: 10))
            rubble2.position = CGPoint(x: 6, y: 4)
            rubble2.fillColor = SKColor(red: 0.47, green: 0.28, blue: 0, alpha: 1)
            rubble2.strokeColor = .clear
            addChild(rubble2)

            let rubble3 = SKShapeNode(rectOf: CGSize(width: 12, height: 10))
            rubble3.position = CGPoint(x: -4, y: -6)
            rubble3.fillColor = SKColor(red: 0.47, green: 0.28, blue: 0, alpha: 1)
            rubble3.strokeColor = .clear
            addChild(rubble3)
        } else {
            // Draw classic Battle City eagle
            // Tan background
            let background = SKShapeNode(rectOf: CGSize(width: baseSize, height: baseSize))
            background.fillColor = SKColor(red: 0.99, green: 0.85, blue: 0.66, alpha: 1) // Tan
            background.strokeColor = .clear
            addChild(background)

            // Eagle body - black parts (coordinates relative to center)
            // Head (x+12, y+4 in original = center offset)
            let head = SKShapeNode(rectOf: CGSize(width: 8, height: 8))
            head.position = CGPoint(x: 0, y: 10)
            head.fillColor = .black
            head.strokeColor = .clear
            addChild(head)

            // Body center
            let bodyCenter = SKShapeNode(rectOf: CGSize(width: 16, height: 12))
            bodyCenter.position = CGPoint(x: 0, y: 0)
            bodyCenter.fillColor = .black
            bodyCenter.strokeColor = .clear
            addChild(bodyCenter)

            // Left wing
            let leftWing = SKShapeNode(rectOf: CGSize(width: 6, height: 8))
            leftWing.position = CGPoint(x: -9, y: -2)
            leftWing.fillColor = .black
            leftWing.strokeColor = .clear
            addChild(leftWing)

            // Right wing
            let rightWing = SKShapeNode(rectOf: CGSize(width: 6, height: 8))
            rightWing.position = CGPoint(x: 9, y: -2)
            rightWing.fillColor = .black
            rightWing.strokeColor = .clear
            addChild(rightWing)

            // Left leg/tail
            let leftLeg = SKShapeNode(rectOf: CGSize(width: 4, height: 6))
            leftLeg.position = CGPoint(x: -4, y: -9)
            leftLeg.fillColor = .black
            leftLeg.strokeColor = .clear
            addChild(leftLeg)

            // Right leg/tail
            let rightLeg = SKShapeNode(rectOf: CGSize(width: 4, height: 6))
            rightLeg.position = CGPoint(x: 4, y: -9)
            rightLeg.fillColor = .black
            rightLeg.strokeColor = .clear
            addChild(rightLeg)

            // Orange/red details
            let detailColor = SKColor(red: 0.99, green: 0.45, blue: 0.38, alpha: 1)

            let leftDetail = SKShapeNode(rectOf: CGSize(width: 4, height: 4))
            leftDetail.position = CGPoint(x: -4, y: -2)
            leftDetail.fillColor = detailColor
            leftDetail.strokeColor = .clear
            addChild(leftDetail)

            let rightDetail = SKShapeNode(rectOf: CGSize(width: 4, height: 4))
            rightDetail.position = CGPoint(x: 4, y: -2)
            rightDetail.fillColor = detailColor
            rightDetail.strokeColor = .clear
            addChild(rightDetail)

            let centerDetail = SKShapeNode(rectOf: CGSize(width: 4, height: 8))
            centerDetail.position = CGPoint(x: 0, y: 0)
            centerDetail.fillColor = detailColor
            centerDetail.strokeColor = .clear
            addChild(centerDetail)
        }
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
