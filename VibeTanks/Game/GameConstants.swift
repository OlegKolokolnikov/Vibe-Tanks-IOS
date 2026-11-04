import Foundation
import CoreGraphics

/// Game constants ported from Java version
struct GameConstants {
    // Map dimensions (in tiles)
    static let mapWidth = 26
    static let mapHeight = 26
    static let tileSize: CGFloat = 32

    // Sidebar (like original Battle City)
    static let sidebarWidth: CGFloat = 64

    // Game area size
    static let gameWidth: CGFloat = CGFloat(mapWidth) * tileSize
    static let gameHeight: CGFloat = CGFloat(mapHeight) * tileSize

    // Tank properties
    static let tankSize: CGFloat = 28
    static let tankSpeed: CGFloat = 2.0
    static let enemyTankSpeed: CGFloat = 1.5
    static let bossTankSize: CGFloat = 28  // Same size as other tanks so it fits every corridor
    static let alienSize: CGFloat = 22  // Small alien enemy (alien mode)

    // Player spawn / respawn point
    static let playerSpawnPosition = CGPoint(x: tileSize * 8, y: tileSize * 2)
    // Player 2 spawn: mirror of player 1 on the right side of the base (base is col 13)
    static let player2SpawnPosition = CGPoint(x: tileSize * 19, y: tileSize * 2)

    static func spawnPosition(forPlayer number: Int) -> CGPoint {
        return number == 2 ? player2SpawnPosition : playerSpawnPosition
    }

    // Bullet properties
    static let bulletSize: CGFloat = 8
    static let bulletSpeed: CGFloat = 6.0
    static let maxBulletsPerTank = 2
    static let laserSpeed: CGFloat = 10.0  // LASER shots: light, faster than bullets
    static let friendHits = 3  // Enemy hits the Gzhel friend survives (+1 per extra-life power-up)
    static let laserRoundsOnPickup = 2     // Laser lasts the current round + the next one

    // Spawn settings
    static let totalEnemies = 20
    static let maxEnemiesOnScreen = 5
    static let spawnDelay = 50 // frames (~0.8 seconds)

    // Boss settings
    static let bossBaseHealth = 10
    static let bossLevelInterval = 10  // Boss is the last tank of every 10th level
    static let fireBoostStep = 5       // Frames off the shot cooldown per star / defeated boss
    static let bossesPerExtraBullet = 3   // Every 3rd defeated boss adds a bullet per shot

    // Spawn type thresholds (cumulative probabilities)
    static let spawnRegularThreshold = 0.50
    static let spawnFastThreshold = 0.70
    static let spawnArmoredThreshold = 0.85

    // Victory delay (frames)
    static let victoryDelay = 300 // 5 seconds at 60fps

    // Respawn delay (frames)
    static let respawnDelay = 60 // 1 second

    // Shield duration
    static let shieldDuration = 3600 // 1 minute (full shield power-up)
    static let temporaryShieldDuration = 180 // 3 seconds (respawn/start)

    // Power-up settings
    static let powerUpLifetime = 600 // 10 seconds

    // Level-clear bonuses
    static let strawberryScoreThreshold = 250
    static let bananaScoreThreshold = 500
    static let strawberryPoints = 50
    static let bananaPoints = 75
    static let ballPoints = 90
    static let ballSpeedBoost: CGFloat = 0.15   // Start speed per ball
    static let ballMaxBaseSpeed: CGFloat = 1.6  // Start speed cap
    static let levelBonusVictoryDelay = 720     // 12 seconds to grab the bonuses
    static let freezeTime = 600 // 10 seconds
    static let freezeDuration = 1800 // 30 seconds (freeze power-up effect)
    // How long players stay frozen when an enemy takes the freeze power-up (frames)
    static let playerFreezeNormal = 1200  // 20 seconds
    static let playerFreezeEasy = 600     // 10 seconds
    static let playerFreezeSpecial = 900  // 15 seconds (Gzhel and alien levels)
    static let baseProtectionTime = 3600 // 1 minute (shovel power-up)

    // UFO settings
    static let ufoLifetime = 1800 // 30 seconds
    static let ufoShootCooldown = 90 // frames between shots
    static let ufoSpawnChance: Double = 0.003 // ~5.5 seconds average at 60 FPS
    static let ufoMessageDuration = 180 // 3 seconds
    static let ufoKillsRequired = 5 // kills needed before UFO can spawn

    // Easter Egg settings
    static let easterEggLifetime = 600 // 10 seconds
    static let easterEggLivesBonus = 3 // extra lives when player collects

    // Colors
    struct Colors {
        static let player1 = "#FFD700" // Gold
        static let player2 = "#00FF00" // Green
        static let enemy = "#C0C0C0"   // Silver
        static let brick = "#8B4513"   // Brown
        static let steel = "#808080"   // Gray
        static let water = "#4169E1"   // Blue
        static let forest = "#228B22"  // Forest green
        static let sidebarBg = "#636363" // Gray sidebar
    }

    // Score values
    static func scoreForEnemyType(_ type: Tank.EnemyType) -> Int {
        switch type {
        case .regular: return 1
        case .fast: return 2
        case .armored: return 3
        case .power: return 4
        case .heavy: return 5
        case .boss: return 10
        case .alien: return 5
        case .gzhel: return 0  // Ally, never scored
        }
    }
}
