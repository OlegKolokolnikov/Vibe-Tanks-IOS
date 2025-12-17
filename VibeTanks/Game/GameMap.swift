import SpriteKit
import GameplayKit

/// Game map with tile-based terrain
class GameMap: SKNode {

    enum TileType: Int {
        case empty = 0
        case brick
        case steel
        case water
        case forest
        case ice
    }

    // Static texture cache for performance
    private static var textureCache: [TileType: SKTexture] = [:]

    private let mapWidth: Int
    private let mapHeight: Int
    private let tileSize: CGFloat
    private var tiles: [[TileType]]
    private var tileNodes: [[SKNode?]]

    // Seeded random source for deterministic level generation
    private var randomSource: GKMersenneTwisterRandomSource!

    var pixelSize: CGSize {
        CGSize(
            width: CGFloat(mapWidth) * tileSize,
            height: CGFloat(mapHeight) * tileSize
        )
    }

    init(level: Int = 1, seed: UInt64 = 0) {
        self.mapWidth = GameConstants.mapWidth
        self.mapHeight = GameConstants.mapHeight
        self.tileSize = GameConstants.tileSize
        self.tiles = Array(repeating: Array(repeating: .empty, count: mapWidth), count: mapHeight)
        self.tileNodes = Array(repeating: Array(repeating: nil, count: GameConstants.mapWidth), count: GameConstants.mapHeight)

        super.init()

        // Initialize seeded random source
        // If seed is provided (from session), use it; otherwise generate randomly
        let finalSeed = seed != 0 ? seed : UInt64.random(in: 0..<UInt64.max)
        self.randomSource = GKMersenneTwisterRandomSource(seed: finalSeed)

        // Pre-generate textures if needed
        Self.generateTexturesIfNeeded(tileSize: tileSize)

        generateLevel(levelNumber: level)
        renderMap()
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Seeded Random Helpers

    private func randomInt(in range: ClosedRange<Int>) -> Int {
        return randomSource.nextInt(upperBound: range.upperBound - range.lowerBound + 1) + range.lowerBound
    }

    private func randomInt(in range: Range<Int>) -> Int {
        guard range.upperBound > range.lowerBound else { return range.lowerBound }
        return randomSource.nextInt(upperBound: range.upperBound - range.lowerBound) + range.lowerBound
    }

    private func randomDouble() -> Double {
        return Double(randomSource.nextUniform())
    }

    private func randomBool() -> Bool {
        return randomSource.nextBool()
    }

    // MARK: - Level Generation

    private func generateLevel(levelNumber: Int) {
        // Clear to empty
        for row in 0..<mapHeight {
            for col in 0..<mapWidth {
                tiles[row][col] = .empty
            }
        }

        // Create border walls (steel)
        for i in 0..<mapWidth {
            tiles[0][i] = .steel
            tiles[mapHeight - 1][i] = .steel
        }
        for i in 0..<mapHeight {
            tiles[i][0] = .steel
            tiles[i][mapWidth - 1] = .steel
        }

        // Generate 2-4 main geometric structures
        let numMainStructures = 2 + randomInt(in: 0...2)
        for _ in 0..<numMainStructures {
            generateGeometricShape()
        }

        // Add symmetric patterns
        if randomDouble() < 0.7 {
            generateSymmetricPattern()
        }

        // Add corridors/walls
        let numCorridors = 1 + randomInt(in: 0...2)
        for _ in 0..<numCorridors {
            generateCorridor()
        }

        // Add water features
        let numWater = 1 + randomInt(in: 0...2)
        for _ in 0..<numWater {
            generateWaterFeature()
        }

        // Add tree patches
        let numTrees = 1 + randomInt(in: 0...2)
        for _ in 0..<numTrees {
            generateTreePatch()
        }

        // Add ice patches
        let numIce = 1 + randomInt(in: 0...1)
        for _ in 0..<numIce {
            generateIcePatch()
        }

        // Add random scattered blocks
        let numScattered = 5 + randomInt(in: 0...9)
        for _ in 0..<numScattered {
            generateScatteredBlocks()
        }

        // Clear spawn areas
        clearSpawnAreas()

        // Ensure minimum content (less than 50% empty)
        ensureMinimumContent()

        // Create base protection (LAST to ensure nothing overwrites)
        createBaseProtection()
    }

    // MARK: - Geometric Shapes

    private func generateGeometricShape() {
        let shapeType = randomInt(in: 0...7)
        let centerCol = 4 + randomInt(in: 0...(mapWidth - 9))
        let centerRow = 5 + randomInt(in: 0...(mapHeight - 15))
        let type: TileType = randomDouble() < 0.75 ? .brick : .steel

        switch shapeType {
        case 0: generateHollowRectangle(startRow: centerRow, startCol: centerCol, type: type)
        case 1: generateCross(centerRow: centerRow, centerCol: centerCol, type: type)
        case 2: generateDiamond(centerRow: centerRow, centerCol: centerCol, type: type)
        case 3: generateLShape(startRow: centerRow, startCol: centerCol, type: type)
        case 4: generateTShape(startRow: centerRow, startCol: centerCol, type: type)
        case 5: generateUShape(startRow: centerRow, startCol: centerCol, type: type)
        case 6: generateZigzag(startRow: centerRow, startCol: centerCol, type: type)
        default: generateSpiral(centerRow: centerRow, centerCol: centerCol, type: type)
        }
    }

    private func generateHollowRectangle(startRow: Int, startCol: Int, type: TileType) {
        let w = 4 + randomInt(in: 0...3)
        let h = 3 + randomInt(in: 0...2)

        for col in startCol..<(startCol + w) {
            placeTile(row: startRow, col: col, type: type)
            placeTile(row: startRow + h - 1, col: col, type: type)
        }
        for row in startRow..<(startRow + h) {
            placeTile(row: row, col: startCol, type: type)
            placeTile(row: row, col: startCol + w - 1, type: type)
        }
        // Opening
        let opening = randomInt(in: 0...3)
        switch opening {
        case 0: placeTile(row: startRow, col: startCol + w / 2, type: .empty)
        case 1: placeTile(row: startRow + h - 1, col: startCol + w / 2, type: .empty)
        case 2: placeTile(row: startRow + h / 2, col: startCol, type: .empty)
        default: placeTile(row: startRow + h / 2, col: startCol + w - 1, type: .empty)
        }
    }

    private func generateCross(centerRow: Int, centerCol: Int, type: TileType) {
        let armLength = 2 + randomInt(in: 0...2)
        for i in -armLength...armLength {
            placeTile(row: centerRow + i, col: centerCol, type: type)
            placeTile(row: centerRow, col: centerCol + i, type: type)
        }
    }

    private func generateDiamond(centerRow: Int, centerCol: Int, type: TileType) {
        let size = 2 + randomInt(in: 0...1)
        for i in 0...size {
            placeTile(row: centerRow - i, col: centerCol - (size - i), type: type)
            placeTile(row: centerRow - i, col: centerCol + (size - i), type: type)
            placeTile(row: centerRow + i, col: centerCol - (size - i), type: type)
            placeTile(row: centerRow + i, col: centerCol + (size - i), type: type)
        }
    }

    private func generateLShape(startRow: Int, startCol: Int, type: TileType) {
        let vertLen = 3 + randomInt(in: 0...2)
        let horizLen = 3 + randomInt(in: 0...2)
        let flipped = randomBool()
        let rotated = randomBool()

        for i in 0..<vertLen {
            let col = flipped ? startCol + horizLen - 1 : startCol
            placeTile(row: startRow + i, col: col, type: type)
        }
        let horizRow = rotated ? startRow : startRow + vertLen - 1
        for i in 0..<horizLen {
            placeTile(row: horizRow, col: startCol + i, type: type)
        }
    }

    private func generateTShape(startRow: Int, startCol: Int, type: TileType) {
        let topWidth = 4 + randomInt(in: 0...2)
        let stemHeight = 2 + randomInt(in: 0...2)

        for i in 0..<topWidth {
            placeTile(row: startRow, col: startCol + i, type: type)
        }
        let stemCol = startCol + topWidth / 2
        for i in 1...stemHeight {
            placeTile(row: startRow + i, col: stemCol, type: type)
        }
    }

    private func generateUShape(startRow: Int, startCol: Int, type: TileType) {
        let w = 3 + randomInt(in: 0...2)
        let h = 3 + randomInt(in: 0...1)

        for i in 0..<h {
            placeTile(row: startRow + i, col: startCol, type: type)
            placeTile(row: startRow + i, col: startCol + w - 1, type: type)
        }
        for i in 0..<w {
            placeTile(row: startRow + h - 1, col: startCol + i, type: type)
        }
    }

    private func generateZigzag(startRow: Int, startCol: Int, type: TileType) {
        let segments = 2 + randomInt(in: 0...1)
        let segLen = 2 + randomInt(in: 0...1)
        var goingRight = randomBool()
        var row = startRow
        var col = startCol

        for _ in 0..<segments {
            for i in 0..<segLen {
                placeTile(row: row, col: col + (goingRight ? i : -i), type: type)
            }
            col += goingRight ? segLen - 1 : -(segLen - 1)
            for i in 1..<segLen {
                placeTile(row: row + i, col: col, type: type)
            }
            row += segLen - 1
            goingRight = !goingRight
        }
    }

    private func generateSpiral(centerRow: Int, centerCol: Int, type: TileType) {
        let spiral = [(0, 0), (0, 1), (0, 2), (0, 3), (1, 3), (2, 3), (2, 2), (2, 1), (2, 0), (1, 0)]
        for offset in spiral {
            placeTile(row: centerRow + offset.0, col: centerCol + offset.1, type: type)
        }
    }

    // MARK: - Symmetric Patterns

    private func generateSymmetricPattern() {
        let patternType = randomInt(in: 0...2)
        let centerCol = mapWidth / 2
        let type: TileType = randomDouble() < 0.7 ? .brick : .steel

        switch patternType {
        case 0: generateSymmetricWalls(centerCol: centerCol, type: type)
        case 1: generateSymmetricPillars(centerCol: centerCol, type: type)
        default: generateSymmetricMaze(centerCol: centerCol, type: type)
        }
    }

    private func generateSymmetricWalls(centerCol: Int, type: TileType) {
        let wallRow = 8 + randomInt(in: 0...5)
        let wallLength = 3 + randomInt(in: 0...3)
        let offset = 3 + randomInt(in: 0...3)

        for i in 0..<wallLength {
            placeTile(row: wallRow + i, col: centerCol - offset, type: type)
            placeTile(row: wallRow + i, col: centerCol + offset - 1, type: type)
        }
    }

    private func generateSymmetricPillars(centerCol: Int, type: TileType) {
        let numPillars = 2 + randomInt(in: 0...1)
        let spacing = 4 + randomInt(in: 0...2)

        for p in 0..<numPillars {
            let row = 6 + p * spacing
            let offset = 4 + randomInt(in: 0...3)

            placeTile(row: row, col: centerCol - offset, type: type)
            placeTile(row: row + 1, col: centerCol - offset, type: type)
            placeTile(row: row, col: centerCol - offset + 1, type: type)
            placeTile(row: row + 1, col: centerCol - offset + 1, type: type)

            placeTile(row: row, col: centerCol + offset - 2, type: type)
            placeTile(row: row + 1, col: centerCol + offset - 2, type: type)
            placeTile(row: row, col: centerCol + offset - 1, type: type)
            placeTile(row: row + 1, col: centerCol + offset - 1, type: type)
        }
    }

    private func generateSymmetricMaze(centerCol: Int, type: TileType) {
        let pattern = [(6, -6), (6, -5), (7, -5), (10, -8), (10, -7), (11, -7), (11, -6), (14, -5), (14, -4), (14, -3), (15, -3)]

        for pos in pattern {
            placeTile(row: pos.0, col: centerCol + pos.1, type: type)
            placeTile(row: pos.0, col: centerCol - pos.1 - 1, type: type)
        }
    }

    // MARK: - Corridors

    private func generateCorridor() {
        let horizontal = randomBool()
        let type: TileType = randomDouble() < 0.6 ? .brick : .steel

        if horizontal {
            let row = 5 + randomInt(in: 0...(mapHeight - 13))
            let startCol = 2 + randomInt(in: 0...4)
            let length = 4 + randomInt(in: 0...7)
            for i in 0..<length {
                placeTile(row: row, col: startCol + i, type: type)
            }
            if length > 4 {
                placeTile(row: row, col: startCol + length / 2, type: .empty)
            }
        } else {
            let col = 3 + randomInt(in: 0...(mapWidth - 7))
            let startRow = 4 + randomInt(in: 0...4)
            let length = 3 + randomInt(in: 0...5)
            for i in 0..<length {
                placeTile(row: startRow + i, col: col, type: type)
            }
            if length > 3 {
                placeTile(row: startRow + length / 2, col: col, type: .empty)
            }
        }
    }

    // MARK: - Water Features

    private func generateWaterFeature() {
        let featureType = randomInt(in: 0...2)
        switch featureType {
        case 0: generateWaterPool()
        case 1: generateWaterRiver()
        default: generateWaterLake()
        }
    }

    private func generateWaterPool() {
        let poolRow = 6 + randomInt(in: 0...(mapHeight - 15))
        let poolCol = 3 + randomInt(in: 0...(mapWidth - 9))
        let poolWidth = 2 + randomInt(in: 0...1)
        let poolHeight = 2 + randomInt(in: 0...1)

        for r in 0..<poolHeight {
            for c in 0..<poolWidth {
                placeTile(row: poolRow + r, col: poolCol + c, type: .water)
            }
        }
    }

    private func generateWaterRiver() {
        let horizontal = randomBool()
        if horizontal {
            let row = 8 + randomInt(in: 0...(mapHeight - 17))
            for c in 2...(mapWidth - 4) {
                let wobble = randomInt(in: -1...1)
                let actualRow = max(1, min(mapHeight - 2, row + wobble))
                placeTile(row: actualRow, col: c, type: .water)
            }
        } else {
            let col = 6 + randomInt(in: 0...(mapWidth - 13))
            for r in 2...(mapHeight - 9) {
                let wobble = randomInt(in: -1...1)
                let actualCol = max(1, min(mapWidth - 2, col + wobble))
                placeTile(row: r, col: actualCol, type: .water)
            }
        }
    }

    private func generateWaterLake() {
        let lakeRow = 8 + randomInt(in: 0...(mapHeight - 19))
        let lakeCol = 5 + randomInt(in: 0...(mapWidth - 13))
        let lakeSize = 3 + randomInt(in: 0...1)

        for r in -lakeSize...lakeSize {
            for c in -lakeSize...lakeSize {
                if r * r + c * c <= lakeSize * lakeSize {
                    placeTile(row: lakeRow + r, col: lakeCol + c, type: .water)
                }
            }
        }
    }

    // MARK: - Tree Patches

    private func generateTreePatch() {
        let patchType = randomInt(in: 0...2)
        switch patchType {
        case 0: generateTreeCluster()
        case 1: generateTreeLine()
        default: generateTreeForest()
        }
    }

    private func generateTreeCluster() {
        let clusterRow = 4 + randomInt(in: 0...(mapHeight - 11))
        let clusterCol = 3 + randomInt(in: 0...(mapWidth - 9))
        let numTrees = 3 + randomInt(in: 0...3)

        for _ in 0..<numTrees {
            let offsetRow = randomInt(in: -1...1)
            let offsetCol = randomInt(in: -1...1)
            placeTile(row: clusterRow + offsetRow, col: clusterCol + offsetCol, type: .forest)
        }
    }

    private func generateTreeLine() {
        let horizontal = randomBool()
        if horizontal {
            let row = 3 + randomInt(in: 0...(mapHeight - 9))
            let startCol = 2 + randomInt(in: 0...4)
            let length = 3 + randomInt(in: 0...4)
            for i in 0..<length {
                placeTile(row: row, col: startCol + i, type: .forest)
            }
        } else {
            let col = 2 + randomInt(in: 0...(mapWidth - 7))
            let startRow = 3 + randomInt(in: 0...4)
            let length = 3 + randomInt(in: 0...4)
            for i in 0..<length {
                placeTile(row: startRow + i, col: col, type: .forest)
            }
        }
    }

    private func generateTreeForest() {
        let forestRow = 5 + randomInt(in: 0...(mapHeight - 13))
        let forestCol = 4 + randomInt(in: 0...(mapWidth - 11))
        let forestWidth = 3 + randomInt(in: 0...2)
        let forestHeight = 2 + randomInt(in: 0...1)

        for r in 0..<forestHeight {
            for c in 0..<forestWidth {
                if randomDouble() < 0.7 {
                    placeTile(row: forestRow + r, col: forestCol + c, type: .forest)
                }
            }
        }
    }

    // MARK: - Ice Patches

    private func generateIcePatch() {
        let patchType = randomInt(in: 0...1)
        if patchType == 0 {
            generateIceRink()
        } else {
            generateIcePath()
        }
    }

    private func generateIceRink() {
        let rinkRow = 6 + randomInt(in: 0...(mapHeight - 15))
        let rinkCol = 4 + randomInt(in: 0...(mapWidth - 11))
        let rinkWidth = 3 + randomInt(in: 0...2)
        let rinkHeight = 2 + randomInt(in: 0...1)

        for r in 0..<rinkHeight {
            for c in 0..<rinkWidth {
                placeTile(row: rinkRow + r, col: rinkCol + c, type: .ice)
            }
        }
    }

    private func generateIcePath() {
        let horizontal = randomBool()
        if horizontal {
            let row = 8 + randomInt(in: 0...(mapHeight - 17))
            let startCol = 3 + randomInt(in: 0...4)
            let length = 4 + randomInt(in: 0...5)
            for i in 0..<length {
                placeTile(row: row, col: startCol + i, type: .ice)
            }
        } else {
            let col = 5 + randomInt(in: 0...(mapWidth - 11))
            let startRow = 4 + randomInt(in: 0...4)
            let length = 3 + randomInt(in: 0...4)
            for i in 0..<length {
                placeTile(row: startRow + i, col: col, type: .ice)
            }
        }
    }

    // MARK: - Scattered Blocks

    private func generateScatteredBlocks() {
        let row = 2 + randomInt(in: 0...(mapHeight - 7))
        let col = 2 + randomInt(in: 0...(mapWidth - 5))

        let typeRoll = randomDouble()
        let type: TileType
        if typeRoll < 0.5 {
            type = .brick
        } else if typeRoll < 0.7 {
            type = .steel
        } else if typeRoll < 0.85 {
            type = .forest
        } else {
            type = .water
        }

        let size = 1 + randomInt(in: 0...1)
        for r in 0..<size {
            for c in 0..<size {
                placeTile(row: row + r, col: col + c, type: type)
            }
        }
    }

    // MARK: - Helper Methods

    private func placeTile(row: Int, col: Int, type: TileType) {
        guard row > 0 && row < mapHeight - 1 && col > 0 && col < mapWidth - 1 else { return }
        // Don't overwrite base area (rows 23-24, cols 12-14)
        if row >= 23 && row <= 24 && col >= 12 && col <= 14 { return }
        tiles[row][col] = type
    }

    private func ensureMinimumContent() {
        var attempts = 0
        while calculateEmptyPercentage() > 0.50 && attempts < 50 {
            let contentType = randomInt(in: 0...4)
            switch contentType {
            case 0: generateGeometricShape()
            case 1: generateCorridor()
            case 2: generateScatteredBlocks()
            case 3: generateTreePatch()
            default:
                for _ in 0..<3 { generateScatteredBlocks() }
            }
            attempts += 1
        }
        if attempts > 0 {
            clearSpawnAreas()
        }
    }

    private func calculateEmptyPercentage() -> Double {
        var totalPlayable = 0
        var emptyCount = 0

        for row in 1..<(mapHeight - 1) {
            for col in 1..<(mapWidth - 1) {
                totalPlayable += 1
                if tiles[row][col] == .empty {
                    emptyCount += 1
                }
            }
        }
        return Double(emptyCount) / Double(totalPlayable)
    }

    private func clearSpawnAreas() {
        // Enemy spawn 1 (left)
        for row in 1...2 {
            for col in 1...4 {
                tiles[row][col] = .empty
            }
        }
        // Enemy spawn 2 (center) - wider and taller for BOSS
        // Boss spawns at row ~4-5, needs clearance for 112x112 size (covers ~4 tiles)
        for row in 1...8 {
            for col in 9...17 {
                tiles[row][col] = .empty
            }
        }
        // Enemy spawn 3 (right)
        for row in 1...2 {
            for col in (mapWidth - 5)...(mapWidth - 2) {
                tiles[row][col] = .empty
            }
        }
        // Player spawn (bottom)
        for row in 23...(mapHeight - 2) {
            for col in 7...9 {
                tiles[row][col] = .empty
            }
        }
    }

    private func createBaseProtection() {
        // Base (eagle) is at center bottom, roughly at col 13
        // Create tight U-shaped brick protection around the eagle
        // Classic Battle City layout (3 wide):
        //   [B][B][B]    <- top row
        //   [B]   [B]    <- sides with eagle space
        //   [B][E][B]    <- bottom with eagle in center

        // Top of protection (row 23)
        tiles[23][12] = .brick
        tiles[23][13] = .brick
        tiles[23][14] = .brick

        // Left side (col 12)
        tiles[24][12] = .brick

        // Right side (col 14)
        tiles[24][14] = .brick

        // Clear the eagle space (col 13, row 24)
        tiles[24][13] = .empty
    }

    // MARK: - Rendering

    private func renderMap() {
        removeAllChildren()

        for row in 0..<mapHeight {
            for col in 0..<mapWidth {
                let tile = tiles[row][col]
                let position = CGPoint(
                    x: CGFloat(col) * tileSize + tileSize / 2,
                    y: CGFloat(mapHeight - 1 - row) * tileSize + tileSize / 2
                )
                renderTile(tile: tile, at: position, row: row, col: col)
            }
        }
    }

    private func renderTile(tile: TileType, at position: CGPoint, row: Int, col: Int) {
        guard tile != .empty else { return }
        guard let texture = Self.textureCache[tile] else { return }

        let sprite = SKSpriteNode(texture: texture)
        sprite.position = position
        if tile == .forest {
            sprite.zPosition = 15 // Above tanks
        }
        addChild(sprite)
        tileNodes[row][col] = sprite
    }

    // MARK: - Texture Generation (called once)

    private static func generateTexturesIfNeeded(tileSize: CGFloat) {
        guard textureCache.isEmpty else { return }

        // Generate all tile textures once
        textureCache[.brick] = generateBrickTexture(tileSize: tileSize)
        textureCache[.steel] = generateSteelTexture(tileSize: tileSize)
        textureCache[.water] = generateWaterTexture(tileSize: tileSize)
        textureCache[.forest] = generateForestTexture(tileSize: tileSize)
        textureCache[.ice] = generateIceTexture(tileSize: tileSize)
        print("Generated tile textures for \(textureCache.count) tile types")
    }

    private static func renderShapeToTexture(_ node: SKNode, size: CGSize) -> SKTexture {
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        let scene = SKScene(size: size)
        scene.backgroundColor = .clear
        node.position = CGPoint(x: size.width / 2, y: size.height / 2)
        scene.addChild(node)
        return view.texture(from: scene)!
    }

    private static func generateBrickTexture(tileSize: CGFloat) -> SKTexture {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
        node.fillColor = SKColor(red: 0.6, green: 0.3, blue: 0.1, alpha: 1.0)
        node.strokeColor = SKColor(red: 0.4, green: 0.2, blue: 0.05, alpha: 1.0)
        node.lineWidth = 1

        let pattern = SKShapeNode()
        let path = CGMutablePath()
        let half = tileSize / 2
        path.move(to: CGPoint(x: -half, y: 0))
        path.addLine(to: CGPoint(x: half, y: 0))
        path.move(to: CGPoint(x: 0, y: -half))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.move(to: CGPoint(x: -half / 2, y: 0))
        path.addLine(to: CGPoint(x: -half / 2, y: half))
        path.move(to: CGPoint(x: half / 2, y: 0))
        path.addLine(to: CGPoint(x: half / 2, y: half))
        pattern.path = path
        pattern.strokeColor = SKColor(red: 0.4, green: 0.2, blue: 0.05, alpha: 1.0)
        pattern.lineWidth = 1
        node.addChild(pattern)

        return renderShapeToTexture(node, size: CGSize(width: tileSize, height: tileSize))
    }

    private static func generateSteelTexture(tileSize: CGFloat) -> SKTexture {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
        node.fillColor = SKColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1.0)
        node.strokeColor = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        node.lineWidth = 2

        let shine = SKShapeNode(rectOf: CGSize(width: tileSize - 8, height: tileSize - 8))
        shine.fillColor = SKColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.3)
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -2, y: 2)
        node.addChild(shine)

        return renderShapeToTexture(node, size: CGSize(width: tileSize, height: tileSize))
    }

    private static func generateWaterTexture(tileSize: CGFloat) -> SKTexture {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
        node.fillColor = SKColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 0.8)
        node.strokeColor = SKColor(red: 0.1, green: 0.3, blue: 0.6, alpha: 1.0)
        node.lineWidth = 1

        let wave = SKShapeNode()
        let path = CGMutablePath()
        let half = tileSize / 2
        path.move(to: CGPoint(x: -half, y: 4))
        path.addQuadCurve(to: CGPoint(x: 0, y: 4), control: CGPoint(x: -half / 2, y: 8))
        path.addQuadCurve(to: CGPoint(x: half, y: 4), control: CGPoint(x: half / 2, y: 0))
        wave.path = path
        wave.strokeColor = SKColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 0.5)
        wave.lineWidth = 2
        node.addChild(wave)

        return renderShapeToTexture(node, size: CGSize(width: tileSize, height: tileSize))
    }

    private static func generateForestTexture(tileSize: CGFloat) -> SKTexture {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
        node.fillColor = SKColor(red: 0.1, green: 0.5, blue: 0.1, alpha: 0.7)
        node.strokeColor = .clear

        for i in 0..<2 {
            for j in 0..<2 {
                let tree = SKShapeNode(circleOfRadius: 6)
                tree.fillColor = SKColor(red: 0.0, green: 0.4, blue: 0.0, alpha: 0.8)
                tree.strokeColor = SKColor(red: 0.0, green: 0.3, blue: 0.0, alpha: 1.0)
                tree.position = CGPoint(x: CGFloat(i) * 12 - 6, y: CGFloat(j) * 12 - 6)
                node.addChild(tree)
            }
        }

        return renderShapeToTexture(node, size: CGSize(width: tileSize, height: tileSize))
    }

    private static func generateIceTexture(tileSize: CGFloat) -> SKTexture {
        let node = SKShapeNode(rectOf: CGSize(width: tileSize, height: tileSize))
        node.fillColor = SKColor(red: 0.8, green: 0.9, blue: 1.0, alpha: 0.9)
        node.strokeColor = SKColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 1.0)
        node.lineWidth = 1

        let shine = SKShapeNode(rectOf: CGSize(width: 8, height: 4))
        shine.fillColor = .white
        shine.strokeColor = .clear
        shine.position = CGPoint(x: -4, y: 6)
        shine.alpha = 0.6
        node.addChild(shine)

        return renderShapeToTexture(node, size: CGSize(width: tileSize, height: tileSize))
    }

    // MARK: - Collision Detection

    func checkTankCollision(position: CGPoint, size: CGFloat, canSwim: Bool = false) -> Bool {
        let halfSize = size / 2

        // Check map boundaries first
        if position.x - halfSize < 0 || position.x + halfSize > CGFloat(mapWidth) * tileSize ||
           position.y - halfSize < 0 || position.y + halfSize > CGFloat(mapHeight) * tileSize {
            return true
        }

        // Convert to tile coordinates (Y is flipped)
        let minCol = max(0, Int((position.x - halfSize) / tileSize))
        let maxCol = min(mapWidth - 1, Int((position.x + halfSize) / tileSize))
        let minRow = max(0, mapHeight - 1 - Int((position.y + halfSize) / tileSize))
        let maxRow = min(mapHeight - 1, mapHeight - 1 - Int((position.y - halfSize) / tileSize))

        guard minCol <= maxCol && minRow <= maxRow else { return true }

        for row in minRow...maxRow {
            for col in minCol...maxCol {
                let tile = tiles[row][col]
                if tile == .brick || tile == .steel {
                    return true
                }
                if tile == .water && !canSwim {
                    return true
                }
            }
        }

        return false
    }

    func checkBulletCollision(position: CGPoint, power: Int) -> (hit: Bool, tileDestroyed: Bool) {
        // Convert to tile coordinates
        let col = Int(position.x / tileSize)
        let row = mapHeight - 1 - Int(position.y / tileSize)

        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else {
            return (true, false)
        }

        let tile = tiles[row][col]

        switch tile {
        case .brick:
            tiles[row][col] = .empty
            updateTileVisual(row: row, col: col)
            return (true, true)
        case .steel:
            if power >= 2 {
                tiles[row][col] = .empty
                updateTileVisual(row: row, col: col)
                return (true, true)
            }
            return (true, false)
        case .water, .ice, .forest:
            return (false, false) // Bullets pass through
        case .empty:
            return (false, false)
        }
    }

    private func updateTileVisual(row: Int, col: Int) {
        // Remove existing tile using cached reference
        if let node = tileNodes[row][col] {
            node.removeFromParent()
            tileNodes[row][col] = nil
        }
    }

    // Check if a tile is ice (for tank sliding)
    func isIceTile(at position: CGPoint) -> Bool {
        let col = Int(position.x / tileSize)
        let row = mapHeight - 1 - Int(position.y / tileSize)
        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else { return false }
        return tiles[row][col] == .ice
    }

    // Get tile type at a position (for collision detection)
    func getTile(at position: CGPoint) -> TileType {
        let col = Int(position.x / tileSize)
        let row = mapHeight - 1 - Int(position.y / tileSize)
        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else { return .empty }
        return tiles[row][col]
    }

    // MARK: - Base Protection

    /// Set base protection tiles to steel or brick
    func setBaseProtection(steel: Bool) {
        let type: TileType = steel ? .steel : .brick

        // Base protection positions (same as createBaseProtection)
        // Top of protection (row 23)
        setTileAndUpdate(row: 23, col: 12, type: type)
        setTileAndUpdate(row: 23, col: 13, type: type)
        setTileAndUpdate(row: 23, col: 14, type: type)

        // Left side (col 12)
        setTileAndUpdate(row: 24, col: 12, type: type)

        // Right side (col 14)
        setTileAndUpdate(row: 24, col: 14, type: type)
    }

    /// Clear base protection entirely (remove all protection tiles)
    func clearBaseProtection() {
        setTileAndUpdate(row: 23, col: 12, type: .empty)
        setTileAndUpdate(row: 23, col: 13, type: .empty)
        setTileAndUpdate(row: 23, col: 14, type: .empty)
        setTileAndUpdate(row: 24, col: 12, type: .empty)
        setTileAndUpdate(row: 24, col: 14, type: .empty)
    }

    /// Set a tile and update its visual representation
    private func setTileAndUpdate(row: Int, col: Int, type: TileType) {
        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else { return }
        tiles[row][col] = type

        // Remove existing node
        if let node = tileNodes[row][col] {
            node.removeFromParent()
            tileNodes[row][col] = nil
        }

        // Add new node if not empty
        if type != .empty {
            let position = CGPoint(
                x: CGFloat(col) * tileSize + tileSize / 2,
                y: CGFloat(mapHeight - 1 - row) * tileSize + tileSize / 2
            )
            renderTile(tile: type, at: position, row: row, col: col)
        }
    }

    // MARK: - Forest Destruction

    /// Destroy forest tile at position (for SAW power-up)
    func destroyForest(at position: CGPoint) -> Bool {
        let col = Int(position.x / tileSize)
        let row = mapHeight - 1 - Int(position.y / tileSize)
        guard row >= 0 && row < mapHeight && col >= 0 && col < mapWidth else { return false }

        if tiles[row][col] == .forest {
            setTileAndUpdate(row: row, col: col, type: .empty)
            return true
        }
        return false
    }
}
