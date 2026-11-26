import SpriteKit

/// Cheat options (opened from the menu after the Konami code): pages of rows with < value > controls.
/// Keyboard: ↑↓ pick a row, ←→ change it, Tab / 1-5 switch pages, Esc goes back.
class CheatScene: SKScene {

    private enum Page: Int, CaseIterable {
        case player, powerUps, enemies, level, crazy

        var title: String {
            switch self {
            case .player: return "PLAYER"
            case .powerUps: return "POWER-UPS"
            case .enemies: return "ENEMIES"
            case .level: return "LEVEL"
            case .crazy: return "CRAZY"
            }
        }
    }

    private struct Row {
        let title: String
        let value: (CheatSettings.Config) -> String
        let change: (inout CheatSettings.Config, Int) -> Void
    }

    private var page: Page = .player
    private var selectedRow = 0
    private var pageNode = SKNode()
    private var statusLabel: SKLabelNode!

    private static let accent = SKColor.magenta
    private static let rowFill = SKColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupUI()
    }

    // MARK: - Rows

    private static func factorText(_ value: Double) -> String {
        String(format: "%gx", value)
    }

    /// Step through a list of values (clamped at both ends)
    private static func stepped<T: Comparable>(_ current: T, in steps: [T], by delta: Int) -> T {
        let index = steps.firstIndex { $0 >= current } ?? steps.count - 1
        return steps[min(max(index + delta, 0), steps.count - 1)]
    }

    private func listRow<T: Comparable>(_ title: String, _ path: WritableKeyPath<CheatSettings.Config, T>,
                                        _ steps: [T], format: @escaping (T) -> String) -> Row {
        Row(title: title,
            value: { format($0[keyPath: path]) },
            change: { config, delta in config[keyPath: path] = CheatScene.stepped(config[keyPath: path], in: steps, by: delta) })
    }

    private func boolRow(_ title: String, _ path: WritableKeyPath<CheatSettings.Config, Bool>,
                         on: String = "ON", off: String = "OFF") -> Row {
        Row(title: title,
            value: { $0[keyPath: path] ? on : off },
            change: { config, _ in config[keyPath: path].toggle() })
    }

    /// AUTO / ALWAYS / ONCE / NEVER: force a level kind on every level or switch it off
    private func forceRow(_ title: String, _ path: WritableKeyPath<CheatSettings.Config, CheatSettings.Force?>) -> Row {
        Row(title: title,
            value: { config in
                switch config[keyPath: path] {
                case .always: return "ALWAYS"
                case .once: return "ONCE"
                case .never: return "NEVER"
                case nil: return "AUTO"
                }
            },
            change: { config, delta in config[keyPath: path] = CheatSettings.Force.cycle(config[keyPath: path], by: delta) })
    }

    private func rows(for page: Page) -> [Row] {
        switch page {
        case .player:
            return [
                listRow("SPEED", \.playerSpeed, CheatSettings.factorSteps, format: CheatScene.factorText),
                listRow("FIRE RATE", \.playerFireRate, CheatSettings.factorSteps, format: CheatScene.factorText),
                listRow("LIVES", \.playerLives, CheatSettings.livesSteps) { "\($0)" },
                listRow("START LEVEL", \.startLevel, CheatSettings.levelSteps) { "\($0)" }
            ]
        case .powerUps:
            return [
                listRow("⭐ STAR", \.stars, Array(0...3)) { "\($0)" },
                listRow("💥 MACHINEGUN", \.machineguns, Array(0...3)) { "\($0)" },
                listRow("🚗 CAR", \.cars, Array(0...5)) { "\($0)" },
                boolRow("🔫 GUN", \.gun),
                boolRow("🚢 SHIP", \.ship),
                boolRow("🪚 SAW", \.saw),
                boolRow("🛡️ SHIELD", \.shield),
                boolRow("🔦 LASER", \.laser),
                boolRow("🔮 MAGIC", \.magic),
                boolRow("⛏️ STEEL BASE", \.steelBase)
            ]
        case .enemies:
            return [
                listRow("SPEED", \.enemySpeed, CheatSettings.factorSteps, format: CheatScene.factorText),
                listRow("FIRE RATE", \.enemyFireRate, CheatSettings.factorSteps, format: CheatScene.factorText),
                boolRow("TAKE POWER-UPS", \.enemiesTakePowerUps, on: "YES", off: "NO"),
                listRow("PER LEVEL", \.enemyCount, CheatSettings.enemyCountSteps) { $0 == 0 ? "AUTO" : "\($0)" },
                listRow("ON SCREEN", \.enemiesOnScreen, CheatSettings.onScreenSteps) { $0 == 0 ? "AUTO" : "\($0)" },
                listRow("EXTRA ARMOR", \.enemyArmor, Array(0...5)) { $0 == 0 ? "0" : "+\($0)" },
                boolRow("UFO", \.ufoEnabled)
            ]
        case .level:
            return [
                forceRow("👽 ALIEN", \.alienLevel),
                forceRow("🏺 GZHEL", \.gzhelLevel),
                forceRow("👑 BOSS", \.bossLevel),
                forceRow("✨ BONUS STAGE", \.bonusLevel),
                forceRow("🤝 FRIEND", \.friendLevel),
                forceRow("🐣 EASY", \.easyLevel)
            ]
        case .crazy:
            return [boolRow("🤪 CRAZY MODE", \.crazyMode)]
        }
    }

    // MARK: - Layout

    private var rowHeight: CGFloat { min(46, size.height * 0.48 / 5) }
    private var columnWidth: CGFloat { min(size.width * 0.45, 400) }

    private func setupUI() {
        let title = SKLabelNode(text: "CHEATS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = min(40, size.height * 0.085)
        title.fontColor = CheatScene.accent
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.87)
        addChild(title)

        statusLabel = SKLabelNode(fontNamed: "Helvetica")
        statusLabel.fontSize = min(14, size.height * 0.033)
        statusLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.695)
        addChild(statusLabel)

        addChild(pageNode)

        let back = createButton(text: "BACK", width: 160, position: CGPoint(x: size.width / 2 - 95, y: size.height * 0.08))
        back.name = "backButton"
        addChild(back)
        let reset = createButton(text: "RESET ALL", width: 160, position: CGPoint(x: size.width / 2 + 95, y: size.height * 0.08))
        reset.name = "resetButton"
        addChild(reset)

        rebuild()
    }

    /// Redraw tabs, rows and the status line (cheap enough to do on every change)
    private func rebuild() {
        pageNode.removeAllChildren()
        let config = CheatSettings.shared.config

        // Tabs
        let tabWidth = min(150, (size.width - 40) / CGFloat(Page.allCases.count) - 8)
        let tabHeight = min(36, size.height * 0.08)
        for p in Page.allCases {
            let x = size.width / 2 + (CGFloat(p.rawValue) - CGFloat(Page.allCases.count - 1) / 2) * (tabWidth + 8)
            let tab = SKShapeNode(rectOf: CGSize(width: tabWidth, height: tabHeight), cornerRadius: 6)
            tab.position = CGPoint(x: x, y: size.height * 0.775)
            tab.fillColor = p == page ? SKColor(red: 0.35, green: 0.1, blue: 0.35, alpha: 1) : CheatScene.rowFill
            tab.strokeColor = p == page ? CheatScene.accent : .gray
            tab.lineWidth = 2
            tab.name = "tab_\(p.rawValue)"
            let label = SKLabelNode(text: p.title)
            label.fontName = "Helvetica-Bold"
            label.fontSize = min(17, tabHeight * 0.5)
            label.fontColor = p == page ? .white : .lightGray
            label.verticalAlignmentMode = .center
            tab.addChild(label)
            pageNode.addChild(tab)
        }

        // Rows: two columns of up to 5 (the crazy page has one row in the middle)
        let pageRows = rows(for: page)
        let perColumn = page == .crazy ? 1 : (pageRows.count + 1) / 2
        let topY = size.height * 0.62
        for (index, row) in pageRows.enumerated() {
            let column = index / perColumn
            let x = page == .crazy ? size.width / 2 : (column == 0 ? size.width * 0.27 : size.width * 0.73)
            let y = topY - CGFloat(index % perColumn) * rowHeight
            pageNode.addChild(makeRow(row, index: index, config: config, at: CGPoint(x: x, y: y)))
        }

        var lines: [String] = []
        if page == .level {
            lines = [
                "AUTO: as usual · ALWAYS: every level · ONCE: the first level only · NEVER: off.",
                "Alien + boss = red alien with eyes · bonus + boss = the rat stage.",
                "The bonus stage wins over Gzhel."
            ]
        } else if page == .crazy {
            lines = [
                "Every level: 10 to 1000 enemies of any kind, bosses and aliens too,",
                "several UFOs and a crowd of friends with 1 to 5 hits each.",
                "Every game start: 3 to 99 lives and random power-ups.",
                "Speeds, fire rates, armor, enemy power-ups and UFO switch still apply."
            ]
        }
        if !lines.isEmpty {
            let linesTop = page == .crazy ? topY - rowHeight * 1.3 : topY - rowHeight * CGFloat(perColumn) - rowHeight * 0.1
            for (i, line) in lines.enumerated() {
                let label = SKLabelNode(text: line)
                label.fontName = "Helvetica"
                label.fontSize = min(16, size.height * 0.038)
                label.fontColor = .lightGray
                label.position = CGPoint(x: size.width / 2, y: linesTop - CGFloat(i) * label.fontSize * 1.5)
                pageNode.addChild(label)
            }
        }

        // Status: do the cheats do anything right now?
        if CheatSettings.shared.isActive {
            statusLabel.text = config.crazyMode ? "CRAZY MODE IS ON · high scores are not saved"
                                                : "Cheats are on · high scores are not saved"
            statusLabel.fontColor = .yellow
        } else {
            statusLabel.text = "Everything is normal: change something to cheat"
            statusLabel.fontColor = .gray
        }
    }

    private func makeRow(_ row: Row, index: Int, config: CheatSettings.Config, at position: CGPoint) -> SKNode {
        let width = columnWidth
        let height = rowHeight - 6
        let container = SKNode()
        container.position = position
        container.name = "row_\(index)"

        let isSelected = index == selectedRow
        let isChanged = row.value(config) != row.value(CheatSettings.Config())
        let bg = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 6)
        bg.fillColor = CheatScene.rowFill
        bg.strokeColor = isSelected ? CheatScene.accent : SKColor(white: 0.35, alpha: 1)
        bg.lineWidth = isSelected ? 2.5 : 1
        bg.name = "row_\(index)"
        container.addChild(bg)

        let fontSize = min(18, height * 0.45)
        let title = SKLabelNode(text: row.title)
        title.fontName = "Helvetica-Bold"
        title.fontSize = fontSize
        title.fontColor = .white
        title.horizontalAlignmentMode = .left
        title.verticalAlignmentMode = .center
        title.position = CGPoint(x: -width / 2 + 12, y: 0)
        container.addChild(title)

        // < value >
        let arrowSize = CGSize(width: height * 1.1, height: height - 8)
        for (name, text, x) in [("dec_\(index)", "<", width / 2 - 125), ("inc_\(index)", ">", width / 2 - arrowSize.width / 2 - 6)] {
            let button = SKShapeNode(rectOf: arrowSize, cornerRadius: 4)
            button.position = CGPoint(x: x, y: 0)
            button.fillColor = SKColor(white: 0.28, alpha: 1)
            button.strokeColor = .gray
            button.name = name
            let label = SKLabelNode(text: text)
            label.fontName = "Helvetica-Bold"
            label.fontSize = fontSize
            label.fontColor = .white
            label.verticalAlignmentMode = .center
            label.name = name
            button.addChild(label)
            container.addChild(button)
        }

        let value = SKLabelNode(text: row.value(config))
        value.fontName = "Helvetica-Bold"
        value.fontSize = fontSize
        value.fontColor = isChanged ? .yellow : .lightGray
        value.verticalAlignmentMode = .center
        value.position = CGPoint(x: (width / 2 - 125 + width / 2 - arrowSize.width / 2 - 6) / 2, y: 0)
        container.addChild(value)

        return container
    }

    private func createButton(text: String, width: CGFloat, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position
        let height = min(46, size.height * 0.1)
        let background = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = min(22, height * 0.5)
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)
        return container
    }

    // MARK: - Actions

    private func change(row index: Int, by delta: Int) {
        let pageRows = rows(for: page)
        guard pageRows.indices.contains(index) else { return }
        var config = CheatSettings.shared.config
        pageRows[index].change(&config, delta)
        CheatSettings.shared.config = config
        selectedRow = index
        SoundManager.shared.playShoot()
        rebuild()
    }

    private func show(_ newPage: Page) {
        page = newPage
        selectedRow = 0
        rebuild()
    }

    private func goBack() {
        let menuScene = MenuScene(size: size)
        menuScene.scaleMode = scaleMode
        view?.presentScene(menuScene, transition: .fade(withDuration: 0.3))
    }

    // MARK: - Input

    #if os(iOS) || os(tvOS)
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        // Most specific node first: an arrow button wins over its row
        for node in nodes(at: touch.location(in: self)) {
            guard let name = node.name ?? node.parent?.name else { continue }
            if name == "backButton" || node.parent?.name == "backButton" { goBack(); return }
            if name == "resetButton" || node.parent?.name == "resetButton" {
                CheatSettings.shared.reset()
                SoundManager.shared.playPowerUp()
                rebuild()
                return
            }
            if name.hasPrefix("dec_"), let i = Int(name.dropFirst(4)) { change(row: i, by: -1); return }
            if name.hasPrefix("inc_"), let i = Int(name.dropFirst(4)) { change(row: i, by: 1); return }
            if name.hasPrefix("tab_"), let i = Int(name.dropFirst(4)), let p = Page(rawValue: i) { show(p); return }
        }
        // Tap on a row (not on its arrows): next value
        for node in nodes(at: touch.location(in: self)) {
            if let name = node.name, name.hasPrefix("row_"), let i = Int(name.dropFirst(4)) {
                change(row: i, by: 1)
                return
            }
        }
    }

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let count = rows(for: page).count
        for press in presses {
            guard let key = press.key?.keyCode else { continue }
            switch key {
            case .keyboardEscape, .keyboardDeleteOrBackspace:
                goBack()
                return
            case .keyboardUpArrow, .keyboardW:
                selectedRow = (selectedRow - 1 + count) % count
                rebuild()
            case .keyboardDownArrow, .keyboardS:
                selectedRow = (selectedRow + 1) % count
                rebuild()
            case .keyboardLeftArrow, .keyboardA:
                change(row: selectedRow, by: -1)
            case .keyboardRightArrow, .keyboardD, .keyboardReturnOrEnter, .keyboardSpacebar:
                change(row: selectedRow, by: 1)
            case .keyboardTab:
                show(Page(rawValue: (page.rawValue + 1) % Page.allCases.count) ?? .player)
            case .keyboard1, .keyboard2, .keyboard3, .keyboard4, .keyboard5:
                let index = key.rawValue - UIKeyboardHIDUsage.keyboard1.rawValue
                if let p = Page(rawValue: index) { show(p) }
            default:
                break
            }
        }
    }
    #endif
}
