import Foundation
import CoreGraphics

/// Movement direction for tanks and bullets
enum Direction: CaseIterable {
    case up
    case down
    case left
    case right

    /// Get the velocity vector for this direction
    var velocity: CGVector {
        switch self {
        case .up: return CGVector(dx: 0, dy: 1)
        case .down: return CGVector(dx: 0, dy: -1)
        case .left: return CGVector(dx: -1, dy: 0)
        case .right: return CGVector(dx: 1, dy: 0)
        }
    }

    /// Rotation angle in radians for sprite
    var rotation: CGFloat {
        switch self {
        case .up: return 0
        case .down: return .pi
        case .left: return .pi / 2
        case .right: return -.pi / 2
        }
    }

    /// Get opposite direction
    var opposite: Direction {
        switch self {
        case .up: return .down
        case .down: return .up
        case .left: return .right
        case .right: return .left
        }
    }

    /// Get perpendicular directions
    var perpendicular: [Direction] {
        switch self {
        case .up, .down: return [.left, .right]
        case .left, .right: return [.up, .down]
        }
    }

    /// Random direction
    static var random: Direction {
        Direction.allCases.randomElement()!
    }
}
