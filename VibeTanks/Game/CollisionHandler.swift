import SpriteKit

/// Handles collision detection between game objects
class CollisionHandler {

    /// Check collision between two rectangles
    static func checkRectCollision(
        pos1: CGPoint, size1: CGFloat,
        pos2: CGPoint, size2: CGFloat
    ) -> Bool {
        let halfSize1 = size1 / 2
        let halfSize2 = size2 / 2

        let dx = abs(pos1.x - pos2.x)
        let dy = abs(pos1.y - pos2.y)

        return dx < halfSize1 + halfSize2 && dy < halfSize1 + halfSize2
    }

    /// Check collision between circle and rectangle
    static func checkCircleRectCollision(
        circlePos: CGPoint, radius: CGFloat,
        rectPos: CGPoint, rectSize: CGFloat
    ) -> Bool {
        let halfSize = rectSize / 2

        let dx = abs(circlePos.x - rectPos.x)
        let dy = abs(circlePos.y - rectPos.y)

        if dx > halfSize + radius { return false }
        if dy > halfSize + radius { return false }

        if dx <= halfSize { return true }
        if dy <= halfSize { return true }

        let cornerDist = pow(dx - halfSize, 2) + pow(dy - halfSize, 2)
        return cornerDist <= radius * radius
    }

    /// Check if point is inside rectangle
    static func pointInRect(
        point: CGPoint,
        rectPos: CGPoint,
        rectSize: CGFloat
    ) -> Bool {
        let halfSize = rectSize / 2

        return point.x >= rectPos.x - halfSize &&
               point.x <= rectPos.x + halfSize &&
               point.y >= rectPos.y - halfSize &&
               point.y <= rectPos.y + halfSize
    }

    /// Get distance between two points
    static func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        let dx = p1.x - p2.x
        let dy = p1.y - p2.y
        return sqrt(dx * dx + dy * dy)
    }

    /// Check line of sight between two points (no walls blocking)
    static func hasLineOfSight(
        from: CGPoint,
        to: CGPoint,
        map: GameMap,
        stepSize: CGFloat = 16
    ) -> Bool {
        let dx = to.x - from.x
        let dy = to.y - from.y
        let dist = sqrt(dx * dx + dy * dy)

        if dist == 0 { return true }

        let steps = Int(dist / stepSize)
        let stepX = dx / CGFloat(steps)
        let stepY = dy / CGFloat(steps)

        for i in 1..<steps {
            let checkPoint = CGPoint(
                x: from.x + stepX * CGFloat(i),
                y: from.y + stepY * CGFloat(i)
            )

            let tile = map.getTile(at: checkPoint)
            if tile == .brick || tile == .steel {
                return false
            }
        }

        return true
    }
}
