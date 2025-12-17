import SpriteKit

/// Bullet projectile
class Bullet: SKSpriteNode {

    let direction: Direction
    weak var owner: Tank?
    let power: Int
    let moveSpeed: CGFloat = GameConstants.bulletSpeed
    private let forceIsEnemy: Bool?

    var isFromEnemy: Bool {
        if let forced = forceIsEnemy {
            return forced
        }
        return !(owner?.isPlayer ?? true)
    }

    var isEnemy: Bool {
        return isFromEnemy
    }

    init(position: CGPoint, direction: Direction, owner: Tank, power: Int = 1) {
        self.direction = direction
        self.owner = owner
        self.power = power
        self.forceIsEnemy = nil

        let color: SKColor = owner.isPlayer ? .yellow : .white
        let size = CGSize(width: GameConstants.bulletSize, height: GameConstants.bulletSize)

        // Create simple circular texture for bullet
        let texture = Bullet.createBulletTexture(color: color)
        super.init(texture: texture, color: .white, size: size)

        self.position = position
        self.zPosition = 5

        // Physics
        physicsBody = SKPhysicsBody(circleOfRadius: GameConstants.bulletSize / 2)
        physicsBody?.isDynamic = true
        physicsBody?.affectedByGravity = false
        physicsBody?.categoryBitMask = PhysicsCategory.bullet
        physicsBody?.contactTestBitMask = PhysicsCategory.wall | PhysicsCategory.player | PhysicsCategory.enemy | PhysicsCategory.bullet
        physicsBody?.collisionBitMask = 0
    }

    /// Alternative initializer for UFO bullets (no tank owner)
    init(x: CGFloat, y: CGFloat, direction: Direction, isEnemy: Bool, power: Int = 1) {
        self.direction = direction
        self.owner = nil
        self.power = power
        self.forceIsEnemy = isEnemy

        let color: SKColor = .green
        let size = CGSize(width: GameConstants.bulletSize, height: GameConstants.bulletSize)

        let texture = Bullet.createBulletTexture(color: color)
        super.init(texture: texture, color: .white, size: size)

        self.position = CGPoint(x: x, y: y)
        self.zPosition = 5

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

    /// Create a simple circular texture for the bullet
    private static func createBulletTexture(color: SKColor) -> SKTexture {
        let size = GameConstants.bulletSize
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(color.cgColor)
            ctx.fillEllipse(in: CGRect(x: 0, y: 0, width: size, height: size))
            ctx.setStrokeColor(UIColor.orange.cgColor)
            ctx.setLineWidth(1)
            ctx.strokeEllipse(in: CGRect(x: 0.5, y: 0.5, width: size - 1, height: size - 1))
        }
        return SKTexture(image: image)
    }

    func update() {
        let velocity = direction.velocity
        position.x += velocity.dx * moveSpeed
        position.y += velocity.dy * moveSpeed
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
