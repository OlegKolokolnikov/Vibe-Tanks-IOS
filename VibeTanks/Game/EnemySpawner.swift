import SpriteKit

/// Handles spawning of enemy tanks
class EnemySpawner {

    private var totalEnemies: Int
    private let maxOnScreen: Int
    private var spawnedCount: Int = 0
    private var spawnCooldown: Int

    // Spawn positions (top of map)
    private let spawnPositions: [CGPoint]

    init(totalEnemies: Int, maxOnScreen: Int) {
        self.totalEnemies = totalEnemies
        self.maxOnScreen = maxOnScreen
        self.spawnCooldown = GameConstants.spawnDelay

        // Initialize spawn positions
        let tileSize = GameConstants.tileSize
        let mapWidth = GameConstants.mapWidth
        let mapHeight = GameConstants.mapHeight

        spawnPositions = [
            CGPoint(x: tileSize * 2, y: CGFloat(mapHeight - 2) * tileSize),
            CGPoint(x: CGFloat(mapWidth / 2) * tileSize, y: CGFloat(mapHeight - 2) * tileSize),
            CGPoint(x: CGFloat(mapWidth - 2) * tileSize, y: CGFloat(mapHeight - 2) * tileSize)
        ]
    }

    func update(existingEnemies: [Tank], map: GameMap) -> Tank? {
        // Check if we can spawn more
        guard spawnedCount < totalEnemies else { return nil }
        guard existingEnemies.count < maxOnScreen else { return nil }

        spawnCooldown -= 1
        guard spawnCooldown <= 0 else { return nil }

        // Reset cooldown
        spawnCooldown = GameConstants.spawnDelay

        // Determine enemy type
        let type = determineEnemyType()

        // Find valid spawn position
        guard let position = findValidSpawnPosition(
            type: type,
            existingEnemies: existingEnemies,
            map: map
        ) else {
            return nil
        }

        // Create enemy
        let enemy = Tank(
            position: position,
            direction: .down,
            isPlayer: false,
            playerNumber: 0,
            enemyType: type
        )

        spawnedCount += 1
        return enemy
    }

    private func determineEnemyType() -> Tank.EnemyType {
        let remaining = totalEnemies - spawnedCount

        // Last few are HEAVY
        if remaining <= 6 {
            return .heavy
        }

        // Random based on probability
        let rand = Double.random(in: 0...1)

        if rand < GameConstants.spawnRegularThreshold {
            return .regular
        } else if rand < GameConstants.spawnFastThreshold {
            return .fast
        } else if rand < GameConstants.spawnArmoredThreshold {
            return .armored
        } else {
            return .power
        }
    }

    private func findValidSpawnPosition(
        type: Tank.EnemyType,
        existingEnemies: [Tank],
        map: GameMap
    ) -> CGPoint? {
        let tankSize = GameConstants.tankSize

        // Try random spawn position
        let shuffled = spawnPositions.shuffled()
        for pos in shuffled {
            if isPositionValid(pos, tankSize: tankSize, existingEnemies: existingEnemies, map: map) {
                return pos
            }
        }

        return nil
    }

    private func isPositionValid(
        _ position: CGPoint,
        tankSize: CGFloat,
        existingEnemies: [Tank],
        map: GameMap
    ) -> Bool {
        // Check collision with other tanks
        for enemy in existingEnemies {
            let minDist = (tankSize + enemy.size.width) / 2
            if position.distance(to: enemy.position) < minDist {
                return false
            }
        }

        // Check collision with map
        if map.checkTankCollision(position: position, size: tankSize) {
            return false
        }

        return true
    }

    func allEnemiesDefeated(currentEnemies: [Tank]) -> Bool {
        return spawnedCount >= totalEnemies && currentEnemies.isEmpty && extraEnemiesToSpawn == 0
    }

    var remainingEnemies: Int {
        return totalEnemies - spawnedCount + extraEnemiesToSpawn
    }

    // Extra enemies from tank power-up (spawned separately, don't affect boss logic)
    private var extraEnemiesToSpawn: Int = 0

    /// Queue an extra enemy to spawn (when enemy collects tank power-up)
    func addExtraEnemy() {
        extraEnemiesToSpawn += 1
    }

    /// Try to spawn an extra enemy (called from GameScene)
    func spawnExtraEnemy(existingEnemies: [Tank], map: GameMap) -> Tank? {
        guard extraEnemiesToSpawn > 0 else { return nil }
        guard existingEnemies.count < maxOnScreen else { return nil }

        // Pick a random non-boss type
        let types: [Tank.EnemyType] = [.regular, .fast, .armored, .power]
        let type = types.randomElement() ?? .regular

        // Find valid spawn position
        guard let position = findValidSpawnPosition(
            type: type,
            existingEnemies: existingEnemies,
            map: map
        ) else {
            return nil
        }

        // Create extra enemy
        let enemy = Tank(
            position: position,
            direction: .down,
            isPlayer: false,
            playerNumber: 0,
            enemyType: type
        )

        extraEnemiesToSpawn -= 1
        return enemy
    }
}
