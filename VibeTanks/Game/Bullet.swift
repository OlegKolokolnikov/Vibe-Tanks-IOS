import SpriteKit

/// Bullet projectile
class Bullet: SKSpriteNode {

    // Static texture cache - created once, reused for all bullets
    private static var textureCache: [String: SKTexture] = [:]

    private static func getCachedTexture(color: SKColor, colorKey: String) -> SKTexture {
        if let cached = textureCache[colorKey] {
            return cached
        }
        let texture = createBulletTexture(color: color)
        textureCache[colorKey] = texture
        return texture
    }

    let direction: Direction
    weak var owner: Tank?

    /// Bullets fired together in one shot (machinegun): the shot ends when all are gone
    final class Burst {
        var remaining: Int
        init(count: Int) { remaining = count }
    }
    let burst: Burst?
    let power: Int
    let moveSpeed: CGFloat
    /// LASER shot: a bolt of light that passes through walls
    let isLaser: Bool
    /// Side is fixed when fired: `owner` is weak, so deriving it from the owner
    /// would turn an enemy's in-flight bullets into "player" bullets once it dies.
    private let fromEnemy: Bool
    /// Fired by the Gzhel tank: hurts enemies and the base, harmless to the player
    let isFromGzhel: Bool

    var isFromEnemy: Bool {
        return fromEnemy
    }

    var isEnemy: Bool {
        return isFromEnemy
    }

    init(position: CGPoint, direction: Direction, owner: Tank, power: Int = 1, isLaser: Bool = false, burst: Burst? = nil) {
        self.direction = direction
        self.burst = burst
        self.owner = owner
        self.power = power
        self.isLaser = isLaser
        self.moveSpeed = isLaser ? GameConstants.laserSpeed : GameConstants.bulletSpeed
        self.isFromGzhel = !owner.isPlayer && owner.enemyType == .gzhel
        self.fromEnemy = !owner.isPlayer && owner.enemyType != .gzhel

        if isLaser {
            // Elongated glowing bolt, drawn pointing up and rotated to the direction
            super.init(texture: Bullet.getLaserTexture(alien: !owner.isPlayer), color: .white, size: Bullet.laserSize)
            self.zRotation = direction.rotation
            self.blendMode = .add
        } else {
            let colorKey = owner.isPlayer ? "yellow" : (isFromGzhel ? "blue" : "white")
            let color: SKColor = owner.isPlayer ? .yellow : (isFromGzhel ? SKColor(red: 0.2, green: 0.45, blue: 1.0, alpha: 1.0) : .white)
            let size = CGSize(width: GameConstants.bulletSize, height: GameConstants.bulletSize)

            // Use cached texture for better performance
            let texture = Bullet.getCachedTexture(color: color, colorKey: colorKey)
            super.init(texture: texture, color: .white, size: size)
        }

        self.position = position
        self.zPosition = isLaser ? 16 : 5  // Light shines above forest
    }

    /// Alternative initializer for UFO bullets (no tank owner)
    init(x: CGFloat, y: CGFloat, direction: Direction, isEnemy: Bool, power: Int = 1) {
        self.direction = direction
        self.owner = nil
        self.burst = nil
        self.power = power
        self.isLaser = false
        self.moveSpeed = GameConstants.bulletSpeed
        self.fromEnemy = isEnemy
        self.isFromGzhel = false

        let color: SKColor = .green
        let size = CGSize(width: GameConstants.bulletSize, height: GameConstants.bulletSize)

        // Use cached texture for better performance
        let texture = Bullet.getCachedTexture(color: color, colorKey: "green")
        super.init(texture: texture, color: .white, size: size)

        self.position = CGPoint(x: x, y: y)
        self.zPosition = 5
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static let laserSize = CGSize(width: 6, height: 20)
    private static var laserTexture: SKTexture?
    private static var alienLaserTexture: SKTexture?

    /// Glow with a white-hot core (vertical): cyan for players, green for the alien
    private static func getLaserTexture(alien: Bool = false) -> SKTexture {
        if let cached = alien ? alienLaserTexture : laserTexture {
            return cached
        }
        let glow: UIColor = alien ? UIColor(red: 0.3, green: 1.0, blue: 0.3, alpha: 1) : .cyan
        let size = laserSize
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(glow.withAlphaComponent(0.45).cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: 3).cgPath)
            ctx.fillPath()
            ctx.setFillColor(glow.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 1, y: 1, width: size.width - 2, height: size.height - 2), cornerRadius: 2).cgPath)
            ctx.fillPath()
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.addPath(UIBezierPath(roundedRect: CGRect(x: 2, y: 2, width: size.width - 4, height: size.height - 4), cornerRadius: 1).cgPath)
            ctx.fillPath()
        }
        let texture = SKTexture(image: image)
        if alien { alienLaserTexture = texture } else { laserTexture = texture }
        return texture
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
        if isLaser != other.isLaser {
            // The fast laser covers more than a bullet's width per frame:
            // check the whole stretch it (and the other shot) moved through this frame
            let laser = isLaser ? self : other
            let shot = isLaser ? other : self
            return laser.sweptHit(shot)
        }
        let dx = position.x - other.position.x
        let dy = position.y - other.position.y
        let dist = sqrt(dx * dx + dy * dy)
        return dist < GameConstants.bulletSize
    }

    /// Did `other` cross the path this shot travelled during the last frame?
    private func sweptHit(_ other: Bullet) -> Bool {
        let v = direction.velocity
        let rx = other.position.x - position.x, ry = other.position.y - position.y
        let along = rx * v.dx + ry * v.dy           // Ahead (+) or behind (-) along the flight line
        let aside = abs(rx * v.dy - ry * v.dx)      // Distance off the flight line
        let reach = GameConstants.bulletSize
        let back = moveSpeed + other.moveSpeed + reach
        return aside < reach && along > -back && along < reach
    }

    func collidesWith(_ tank: Tank) -> Bool {
        let tankHalfSize = tank.size.width / 2
        let bulletRadius = GameConstants.bulletSize / 2

        let dx = abs(position.x - tank.position.x)
        let dy = abs(position.y - tank.position.y)

        return dx < tankHalfSize + bulletRadius && dy < tankHalfSize + bulletRadius
    }
}
