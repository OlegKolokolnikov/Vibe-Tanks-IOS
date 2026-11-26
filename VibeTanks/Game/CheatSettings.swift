import Foundation
import CoreGraphics

/// Cheats, unlocked with the Konami code on the start menu (↑↑↓↓←→←→ B A, or the same swipes + two taps).
/// The settings are saved, but they only take effect after the code is entered (once per app launch).
final class CheatSettings {
    static let shared = CheatSettings()

    /// Level kinds: nil = AUTO (the game decides as usual), forced on every level,
    /// only on the first level of the game (the start level), or never
    enum Force: String, Codable {
        case always, once, never

        /// The game's own choice with this override applied
        static func apply(_ force: Force?, to natural: Bool, firstLevel: Bool) -> Bool {
            switch force {
            case .always: return true
            case .once: return firstLevel || natural
            case .never: return false
            case nil: return natural
            }
        }

        /// AUTO → ALWAYS → ONCE → NEVER → AUTO (backwards for a negative step)
        static func cycle(_ force: Force?, by delta: Int) -> Force? {
            let order: [Force?] = [nil, .always, .once, .never]
            let index = order.firstIndex(of: force) ?? 0
            return order[(index + (delta < 0 ? order.count - 1 : 1)) % order.count]
        }
    }

    struct Config: Codable, Equatable {
        // Players
        var playerSpeed: Double = 1
        var playerFireRate: Double = 1
        var playerLives: Int = 3
        var startLevel: Int = 1

        // Power-ups every player starts the game with
        var stars: Int = 0
        var machineguns: Int = 0
        var cars: Int = 0
        var gun = false
        var ship = false
        var saw = false
        var shield = false
        var laser = false
        var magic = false
        var steelBase = false

        // Enemies
        var enemySpeed: Double = 1
        var enemyFireRate: Double = 1
        var enemiesTakePowerUps = true
        var enemyCount: Int = 0       // 0 = normal for the level
        var enemiesOnScreen: Int = 0  // 0 = normal (5)
        var enemyArmor: Int = 0       // Extra hits for every enemy
        var ufoEnabled = true

        // Level kinds (optional, so configs saved before these existed still load)
        var alienLevel: Force?
        var gzhelLevel: Force?
        var bossLevel: Force?
        var bonusLevel: Force?
        var friendLevel: Force?
        var easyLevel: Force?

        var crazyMode = false
    }

    /// Speed and fire-rate multipliers the cheat screen offers
    static let factorSteps: [Double] = [0.25, 0.5, 0.75, 1, 1.25, 1.5, 2, 2.5, 3]
    static let livesSteps = [1, 2, 3, 4, 5, 7, 10, 15, 20, 30, 50, 75, 99]
    static let levelSteps = Array(1...10) + [15, 20, 25, 30, 40, 50, 75, 100]
    static let enemyCountSteps = [0, 1, 5, 10, 20, 30, 50, 75, 100, 200, 500, 1000]
    static let onScreenSteps = [0] + Array(1...20)

    private let storageKey = "cheatConfig"

    /// Entered the Konami code this launch
    var isUnlocked = false

    var config: Config {
        didSet { save() }
    }

    private init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(Config.self, from: data) {
            config = saved
        } else {
            config = Config()
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    func reset() {
        config = Config()
    }

    /// Cheats change the game (unlocked and something differs from normal). High scores aren't saved then.
    var isActive: Bool { isUnlocked && config != Config() }

    /// The settings the game plays with: normal ones when cheats are off
    var active: Config { isActive ? config : Config() }

    var isCrazy: Bool { active.crazyMode }
}
