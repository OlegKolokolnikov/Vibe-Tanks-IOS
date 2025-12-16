import SpriteKit

/// Bullet projectile
class Bullet: SKSpriteNode {

    let direction: Direction
    weak var owner: Tank?
    let power: Int
    let speed: CGFloat = GameConstants.bulletSpeed

    var isFromEnemy: Bool {
        return !(owner?.isPlayer ?? true)
    }

    init(position: CGPoint, direction: Direction, owner: Tank, power: Int = 1) {
        self.direction = direction
        self.owner = owner
        self.power = power

        let color: SKColor = owner.isPlayer ? .yellow : .white
        let size = CGSize(width: GameConstants.bulletSize, height: GameConstants.bulletSize)

        super.init(texture: nil, color: color, size: size)

        self.position = position
        self.zPosition = 5

        // Draw bullet
        drawBullet()

        // Physics
        physicsBody = SKPhysicsBody(circleOfRadius: GameConstants.bulletSize / 2)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = PhysicsCategory.bullet
        physicsBody?.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.player | PhysicsCategory.enemy | PhysicsCategory.bullet
        physicsBody?.collisionBitMask = 0
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawBullet() {
        let bullet = SKShapeNode(circleOfRadius: GameConstants.bulletSize / 2)
        bullet.fillColor = owner?.isPlayer ?? true ? .yellow : .white
        bullet.strokeColor = .orange
        bullet.lineWidth = 1
        addChild(bullet)
    }

    func update() {
        let velocity = direction.velocity
        position.x += velocity.dx * speed
        position.y += velocity.dy * speed
    }

    func isOutOfBounds(mapSize: CGSize) -> Bool {
        return position.x < 0 || position.x > mapSize.width ||
               position.y < 0 || position.y > mapSize.height
    }

    func collidesWith(_ other: Bullet) -> Bool {
        let dx = position.x - other.position.x
        let dy = position.y - other.position.y
        let dist = sqrt(dx * dx + dy * dy)
        return dist < GameConstants.bulletSize
    }

    func collidesWith(_ tank: Tank) -> Bool {
        let tankHalfSize = tank.size.width / 2
        let bulletRadius = GameConstants.bulletSize / 2

        let dx = abs(position.x - tank.position.x)
        let dy = abs(position.y - tank.position.y)

        return dx < tankHalfSize + bulletRadius && dy < tankHalfSize + bulletRadius
    }
}
