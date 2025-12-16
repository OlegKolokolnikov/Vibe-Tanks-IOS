import SpriteKit

/// Game map with tiles
class GameMap: SKNode {

    enum TileType: Int {
        case empty = 0
        case brick = 1
        case steel = 2
        case water = 3
        case forest = 4
        case ice = 5
    }

    private var tiles: [[TileType]]
    private var tileNodes: [[SKShapeNode?]]
    let mapWidth: Int
    let mapHeight: Int
    let tileSize: CGFloat

    init(width: Int = GameConstants.mapWidth, height: Int = GameConstants.mapHeight) {
        self.mapWidth = width
        self.mapHeight = height
        self.tileSize = GameConstants.tileSize

        // Initialize empty map
        tiles = Array(repeating: Array(repeating: .empty, count: width), count: height)
        tileNodes = Array(repeating: Array(repeating: nil, count: width), count: height)

        super.init()

        generateRandomLevel()
        renderMap()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Level Generation

    private func generateRandomLevel() {
        // Clear protected areas (spawn points, base)
        let protectedAreas: [(x: Int, y: Int, w: Int, h: Int)] = [
            // Player spawn areas (bottom)
            (x: 0, y: 0, w: 4, h: 4),
            (x: mapWidth - 4, y: 0, w: 4, h: 4),
            // Enemy spawn areas (top)
            (x: 0, y: mapHeight - 4, w: 4, h: 4),
            (x: mapWidth / 2 - 2, y: mapHeight - 4, w: 4, h: 4),
            (x: mapWidth - 4, y: mapHeight - 4, w: 4, h: 4),
            // Base area (bottom center)
            (x: mapWidth / 2 - 2, y: 0, w: 4, h: 4)
        ]

        // Generate random tiles
        for row in 0..<mapHeight {
            for col in 0..<mapWidth {
                // Check if in protected area
                var isProtected = false
                for area in protectedAreas {
                    if col >= area.x && col < area.x + area.w &&
                       row >= area.y && row < area.y + area.h {
                        isProtected = true
                        break
                    }
                }

                if isProtected {
                    tiles[row][col] = .empty
                    continue
                }

                // Random tile with probabilities
                let rand = Double.random(in: 0...1)
                if rand < 0.3 {
                    tiles[row][col] = .brick
                } else if rand < 0.35 {
                    tiles[row][col] = .steel
                } else if rand < 0.40 {
                    tiles[row][col] = .water
                } else if rand < 0.45 {
                    tiles[row][col] = .forest
                } else {
                    tiles[row][col] = .empty
                }
            }
        }

        // Add base protection wall (brick)
        let baseCol = mapWidth / 2
        for col in (baseCol - 2)...(baseCol + 1) {
            tiles[2][col] = .brick
            tiles[3][col] = .brick
        }
        tiles[2][baseCol - 2] = .brick
        tiles[2][baseCol + 1] = .brick
    }

    private func renderMap() {
        // Remove old tiles
        removeAllChildren()

        for row in 0..<mapHeight {
            for col in 0..<mapWidth {
                let tile = tiles[row][col]
                if tile != .empty {
                    let node = createTileNode(type: tile)
                    node.position = CGPoint(
                        x: CGFloat(col) * tileSize + tileSize / 2,
                        y: CGFloat(row) * tileSize + tileSize / 2
                    )
                    node.zPosition = tile == .forest ? 15 : 1 // Forest renders above tanks
                    addChild(node)
                    tileNodes[row][col] = node
                }
            }
        }
    }

    private func createTileNode(type: TileType) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))

        switch type {
        case .brick:
            node.fillColor = SKColor(hex: "#8B4513")
            node.strokeColor = SKColor(hex: "#5D2906")
            // Add brick pattern
            addBrickPattern(to: node)
        case .steel:
            node.fillColor = SKColor(hex: "#808080")
            node.strokeColor = SKColor(hex: "#404040")
        case .water:
            node.fillColor = SKColor(hex: "#4169E1")
            node.strokeColor = SKColor(hex: "#1E3A8A")
            node.alpha = 0.8
        case .forest:
            node.fillColor = SKColor(hex: "#228B22")
            node.strokeColor = SKColor(hex: "#145214")
            node.alpha = 0.7
        case .ice:
            node.fillColor = SKColor(hex: "#ADD8E6")
            node.strokeColor = SKColor(hex: "#87CEEB")
        default:
            node.fillColor = .clear
            node.strokeColor = .clear
        }

        node.lineWidth = 1
        return node
    }

    private func addBrickPattern(to node: SKShapeNode) {
        let halfTile = tileSize / 2
        for i in 0..<2 {
            for j in 0..<2 {
                let line = SKShapeNode()
                let path = CGMutablePath()
                path.move(to: CGPoint(x: -halfTile, y: -halfTile + CGFloat(i + 1) * tileSize / 2))
                path.addLine(to: CGPoint(x: halfTile, y: -halfTile + CGFloat(i + 1) * tileSize / 2))
                line.path = path
                line.strokeColor = SKColor(hex: "#5D2906")
                line.lineWidth = 1
                node.addChild(line)
            }
        }
    }

    // MARK: - Collision Detection

    func checkTankCollision(position: CGPoint, size: CGFloat) -> Bool {
        let halfSize = size / 2
        let minCol = max(0, Int((position.x - halfSize) / tileSize))
        let maxCol = min(mapWidth - 1, Int((position.x + halfSize) / tileSize))
        let minRow = max(0, Int((position.y - halfSize) / tileSize))
        let maxRow = min(mapHeight - 1, Int((position.y + halfSize) / tileSize))

        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let tile = tiles[row][col]
                if tile == .brick || tile == .steel || tile == .water {
                    return true
                }
            }
        }

        // Check map boundaries
        if position.x - halfSize < 0 || position.x + halfSize > CGFloat(mapWidth) * tileSize ||
           position.y - halfSize < 0 || position.y + halfSize > CGFloat(mapHeight) * tileSize {
            return true
        }

        return false
    }

    func checkBulletCollision(position: CGPoint, power: Int) -> (hit: Bool, destroyed: Bool) {
        let col = Int(position.x / tileSize)
        let row = Int(position.y / tileSize)

        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else {
            return (true, false) // Hit boundary
        }

        let tile = tiles[row][col]

        switch tile {
        case .brick:
            destroyTile(row: row, col: col)
            return (true, true)
        case .steel:
            if power >= 2 {
                destroyTile(row: row, col: col)
                return (true, true)
            }
            return (true, false)
        case .water:
            return (false, false) // Bullets pass over water
        case .forest:
            return (false, false) // Bullets pass through forest
        default:
            return (false, false)
        }
    }

    private func destroyTile(row: Int, col: Int) {
        tiles[row][col] = .empty
        tileNodes[row][col]?.removeFromParent()
        tileNodes[row][col] = nil
    }

    // MARK: - Utility

    func getTile(at position: CGPoint) -> TileType {
        let col = Int(position.x / tileSize)
        let row = Int(position.y / tileSize)

        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else {
            return .empty
        }

        return tiles[row][col]
    }

    var pixelSize: CGSize {
        return CGSize(
            width: CGFloat(mapWidth) * tileSize,
            height: CGFloat(mapHeight) * tileSize
        )
    }
}
