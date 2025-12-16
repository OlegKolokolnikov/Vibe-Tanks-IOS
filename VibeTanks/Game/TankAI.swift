import SpriteKit

/// AI controller for enemy tanks
class TankAI {

    weak var tank: Tank?

    private var targetDirection: Direction
    private var directionChangeTimer: Int = 0
    private var stuckTimer: Int = 0
    private var lastPosition: CGPoint = .zero

    // AI behavior settings
    private let directionChangeInterval = 60 // frames
    private let shootChance: Double = 0.02
    private let aggressiveness: Double

    init(tank: Tank) {
        self.tank = tank
        self.targetDirection = Direction.random

        // Set aggressiveness based on enemy type
        switch tank.enemyType {
        case .regular:
            aggressiveness = 0.3
        case .fast:
            aggressiveness = 0.5
        case .armored:
            aggressiveness = 0.4
        case .power:
            aggressiveness = 0.6
        case .heavy:
            aggressiveness = 0.7
        case .boss:
            aggressiveness = 0.8
        }
    }

    func update(map: GameMap, playerTanks: [Tank], allTanks: [Tank]) -> (direction: Direction?, shouldShoot: Bool) {
        guard let tank = tank, tank.isAlive else {
            return (nil, false)
        }

        // Check if stuck
        let distMoved = tank.position.distance(to: lastPosition)
        if distMoved < 0.5 {
            stuckTimer += 1
            if stuckTimer > 30 {
                // Change direction when stuck
                targetDirection = findBetterDirection(map: map, allTanks: allTanks)
                stuckTimer = 0
            }
        } else {
            stuckTimer = 0
        }
        lastPosition = tank.position

        // Periodically change direction
        directionChangeTimer += 1
        if directionChangeTimer >= directionChangeInterval {
            directionChangeTimer = 0

            // Chance to target player
            if Double.random(in: 0...1) < aggressiveness {
                if let playerDir = directionTowardsPlayer(playerTanks: playerTanks) {
                    targetDirection = playerDir
                } else {
                    targetDirection = Direction.random
                }
            } else {
                targetDirection = Direction.random
            }
        }

        // Decide whether to shoot
        var shouldShoot = false
        if Double.random(in: 0...1) < shootChance {
            shouldShoot = true
        }

        // Higher chance to shoot if facing a player
        if let _ = playerInLineOfFire(playerTanks: playerTanks, map: map) {
            if Double.random(in: 0...1) < 0.3 {
                shouldShoot = true
            }
        }

        return (targetDirection, shouldShoot)
    }

    private func directionTowardsPlayer(playerTanks: [Tank]) -> Direction? {
        guard let tank = tank else { return nil }

        // Find closest alive player
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

    private func playerInLineOfFire(playerTanks: [Tank], map: GameMap) -> Tank? {
        guard let tank = tank else { return nil }

        let checkDistance: CGFloat = 200
        let velocity = tank.direction.velocity

        for player in playerTanks {
            if !player.isAlive { continue }

            // Check if player is roughly in line with our direction
            let dx = player.position.x - tank.position.x
            let dy = player.position.y - tank.position.y

            switch tank.direction {
            case .up:
                if dy > 0 && dy < checkDistance && abs(dx) < 40 {
                    return player
                }
            case .down:
                if dy < 0 && abs(dy) < checkDistance && abs(dx) < 40 {
                    return player
                }
            case .left:
                if dx < 0 && abs(dx) < checkDistance && abs(dy) < 40 {
                    return player
                }
            case .right:
                if dx > 0 && dx < checkDistance && abs(dy) < 40 {
                    return player
                }
            }
        }

        return nil
    }

    private func findBetterDirection(map: GameMap, allTanks: [Tank]) -> Direction {
        guard let tank = tank else { return .down }

        // Try each direction and pick one that's not blocked
        var validDirections: [Direction] = []

        for dir in Direction.allCases {
            let testPos = CGPoint(
                x: tank.position.x + dir.velocity.dx * 32,
                y: tank.position.y + dir.velocity.dy * 32
            )

            if !map.checkTankCollision(position: testPos, size: tank.size.width) {
                validDirections.append(dir)
            }
        }

        if validDirections.isEmpty {
            return Direction.random
        }

        // Prefer going down towards base
        if validDirections.contains(.down) && Double.random(in: 0...1) < 0.4 {
            return .down
        }

        return validDirections.randomElement() ?? .down
    }
}
