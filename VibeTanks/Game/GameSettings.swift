import SpriteKit

/// Stores and loads user preferences
class GameSettings {
    static let shared = GameSettings()

    private let controlsSwappedKey = "controlsSwapped"
    private let playerColorKey = "playerTankColor"

    enum TankColor: String, CaseIterable {
        case yellow = "yellow"
        case green = "green"
        case blue = "blue"
        case purple = "purple"

        var displayName: String {
            switch self {
            case .yellow: return "Yellow"
            case .green: return "Green"
            case .blue: return "Blue"
            case .purple: return "Purple"
            }
        }

        var color: SKColor {
            switch self {
            case .yellow: return SKColor(red: 1.0, green: 0.84, blue: 0.0, alpha: 1.0)  // Gold
            case .green: return SKColor(red: 0.2, green: 0.8, blue: 0.2, alpha: 1.0)
            case .blue: return SKColor(red: 0.3, green: 0.5, blue: 1.0, alpha: 1.0)
            case .purple: return SKColor(red: 0.7, green: 0.3, blue: 0.9, alpha: 1.0)
            }
        }
    }

    private init() {}

    /// Whether fire button and joystick positions are swapped
    var controlsSwapped: Bool {
        get {
            return UserDefaults.standard.bool(forKey: controlsSwappedKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: controlsSwappedKey)
        }
    }

    /// Player tank color preference
    var playerTankColor: TankColor {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: playerColorKey),
               let color = TankColor(rawValue: rawValue) {
                return color
            }
            return .yellow
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: playerColorKey)
        }
    }
}
