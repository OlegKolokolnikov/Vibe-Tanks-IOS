import SpriteKit

/// Handles spawning of enemy tanks
class EnemySpawner {

    private var totalEnemies: Int
    private let maxOnScreen: Int
    private var spawnedCount: Int = 0
    private var spawnCooldown: Int

    // Pre-planned enemy types for guaranteed distribution
    private var plannedEnemyTypes: [Tank.EnemyType] = []

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

        // Plan enemy types with guaranteed distribution
        plannedEnemyTypes = planEnemyTypes(total: totalEnemies)
    }

    /// Plan enemy types ensuring: exactly 5 heavy, at least 5 power, rest are regular/fast/armored
    private func planEnemyTypes(total: Int) -> [Tank.EnemyType] {
        var types: [Tank.EnemyType] = []

        // Exactly 5 heavy tanks
        let heavyCount = 5
        for _ in 0..<heavyCount {
            types.append(.heavy)
        }

        // At least 5 power tanks
        let powerCount = 5
        for _ in 0..<powerCount {
            types.append(.power)
        }

        // Fill the rest with regular, fast, armored (and possibly more power)
        let remaining = total - heavyCount - powerCount
        let otherTypes: [Tank.EnemyType] = [.regular, .fast, .armored, .power]
        for _ in 0..<remaining {
            types.append(otherTypes.randomElement() ?? .regular)
        }

        // Shuffle so they don't spawn in predictable order (but heavy tanks spawn later)
        // Separate heavy tanks and others, shuffle others, then place heavy at end
        var nonHeavy = types.filter { $0 != .heavy }
        let heavy = types.filter { $0 == .heavy }
        nonHeavy.shuffle()

        // Insert heavy tanks spread across the last portion
        var result = nonHeavy
        for (index, heavyTank) in heavy.enumerated() {
            // Place heavy tanks in the last third of spawns
            let insertPos = result.count - (heavy.count - index - 1)
            result.insert(heavyTank, at: max(insertPos, result.count * 2 / 3))
        }

        return result
    }

    func update(existingEnemies: [Tank], playerTank: Tank?, map: GameMap) -> Tank? {
        // Check if we can spawn more
        guard spawnedCount < totalEnemies else { return nil }
        guard existingEnemies.count < maxOnScreen else { return nil }

        spawnCooldown -= 1
        guard spawnCooldown <= 0 else { return nil }

        // Reset cooldown
        spawnCooldown = GameConstants.spawnDelay

        // Determine enemy type
        let type = determineEnemyType()

        // Find valid spawn position (also checks player position)
        guard let position = findValidSpawnPosition(
            type: type,
            existingEnemies: existingEnemies,
            playerTank: playerTank,
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
        // Use pre-planned type if available
        if spawnedCount < plannedEnemyTypes.count {
            return plannedEnemyTypes[spawnedCount]
        }
        // Fallback for any extra spawns
        return .regular
    }

    private func findValidSpawnPosition(
        type: Tank.EnemyType,
        existingEnemies: [Tank],
        playerTank: Tank?,
        map: GameMap
    ) -> CGPoint? {
        let tankSize = GameConstants.tankSize

        // Try random spawn position
        let shuffled = spawnPositions.shuffled()
        for pos in shuffled {
            if isPositionValid(pos, tankSize: tankSize, existingEnemies: existingEnemies, playerTank: playerTank, map: map) {
                return pos
            }
        }

        return nil
    }

    private func isPositionValid(
        _ position: CGPoint,
        tankSize: CGFloat,
        existingEnemies: [Tank],
        playerTank: Tank?,
        map: GameMap
    ) -> Bool {
        // Check collision with other enemy tanks
        for enemy in existingEnemies {
            let minDist = (tankSize + enemy.size.width) / 2
            if position.distance(to: enemy.position) < minDist {
                return false
            }
        }

        // Check collision with player tank (prevent spawning on player)
        if let player = playerTank, player.isAlive {
            let minDist = (tankSize + player.size.width) / 2
            if position.distance(to: player.position) < minDist {
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
    func spawnExtraEnemy(existingEnemies: [Tank], playerTank: Tank?, map: GameMap) -> Tank? {
        guard extraEnemiesToSpawn > 0 else { return nil }
        guard existingEnemies.count < maxOnScreen else { return nil }

        // Pick a random non-boss type
        let types: [Tank.EnemyType] = [.regular, .fast, .armored, .power]
        let type = types.randomElement() ?? .regular

        // Find valid spawn position (also checks player position)
        guard let position = findValidSpawnPosition(
            type: type,
            existingEnemies: existingEnemies,
            playerTank: playerTank,
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
