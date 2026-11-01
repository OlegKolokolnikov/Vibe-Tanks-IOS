import SpriteKit
import UIKit

/// Stores and loads user preferences
class GameSettings {
    static let shared = GameSettings()

    private let controlsSwappedKey = "controlsSwapped"
    private let playerColorKey = "playerTankColor"
    private let player2ColorKey = "player2TankColor"
    private let volumeKey = "volumeLevel"
    private let mutedKey = "isMuted"

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

    /// Number of volume steps (0 = off, maxVolumeLevel = 100%)
    static let maxVolumeLevel = 10

    /// Sound volume level, 0...maxVolumeLevel (default: full volume)
    var volumeLevel: Int {
        get {
            guard UserDefaults.standard.object(forKey: volumeKey) != nil else {
                return GameSettings.maxVolumeLevel
            }
            let level = UserDefaults.standard.integer(forKey: volumeKey)
            return min(max(level, 0), GameSettings.maxVolumeLevel)
        }
        set {
            let clamped = min(max(newValue, 0), GameSettings.maxVolumeLevel)
            UserDefaults.standard.set(clamped, forKey: volumeKey)
        }
    }

    /// All sound muted (volume level is kept, so unmuting restores it)
    var isMuted: Bool {
        get { UserDefaults.standard.bool(forKey: mutedKey) }
        set { UserDefaults.standard.set(newValue, forKey: mutedKey) }
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
            // Same color as player 2 is not allowed
            guard newValue != player2TankColor else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: playerColorKey)
        }
    }

    /// Player 2 tank color (default green). Never the same as player 1's color:
    /// setting player 2 to player 1's color is ignored, and a clash falls back to another color.
    var player2TankColor: TankColor {
        get {
            let player1 = playerTankColor
            if let rawValue = UserDefaults.standard.string(forKey: player2ColorKey),
               let color = TankColor(rawValue: rawValue), color != player1 {
                return color
            }
            let preferred: [TankColor] = [.green, .blue, .purple, .yellow]
            return preferred.first { $0 != player1 } ?? .green
        }
        set {
            guard newValue != playerTankColor else { return }
            UserDefaults.standard.set(newValue.rawValue, forKey: player2ColorKey)
        }
    }

    // MARK: - Keyboard keys (per player)

    /// Something a player can do with a key
    enum KeyAction: String, CaseIterable {
        case up, down, left, right, fire

        var displayName: String {
            switch self {
            case .up: return "UP"
            case .down: return "DOWN"
            case .left: return "LEFT"
            case .right: return "RIGHT"
            case .fire: return "FIRE"
            }
        }

        /// Movement direction (nil for fire)
        var direction: Direction? {
            switch self {
            case .up: return .up
            case .down: return .down
            case .left: return .left
            case .right: return .right
            case .fire: return nil
            }
        }
    }

    /// Default keys: player 1 WASD + Space, player 2 arrows + Enter
    static let defaultKeys: [[KeyAction: UIKeyboardHIDUsage]] = [
        [.up: .keyboardW, .down: .keyboardS, .left: .keyboardA, .right: .keyboardD, .fire: .keyboardSpacebar],
        [.up: .keyboardUpArrow, .down: .keyboardDownArrow, .left: .keyboardLeftArrow,
         .right: .keyboardRightArrow, .fire: .keyboardReturnOrEnter]
    ]

    /// Keys that can't be assigned: Escape and P pause the game
    static let reservedKeys: Set<UIKeyboardHIDUsage> = [.keyboardEscape, .keyboardP]

    private func keyStorageKey(_ action: KeyAction, player: Int) -> String {
        return "key_p\(player + 1)_\(action.rawValue)"
    }

    /// Key for an action of a player (0 = player 1, 1 = player 2)
    func key(for action: KeyAction, player: Int) -> UIKeyboardHIDUsage {
        let stored = UserDefaults.standard.integer(forKey: keyStorageKey(action, player: player))
        if stored > 0, let key = UIKeyboardHIDUsage(rawValue: stored) {
            return key
        }
        return GameSettings.defaultKeys[player][action] ?? .keyboardSpacebar
    }

    /// Assign a key. If another action (of either player) already uses it, the two swap keys,
    /// so a key never does two things.
    func setKey(_ key: UIKeyboardHIDUsage, for action: KeyAction, player: Int) {
        guard !GameSettings.reservedKeys.contains(key) else { return }
        let previous = self.key(for: action, player: player)
        for otherPlayer in 0..<2 {
            for otherAction in KeyAction.allCases where !(otherPlayer == player && otherAction == action) {
                if self.key(for: otherAction, player: otherPlayer) == key {
                    UserDefaults.standard.set(previous.rawValue, forKey: keyStorageKey(otherAction, player: otherPlayer))
                }
            }
        }
        UserDefaults.standard.set(key.rawValue, forKey: keyStorageKey(action, player: player))
    }

    func resetKeys() {
        for player in 0..<2 {
            for action in KeyAction.allCases {
                UserDefaults.standard.removeObject(forKey: keyStorageKey(action, player: player))
            }
        }
    }

    /// Short name of a key for the controls screen
    static func keyName(_ key: UIKeyboardHIDUsage) -> String {
        let raw = key.rawValue
        let letterA = UIKeyboardHIDUsage.keyboardA.rawValue
        let letterZ = UIKeyboardHIDUsage.keyboardZ.rawValue
        if raw >= letterA && raw <= letterZ {
            return String(UnicodeScalar(UInt8(65 + raw - letterA)))
        }
        let digit1 = UIKeyboardHIDUsage.keyboard1.rawValue
        let digit0 = UIKeyboardHIDUsage.keyboard0.rawValue
        if raw >= digit1 && raw < digit0 {
            return String(raw - digit1 + 1)
        }
        switch key {
        case .keyboard0: return "0"
        case .keyboardUpArrow: return "\u{2191}"
        case .keyboardDownArrow: return "\u{2193}"
        case .keyboardLeftArrow: return "\u{2190}"
        case .keyboardRightArrow: return "\u{2192}"
        case .keyboardSpacebar: return "SPACE"
        case .keyboardReturnOrEnter, .keypadEnter: return "ENTER"
        case .keyboardTab: return "TAB"
        case .keyboardDeleteOrBackspace: return "DELETE"
        case .keyboardLeftShift: return "L-SHIFT"
        case .keyboardRightShift: return "R-SHIFT"
        case .keyboardLeftControl: return "L-CTRL"
        case .keyboardRightControl: return "R-CTRL"
        case .keyboardLeftAlt: return "L-OPT"
        case .keyboardRightAlt: return "R-OPT"
        case .keyboardLeftGUI: return "L-CMD"
        case .keyboardRightGUI: return "R-CMD"
        case .keyboardComma: return ","
        case .keyboardPeriod: return "."
        case .keyboardSlash: return "/"
        case .keyboardSemicolon: return ";"
        case .keyboardQuote: return "'"
        case .keyboardOpenBracket: return "["
        case .keyboardCloseBracket: return "]"
        case .keyboardBackslash: return "\\"
        case .keyboardHyphen: return "-"
        case .keyboardEqualSign: return "="
        case .keyboardGraveAccentAndTilde: return "`"
        default:
            if raw >= UIKeyboardHIDUsage.keypad1.rawValue && raw <= UIKeyboardHIDUsage.keypad0.rawValue {
                let n = raw - UIKeyboardHIDUsage.keypad1.rawValue + 1
                return "NUM \(n == 10 ? 0 : n)"
            }
            return "KEY \(raw)"
        }
    }

    // MARK: - Touch layout (two-player games)

    /// Where a player's fire button sits next to their joystick (two-player touch controls).
    /// "Inside" = toward the middle of the screen, "outside" = at the screen edge.
    enum FirePlacement: String, CaseIterable {
        case above, below, inside, outside

        var displayName: String {
            switch self {
            case .above: return "FIRE ABOVE"
            case .below: return "FIRE BELOW"
            case .inside: return "FIRE INSIDE"
            case .outside: return "FIRE OUTSIDE"
            }
        }

        var next: FirePlacement {
            let all = FirePlacement.allCases
            return all[(all.firstIndex(of: self)! + 1) % all.count]
        }
    }

    func firePlacement(player: Int) -> FirePlacement {
        if let raw = UserDefaults.standard.string(forKey: "firePlacement_p\(player + 1)"),
           let placement = FirePlacement(rawValue: raw) {
            return placement
        }
        return .above
    }

    func setFirePlacement(_ placement: FirePlacement, player: Int) {
        UserDefaults.standard.set(placement.rawValue, forKey: "firePlacement_p\(player + 1)")
    }
}
