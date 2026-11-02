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

    // Gzhel friend: route to its target (distance field over tiles, rebuilt every few frames)
    private var friendRoute: [[Int]] = []
    private var friendRouteTimer: Int = 0
    private var friendWanderTimer: Int = 0
    private var friendWanderDirection: Direction = .up

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
        case .alien:
            aggressiveness = 0.5
            directionChangeInterval = 45
            shootChance = 0.03  // Fires steadily, whatever is in front of it (laser goes through walls, so less often)
        case .gzhel:
            // Hunts enemies (passed in as its targets); never goes for the base
            aggressiveness = 0.8
            directionChangeInterval = 45
            shootChance = 0.03
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

        // Chance to head towards base (down) - not for the Gzhel ally
        if tank?.enemyType != .gzhel && Double.random(in: 0...1) < 0.3 {
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

            if !map.checkTankCollision(position: testPos, size: tank.size.width, canSwim: tank.canMoveOnWater) {
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

        // Prefer going down (towards base) with some probability (enemies only)
        if tank.enemyType != .gzhel && openDirections.contains(.down) && Double.random(in: 0...1) < 0.35 {
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

        if map.checkTankCollision(position: testPos, size: tank.size.width, canSwim: tank.canMoveOnWater) {
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

        // The alien always keeps shooting: no wall cooldown, no "don't waste bullets" logic
        if tank.enemyType == .alien {
            if playerInLineOfFire(playerTanks: playerTanks, map: map) || isBaseInLineOfFire(map: map) {
                return Double.random(in: 0...1) < 0.5
            }
            return Double.random(in: 0...1) < shootChance
        }

        // If we recently shot at a wall, don't shoot again
        if shotAtWallTimer > 0 {
            return false
        }

        // Check if player is in line of fire - high priority to shoot
        if playerInLineOfFire(playerTanks: playerTanks, map: map) {
            return Double.random(in: 0...1) < 0.35
        }

        // Check if base is in line of fire (the Gzhel ally never aims at the base)
        if tank.enemyType != .gzhel && isBaseInLineOfFire(map: map) {
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

// MARK: - Gzhel friend brain

extension TankAI {

    private static let unreachable = Int.max / 2

    /// Smarter behavior for the Gzhel friend: dodges or shoots down incoming bullets, aims at enemies
    /// in a clear line, defends the base first, and finds its way to enemies (shooting through bricks).
    func updateFriend(map: GameMap, enemies: [Tank], allTanks: [Tank], enemyBullets: [Bullet]) -> (direction: Direction?, shouldShoot: Bool) {
        guard let tank = tank, tank.isAlive else { return (nil, false) }
        if shotAtWallTimer > 0 { shotAtWallTimer -= 1 }

        // Stuck (blocked by a tank or a corner): wander a moment, then plan again
        if tank.position.distance(to: lastPosition) < 0.3 {
            stuckTimer += 1
            if stuckTimer > 25 {
                friendWanderDirection = findOpenDirection(map: map, allTanks: allTanks, exclude: tank.direction)
                friendWanderTimer = 30
                stuckTimer = 0
            }
        } else {
            stuckTimer = 0
        }
        lastPosition = tank.position

        // 1. Incoming bullet: shoot it down if facing it, otherwise turn to it or sidestep
        if let bullet = incomingBullet(enemyBullets) {
            let facing = bullet.direction.opposite
            if !bullet.isLaser && tank.canShoot {
                tank.turn(to: facing)
                return (nil, true)
            }
            for side in [facing.turnedLeft, facing.turnedRight].shuffled()
            where !isDirectionBlocked(side, map: map, allTanks: allTanks) {
                return (side, false)
            }
        }

        let alive = enemies.filter { $0.isAlive }

        // 2. An enemy in a clear straight line: face it and fire (hold position when close)
        if let (direction, distance) = clearShot(at: alive, map: map) {
            tank.turn(to: direction)
            let advance = distance >= 140 && !isDirectionBlocked(direction, map: map, allTanks: allTanks)
            return (advance ? direction : nil, true)
        }

        if friendWanderTimer > 0 {
            friendWanderTimer -= 1
            return (friendWanderDirection, false)
        }

        // 3. Go after the enemy closest to the base if one is near it, else the nearest one;
        //    with no enemies around, guard the area in front of the base
        let target: CGPoint
        let base = TankAI.basePosition
        if let danger = alive.filter({ $0.position.distance(to: base) < 260 })
            .min(by: { $0.position.distance(to: base) < $1.position.distance(to: base) }) {
            target = danger.position
        } else if let nearest = alive.min(by: { $0.position.distance(to: tank.position) < $1.position.distance(to: tank.position) }) {
            target = nearest.position
        } else {
            target = TankAI.center(row: GameConstants.mapHeight - 9, col: GameConstants.mapWidth / 2)
        }

        friendRouteTimer -= 1
        if friendRouteTimer <= 0 || friendRoute.isEmpty {
            friendRoute = buildRoute(to: target, map: map)
            friendRouteTimer = 15
        }

        let (row, col) = TankAI.tileOf(tank.position)
        guard row >= 0, row < friendRoute.count, col >= 0, col < friendRoute[row].count else { return (nil, false) }
        let here = friendRoute[row][col]
        if here == 0 {
            return (nil, false)  // Arrived (guard spot): wait here
        }

        // Step to the neighboring tile that is closest to the target
        var best: (direction: Direction, distance: Int)?
        for direction in Direction.allCases {
            let (dr, dc) = TankAI.tileStep(direction)
            let r = row + dr, c = col + dc
            guard r >= 0, r < friendRoute.count, c >= 0, c < friendRoute[r].count else { continue }
            let d = friendRoute[r][c]
            if d < (best?.distance ?? here) {
                best = (direction, d)
            }
        }
        guard let step = best else {
            return (findOpenDirection(map: map, allTanks: allTanks, exclude: nil), false)
        }

        // The way leads through a brick wall: face it and shoot it open
        let nextTile = map.getTile(at: TankAI.center(row: row + TankAI.tileStep(step.direction).0,
                                                     col: col + TankAI.tileStep(step.direction).1))
        if nextTile == .brick {
            tank.turn(to: step.direction)
            if shotAtWallTimer == 0 && tank.canShoot {
                shotAtWallTimer = 20
                return (nil, true)
            }
            return (nil, false)
        }
        return (step.direction, false)
    }

    // MARK: Friend helpers

    private static var basePosition: CGPoint {
        CGPoint(x: 13 * GameConstants.tileSize + GameConstants.tileSize / 2, y: GameConstants.tileSize * 1.5)
    }

    /// Base walls (bricks around the cat): the friend never shoots or drives through them
    private static func isBaseWall(row: Int, col: Int) -> Bool {
        (GameConstants.mapHeight - 3...GameConstants.mapHeight - 2).contains(row) && (12...14).contains(col)
    }

    private static func tileOf(_ point: CGPoint) -> (Int, Int) {
        let col = Int(point.x / GameConstants.tileSize)
        let row = GameConstants.mapHeight - 1 - Int(point.y / GameConstants.tileSize)
        return (row, col)
    }

    private static func center(row: Int, col: Int) -> CGPoint {
        CGPoint(x: (CGFloat(col) + 0.5) * GameConstants.tileSize,
                y: (CGFloat(GameConstants.mapHeight - 1 - row) + 0.5) * GameConstants.tileSize)
    }

    /// Row/column change for one tile in a direction (rows grow downward)
    private static func tileStep(_ direction: Direction) -> (Int, Int) {
        switch direction {
        case .up: return (-1, 0)
        case .down: return (1, 0)
        case .left: return (0, -1)
        case .right: return (0, 1)
        }
    }

    /// Distance (in steps) from every tile to the target. Open ground costs 1,
    /// bricks cost 4 (they have to be shot first), steel and the base walls can't be crossed.
    private func buildRoute(to target: CGPoint, map: GameMap) -> [[Int]] {
        guard let tank = tank else { return [] }
        let rows = GameConstants.mapHeight, cols = GameConstants.mapWidth
        var dist = Array(repeating: Array(repeating: TankAI.unreachable, count: cols), count: rows)
        let (targetRow, targetCol) = TankAI.tileOf(target)
        guard targetRow >= 0, targetRow < rows, targetCol >= 0, targetCol < cols else { return dist }

        func cost(_ row: Int, _ col: Int) -> Int? {
            if TankAI.isBaseWall(row: row, col: col) { return nil }
            switch map.getTile(at: TankAI.center(row: row, col: col)) {
            case .empty, .forest, .ice: return 1
            case .water: return tank.canMoveOnWater ? 1 : nil
            case .brick: return 4
            case .steel: return nil
            }
        }

        dist[targetRow][targetCol] = 0
        var frontier: [(Int, Int, Int)] = [(0, targetRow, targetCol)]
        while !frontier.isEmpty {
            let index = frontier.indices.min { frontier[$0].0 < frontier[$1].0 }!
            let (d, row, col) = frontier.remove(at: index)
            guard d == dist[row][col] else { continue }
            // Cost of the tile we come from (the route runs from the friend to the target)
            let stepCost = (row == targetRow && col == targetCol) ? 1 : (cost(row, col) ?? 1)
            for direction in Direction.allCases {
                let (dr, dc) = TankAI.tileStep(direction)
                let r = row + dr, c = col + dc
                guard r >= 1, r < rows - 1, c >= 1, c < cols - 1, cost(r, c) != nil else { continue }
                let next = d + stepCost
                if next < dist[r][c] {
                    dist[r][c] = next
                    frontier.append((next, r, c))
                }
            }
        }
        return dist
    }

    /// An enemy straight up/down/left/right with nothing in the way the bullet can't pass
    private func clearShot(at enemies: [Tank], map: GameMap) -> (Direction, CGFloat)? {
        guard let tank = tank else { return nil }
        var best: (Direction, CGFloat)?
        for enemy in enemies {
            let dx = enemy.position.x - tank.position.x
            let dy = enemy.position.y - tank.position.y
            let reach = enemy.size.width / 2 + 2
            let direction: Direction
            let distance: CGFloat
            if abs(dx) < reach && abs(dy) < 420 {
                direction = dy > 0 ? .up : .down
                distance = abs(dy)
            } else if abs(dy) < reach && abs(dx) < 420 {
                direction = dx > 0 ? .right : .left
                distance = abs(dx)
            } else {
                continue
            }
            guard isLineClear(from: tank.position, direction: direction, distance: distance, map: map) else { continue }
            if distance < (best?.1 ?? .infinity) {
                best = (direction, distance)
            }
        }
        return best
    }

    /// Steel (without the GUN power) or the base walls stop the shot; bricks just get shot through
    private func isLineClear(from start: CGPoint, direction: Direction, distance: CGFloat, map: GameMap) -> Bool {
        guard let tank = tank else { return false }
        let velocity = direction.velocity
        var travelled: CGFloat = tank.size.width / 2
        while travelled < distance - 8 {
            let point = CGPoint(x: start.x + velocity.dx * travelled, y: start.y + velocity.dy * travelled)
            let (row, col) = TankAI.tileOf(point)
            if TankAI.isBaseWall(row: row, col: col) { return false }
            let tile = map.getTile(at: point)
            if tile == .steel && tank.bulletPower < 2 { return false }
            travelled += 8
        }
        return true
    }

    /// The closest enemy bullet that will hit the friend soon
    private func incomingBullet(_ bullets: [Bullet]) -> Bullet? {
        guard let tank = tank else { return nil }
        var closest: (Bullet, CGFloat)?
        for bullet in bullets {
            let v = bullet.direction.velocity
            let rx = tank.position.x - bullet.position.x
            let ry = tank.position.y - bullet.position.y
            let ahead = rx * v.dx + ry * v.dy          // Distance along the bullet's path
            let aside = abs(rx * v.dy - ry * v.dx)     // Distance off its path
            guard ahead > 0, ahead < 150, aside < tank.size.width / 2 + 4 else { continue }
            if ahead < (closest?.1 ?? .infinity) {
                closest = (bullet, ahead)
            }
        }
        return closest?.0
    }
}

private extension Direction {
    /// The two directions at a right angle
    var turnedLeft: Direction {
        switch self {
        case .up: return .left
        case .left: return .down
        case .down: return .right
        case .right: return .up
        }
    }

    var turnedRight: Direction { turnedLeft.opposite }
}
