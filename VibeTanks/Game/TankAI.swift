import SpriteKit

/// AI controller for enemy tanks
class TankAI {

    weak var tank: Tank?

    private var targetDirection: Direction
    private var directionChangeTimer: Int = 0
    private var stuckTimer: Int = 0
    private var lastPosition: CGPoint = .zero
    private var moveTimer: Int = 0  // How long we've been moving in current direction

    // Track if we just shot at a wall (to avoid repeated wall shooting)
    private var shotAtWallTimer: Int = 0

    // AI behavior settings
    private let directionChangeInterval: Int
    private let shootChance: Double
    private let aggressiveness: Double

    init(tank: Tank) {
        self.tank = tank
        self.targetDirection = Direction.random

        // Set behavior based on enemy type
        switch tank.enemyType {
        case .regular:
            aggressiveness = 0.3
            directionChangeInterval = 60
            shootChance = 0.02
        case .fast:
            aggressiveness = 0.4
            directionChangeInterval = 40
            shootChance = 0.025
        case .armored:
            aggressiveness = 0.35
            directionChangeInterval = 70
            shootChance = 0.02
        case .power:
            aggressiveness = 0.5
            directionChangeInterval = 50
            shootChance = 0.03
        case .heavy:
            aggressiveness = 0.6
            directionChangeInterval = 60
            shootChance = 0.035
        case .boss:
            aggressiveness = 0.7
            directionChangeInterval = 45
            shootChance = 0.04
        }
    }

    func update(map: GameMap, playerTanks: [Tank], allTanks: [Tank]) -> (direction: Direction?, shouldShoot: Bool) {
        guard let tank = tank, tank.isAlive else {
            return (nil, false)
        }

        // Decay shot timer
        if shotAtWallTimer > 0 {
            shotAtWallTimer -= 1
        }

        // Check if stuck (not moving)
        let distMoved = tank.position.distance(to: lastPosition)
        if distMoved < 0.5 {
            stuckTimer += 1
            if stuckTimer > 20 {
                // Stuck - pick a new random direction that's not blocked
                targetDirection = findOpenDirection(map: map, allTanks: allTanks, exclude: targetDirection)
                stuckTimer = 0
                moveTimer = 0
                directionChangeTimer = 0
            }
        } else {
            stuckTimer = 0
            moveTimer += 1
        }
        lastPosition = tank.position

        // Periodically consider changing direction
        directionChangeTimer += 1
        if directionChangeTimer >= directionChangeInterval {
            directionChangeTimer = 0

            // Random chance to change direction even if not stuck
            if Double.random(in: 0...1) < 0.7 {
                targetDirection = chooseNewDirection(map: map, playerTanks: playerTanks, allTanks: allTanks)
                moveTimer = 0
            }
        }

        // Also change direction randomly sometimes for variety
        if moveTimer > 30 && Double.random(in: 0...1) < 0.02 {
            targetDirection = chooseNewDirection(map: map, playerTanks: playerTanks, allTanks: allTanks)
            moveTimer = 0
            directionChangeTimer = 0
        }

        // Decide whether to shoot
        let shouldShoot = decideToShoot(map: map, playerTanks: playerTanks)

        return (targetDirection, shouldShoot)
    }

    /// Choose a new direction - mix of random exploration and targeting
    private func chooseNewDirection(map: GameMap, playerTanks: [Tank], allTanks: [Tank]) -> Direction {
        // Chance to target player based on aggressiveness
        if Double.random(in: 0...1) < aggressiveness {
            if let playerDir = directionTowardsPlayer(playerTanks: playerTanks) {
                // Check if this direction is open
                if !isDirectionBlocked(playerDir, map: map, allTanks: allTanks) {
                    return playerDir
                }
            }
        }

        // Chance to head towards base (down)
        if Double.random(in: 0...1) < 0.3 {
            if !isDirectionBlocked(.down, map: map, allTanks: allTanks) {
                return .down
            }
        }

        // Otherwise pick a random open direction
        return findOpenDirection(map: map, allTanks: allTanks, exclude: nil)
    }

    /// Find an open direction, optionally excluding one
    private func findOpenDirection(map: GameMap, allTanks: [Tank], exclude: Direction?) -> Direction {
        guard let tank = tank else { return .down }

        var openDirections: [Direction] = []

        for dir in Direction.allCases {
            if dir == exclude { continue }

            let testPos = CGPoint(
                x: tank.position.x + dir.velocity.dx * 32,
                y: tank.position.y + dir.velocity.dy * 32
            )

            if !map.checkTankCollision(position: testPos, size: tank.size.width) {
                // Also check for other tanks
                var blockedByTank = false
                for other in allTanks {
                    if other !== tank && other.isAlive {
                        let dist = testPos.distance(to: other.position)
                        if dist < tank.size.width {
                            blockedByTank = true
                            break
                        }
                    }
                }
                if !blockedByTank {
                    openDirections.append(dir)
                }
            }
        }

        // Prefer going down (towards base) with some probability
        if openDirections.contains(.down) && Double.random(in: 0...1) < 0.35 {
            return .down
        }

        return openDirections.randomElement() ?? Direction.random
    }

    /// Check if a direction is blocked
    private func isDirectionBlocked(_ dir: Direction, map: GameMap, allTanks: [Tank]) -> Bool {
        guard let tank = tank else { return true }

        let testPos = CGPoint(
            x: tank.position.x + dir.velocity.dx * 32,
            y: tank.position.y + dir.velocity.dy * 32
        )

        if map.checkTankCollision(position: testPos, size: tank.size.width) {
            return true
        }

        // Check for other tanks
        for other in allTanks {
            if other !== tank && other.isAlive {
                let dist = testPos.distance(to: other.position)
                if dist < tank.size.width {
                    return true
                }
            }
        }

        return false
    }

    /// Decide whether to shoot based on what's in front
    private func decideToShoot(map: GameMap, playerTanks: [Tank]) -> Bool {
        guard let tank = tank else { return false }

        // If we recently shot at a wall, don't shoot again
        if shotAtWallTimer > 0 {
            return false
        }

        // Check if player is in line of fire - high priority to shoot
        if playerInLineOfFire(playerTanks: playerTanks, map: map) {
            return Double.random(in: 0...1) < 0.35
        }

        // Check if base is in line of fire
        if isBaseInLineOfFire(map: map) {
            return Double.random(in: 0...1) < 0.4
        }

        // Check what's in front
        let (obstacle, distance) = checkObstacleInFront(map: map)

        switch obstacle {
        case .brick:
            // Brick wall - occasionally shoot to break through
            if distance < 80 && Double.random(in: 0...1) < 0.03 {
                shotAtWallTimer = 45  // Cooldown after shooting wall
                return true
            }
            return false

        case .steel, .water:
            // Can't break steel/water - don't waste bullets
            return false

        case .empty, .forest, .ice:
            // Open or passable - normal shoot chance
            return Double.random(in: 0...1) < shootChance

        default:
            return Double.random(in: 0...1) < shootChance
        }
    }

    /// Check what obstacle is in front and how far
    private func checkObstacleInFront(map: GameMap) -> (tile: GameMap.TileType, distance: CGFloat) {
        guard let tank = tank else { return (.empty, 1000) }

        let velocity = tank.direction.velocity

        // Check up to 120 pixels ahead
        for dist in stride(from: 24, through: 120, by: 16) {
            let checkPos = CGPoint(
                x: tank.position.x + velocity.dx * CGFloat(dist),
                y: tank.position.y + velocity.dy * CGFloat(dist)
            )

            let tile = map.getTile(at: checkPos)
            if tile != .empty && tile != .forest && tile != .ice {
                return (tile, CGFloat(dist))
            }
        }

        return (.empty, 1000)
    }

    /// Check if base is in line of fire
    private func isBaseInLineOfFire(map: GameMap) -> Bool {
        guard let tank = tank else { return false }

        // Base is at bottom center
        let baseX = CGFloat(13) * GameConstants.tileSize + GameConstants.tileSize / 2
        let baseY = GameConstants.tileSize * 1.5

        let dx = baseX - tank.position.x
        let dy = baseY - tank.position.y

        switch tank.direction {
        case .down:
            return dy < 0 && abs(dy) < 250 && abs(dx) < 48
        case .left:
            return dx < 0 && abs(dx) < 250 && abs(dy) < 48
        case .right:
            return dx > 0 && dx < 250 && abs(dy) < 48
        case .up:
            return false
        }
    }

    /// Check if player is in line of fire
    private func playerInLineOfFire(playerTanks: [Tank], map: GameMap) -> Bool {
        guard let tank = tank else { return false }

        for player in playerTanks {
            if !player.isAlive { continue }

            let dx = player.position.x - tank.position.x
            let dy = player.position.y - tank.position.y

            let inLine: Bool
            switch tank.direction {
            case .up:
                inLine = dy > 0 && dy < 200 && abs(dx) < 36
            case .down:
                inLine = dy < 0 && abs(dy) < 200 && abs(dx) < 36
            case .left:
                inLine = dx < 0 && abs(dx) < 200 && abs(dy) < 36
            case .right:
                inLine = dx > 0 && dx < 200 && abs(dy) < 36
            }

            if inLine {
                // Check no steel wall blocking
                if !hasSteelWallBlocking(to: player.position, map: map) {
                    return true
                }
            }
        }

        return false
    }

    /// Check if steel wall blocks the path
    private func hasSteelWallBlocking(to target: CGPoint, map: GameMap) -> Bool {
        guard let tank = tank else { return true }

        let velocity = tank.direction.velocity
        let distance = tank.position.distance(to: target)

        for dist in stride(from: 24, through: Int(distance), by: 24) {
            let checkPos = CGPoint(
                x: tank.position.x + velocity.dx * CGFloat(dist),
                y: tank.position.y + velocity.dy * CGFloat(dist)
            )

            if map.getTile(at: checkPos) == .steel {
                return true
            }
        }

        return false
    }

    /// Get direction towards closest player
    private func directionTowardsPlayer(playerTanks: [Tank]) -> Direction? {
        guard let tank = tank else { return nil }

        var closestPlayer: Tank?
        var closestDistance: CGFloat = .infinity

        for player in playerTanks {
            if player.isAlive {
                let dist = tank.position.distance(to: player.position)
                if dist < closestDistance {
                    closestDistance = dist
                    closestPlayer = player
                }
            }
        }

        guard let target = closestPlayer else { return nil }

        let dx = target.position.x - tank.position.x
        let dy = target.position.y - tank.position.y

        // Choose direction based on larger delta
        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .up : .down
        }
    }
}
