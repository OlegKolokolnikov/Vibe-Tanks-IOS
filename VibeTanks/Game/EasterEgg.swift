import SpriteKit

/// Easter egg that spawns when UFO is destroyed
/// When collected by player: all enemies become POWER tanks, player gets 3 lives
/// When collected by enemy: all enemies become HEAVY tanks
class EasterEgg: SKNode {

    private static let size: CGFloat = 32

    private var lifetime: Int
    private var collected: Bool = false
    private let eggNode: SKNode
    private var colorOffset: Int = 0

    var isExpired: Bool {
        return lifetime <= 0 || collected
    }

    var isCollected: Bool {
        return collected
    }

    init(x: CGFloat, y: CGFloat) {
        self.lifetime = GameConstants.easterEggLifetime
        self.eggNode = SKNode()

        super.init()

        self.position = CGPoint(x: x, y: y)
        self.zPosition = 50

        addChild(eggNode)
        drawEgg()

        // Pulsing glow effect
        let glowNode = SKShapeNode(ellipseOf: CGSize(width: EasterEgg.size + 8, height: EasterEgg.size + 8))
        glowNode.fillColor = SKColor(red: 1.0, green: 1.0, blue: 0.4, alpha: 0.3)
        glowNode.strokeColor = .clear
        glowNode.zPosition = -1
        glowNode.name = "glow"
        addChild(glowNode)

        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.6, duration: 0.3),
            SKAction.fadeAlpha(to: 0.3, duration: 0.3)
        ])
        glowNode.run(SKAction.repeatForever(pulse))

        // Float animation
        let floatUp = SKAction.moveBy(x: 0, y: 4, duration: 0.5)
        let floatDown = SKAction.moveBy(x: 0, y: -4, duration: 0.5)
        eggNode.run(SKAction.repeatForever(SKAction.sequence([floatUp, floatDown])))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func drawEgg() {
        let eggWidth = EasterEgg.size * 0.7
        let eggHeight = EasterEgg.size * 0.9

        // Egg base shape (white/cream background)
        let eggShape = SKShapeNode(ellipseOf: CGSize(width: eggWidth, height: eggHeight))
        eggShape.fillColor = SKColor(red: 1.0, green: 0.98, blue: 0.86, alpha: 1.0) // Cream color
        eggShape.strokeColor = SKColor(red: 0.78, green: 0.71, blue: 0.39, alpha: 1.0) // Gold outline
        eggShape.lineWidth = 2
        eggNode.addChild(eggShape)

        // Rainbow stripes (as a mask/overlay)
        let rainbowColors: [SKColor] = [
            .red,
            .orange,
            .yellow,
            .green,
            .blue,
            .purple
        ]

        let stripeHeight = eggHeight / 6
        let stripeContainer = SKNode()
        stripeContainer.name = "stripes"

        for i in 0..<6 {
            let stripe = SKShapeNode(rectOf: CGSize(width: eggWidth - 4, height: stripeHeight + 1))
            stripe.fillColor = rainbowColors[i]
            stripe.strokeColor = .clear
            stripe.position = CGPoint(x: 0, y: eggHeight / 2 - stripeHeight / 2 - CGFloat(i) * stripeHeight)
            stripe.alpha = 0.7
            stripeContainer.addChild(stripe)
        }

        // Create a mask using the egg shape
        let maskNode = SKShapeNode(ellipseOf: CGSize(width: eggWidth - 4, height: eggHeight - 4))
        maskNode.fillColor = .white
        maskNode.strokeColor = .clear

        let cropNode = SKCropNode()
        cropNode.maskNode = maskNode
        cropNode.addChild(stripeContainer)
        eggNode.addChild(cropNode)

        // Sparkle/shine effect
        let sparkle = SKShapeNode(ellipseOf: CGSize(width: 6, height: 4))
        sparkle.fillColor = .white
        sparkle.strokeColor = .clear
        sparkle.position = CGPoint(x: -eggWidth * 0.2, y: eggHeight * 0.25)
        sparkle.alpha = 0.8
        sparkle.name = "sparkle"
        eggNode.addChild(sparkle)

        // Animate sparkle
        let sparkleOn = SKAction.fadeAlpha(to: 1.0, duration: 0.2)
        let sparkleOff = SKAction.fadeAlpha(to: 0.3, duration: 0.2)
        sparkle.run(SKAction.repeatForever(SKAction.sequence([sparkleOn, sparkleOff])))
    }

    func update() {
        lifetime -= 1

        // Animate rainbow colors shifting
        colorOffset += 1
        if colorOffset % 12 == 0 {
            updateRainbowColors()
        }

        // Blink when about to expire
        if lifetime < 120 && lifetime % 10 < 5 {
            alpha = 0.5
        } else {
            alpha = 1.0
        }
    }

    private func updateRainbowColors() {
        // Rotate rainbow colors for animation effect
        guard let cropNode = eggNode.childNode(withName: "//stripes")?.parent as? SKCropNode,
              let stripeContainer = cropNode.children.first else { return }

        let rainbowColors: [SKColor] = [.red, .orange, .yellow, .green, .blue, .purple]
        let offset = (colorOffset / 12) % 6

        for (i, child) in stripeContainer.children.enumerated() {
            if let stripe = child as? SKShapeNode {
                stripe.fillColor = rainbowColors[(i + offset) % 6]
            }
        }
    }

    func collidesWith(_ tank: Tank) -> Bool {
        let dx = abs(position.x - tank.position.x)
        let dy = abs(position.y - tank.position.y)
        let combinedHalfSize = (EasterEgg.size + tank.tankSize) / 2
        return dx < combinedHalfSize && dy < combinedHalfSize
    }

    func collect() {
        collected = true

        // Collection effect - rainbow burst
        guard let parent = self.parent else { return }

        let rainbowColors: [SKColor] = [.red, .orange, .yellow, .green, .blue, .purple]

        // Rainbow particles burst
        for i in 0..<18 {
            let particle = SKShapeNode(ellipseOf: CGSize(width: 8, height: 12))
            particle.fillColor = rainbowColors[i % 6]
            particle.strokeColor = .white
            particle.lineWidth = 1
            particle.position = position
            particle.zPosition = 200
            parent.addChild(particle)

            let angle = CGFloat(i) * .pi * 2 / 18
            let dx = cos(angle) * 50
            let dy = sin(angle) * 50
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.6)
            let spin = SKAction.rotate(byAngle: .pi * 2, duration: 0.6)
            let fade = SKAction.fadeOut(withDuration: 0.6)
            let remove = SKAction.removeFromParent()
            particle.run(SKAction.sequence([SKAction.group([move, spin, fade]), remove]))
        }

        // Sparkle stars
        for i in 0..<8 {
            let star = SKLabelNode(text: "\u{2605}") // Star symbol
            star.fontSize = 14
            star.fontColor = .yellow
            star.position = position
            star.zPosition = 201
            parent.addChild(star)

            let angle = CGFloat(i) * .pi * 2 / 8 + .pi / 8
            let dx = cos(angle) * 35
            let dy = sin(angle) * 35
            let move = SKAction.moveBy(x: dx, y: dy, duration: 0.4)
            let scale = SKAction.scale(to: 1.5, duration: 0.2)
            let shrink = SKAction.scale(to: 0, duration: 0.2)
            let remove = SKAction.removeFromParent()
            star.run(SKAction.sequence([SKAction.group([move, scale]), shrink, remove]))
        }

        removeFromParent()
    }
}
