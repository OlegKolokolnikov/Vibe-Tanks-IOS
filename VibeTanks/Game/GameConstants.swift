import Foundation
import CoreGraphics

/// Game constants ported from Java version
struct GameConstants {
    // Map dimensions (in tiles)
    static let mapWidth = 26
    static let mapHeight = 26
    static let tileSize: CGFloat = 32

    // Game area size
    static let gameWidth: CGFloat = CGFloat(mapWidth) * tileSize
    static let gameHeight: CGFloat = CGFloat(mapHeight) * tileSize

    // Tank properties
    static let tankSize: CGFloat = 28
    static let tankSpeed: CGFloat = 2.0
    static let enemyTankSpeed: CGFloat = 1.5
    static let bossTankSize: CGFloat = 28 * 4

    // Bullet properties
    static let bulletSize: CGFloat = 8
    static let bulletSpeed: CGFloat = 6.0
    static let maxBulletsPerTank = 2

    // Spawn settings
    static let totalEnemies = 20
    static let maxEnemiesOnScreen = 4
    static let spawnDelay = 120 // frames

    // Boss settings
    static let bossBaseHealth = 12

    // Spawn type thresholds (cumulative probabilities)
    static let spawnRegularThreshold = 0.50
    static let spawnFastThreshold = 0.70
    static let spawnArmoredThreshold = 0.85

    // Victory delay (frames)
    static let victoryDelay = 600 // 10 seconds at 60fps

    // Respawn delay (frames)
    static let respawnDelay = 60 // 1 second

    // Colors
    struct Colors {
        static let player1 = "#FFD700" // Gold
        static let player2 = "#00FF00" // Green
        static let enemy = "#C0C0C0"   // Silver
        static let brick = "#8B4513"   // Brown
        static let steel = "#808080"   // Gray
        static let water = "#4169E1"   // Blue
        static let forest = "#228B22"  // Forest green
    }

    // Score values
    static func scoreForEnemyType(_ type: Tank.EnemyType) -> Int {
        switch type {
        case .regular: return 1
        case .fast: return 2
        case .armored: return 3
        case .power: return 4
        case .heavy: return 5
        case .boss: return 20
        }
    }
}
