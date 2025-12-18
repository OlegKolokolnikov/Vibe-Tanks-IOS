import SpriteKit

class MenuScene: SKScene {

    override func didMove(to view: SKView) {
        backgroundColor = .black
        setupMenu()
    }

    private func setupMenu() {
        // Title
        let title = SKLabelNode(text: "VIBE TANKS")
        title.fontName = "Helvetica-Bold"
        title.fontSize = 48
        title.fontColor = .yellow
        title.position = CGPoint(x: size.width / 2, y: size.height * 0.75)
        addChild(title)

        // Subtitle
        let subtitle = SKLabelNode(text: "Tank Battle Game")
        subtitle.fontName = "Helvetica"
        subtitle.fontSize = 20
        subtitle.fontColor = .white
        subtitle.position = CGPoint(x: size.width / 2, y: size.height * 0.75 - 35)
        addChild(subtitle)

        // Tank in profile view and skull with war hat
        let decoration = createTankAndSkull()
        decoration.position = CGPoint(x: size.width / 2, y: size.height * 0.48)
        addChild(decoration)

        // Play button
        let playButton = createButton(text: "PLAY", position: CGPoint(x: size.width / 2, y: size.height * 0.30))
        playButton.name = "playButton"
        addChild(playButton)

        // Options button
        let optionsButton = createButton(text: "OPTIONS", position: CGPoint(x: size.width / 2, y: size.height * 0.20))
        optionsButton.name = "optionsButton"
        addChild(optionsButton)

        // Instructions
        let instructions = SKLabelNode(text: "Defend your base from enemy tanks!")
        instructions.fontName = "Helvetica"
        instructions.fontSize = 14
        instructions.fontColor = .white
        instructions.position = CGPoint(x: size.width / 2, y: size.height * 0.12)
        addChild(instructions)

        // Credits
        let credits = SKLabelNode(text: "Designed by Oleg")
        credits.fontName = "Helvetica-Bold"
        credits.fontSize = 14
        credits.fontColor = .lightGray
        credits.position = CGPoint(x: size.width / 2, y: size.height * 0.05)
        addChild(credits)
    }

    /// Create tank in profile view with skull commander sticking out
    private func createTankAndSkull() -> SKNode {
        let container = SKNode()

        // Tank in profile (side view) - facing right
        let tank = createProfileTankWithSkull()
        container.addChild(tank)

        // Add subtle animation
        let breathe = SKAction.sequence([
            SKAction.scaleY(to: 1.03, duration: 1.5),
            SKAction.scaleY(to: 0.97, duration: 1.5)
        ])
        container.run(SKAction.repeatForever(breathe))

        return container
    }

    /// Create a detailed tank in profile (side) view with skull commander
    private func createProfileTankWithSkull() -> SKNode {
        let tank = SKNode()

        // Colors with more variation for realism
        let tankGreen = SKColor(red: 0.28, green: 0.38, blue: 0.2, alpha: 1.0)
        let tankDark = SKColor(red: 0.18, green: 0.25, blue: 0.12, alpha: 1.0)
        let tankLight = SKColor(red: 0.38, green: 0.48, blue: 0.28, alpha: 1.0)
        let metalDark = SKColor(red: 0.15, green: 0.15, blue: 0.15, alpha: 1.0)
        let metalMid = SKColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 1.0)
        let metalLight = SKColor(red: 0.45, green: 0.45, blue: 0.45, alpha: 1.0)

        // === TRACKS ===
        // Track housing (fenders)
        let trackHousing = SKShapeNode()
        let housingPath = CGMutablePath()
        housingPath.move(to: CGPoint(x: -50, y: -12))
        housingPath.addLine(to: CGPoint(x: -55, y: -18))
        housingPath.addQuadCurve(to: CGPoint(x: -50, y: -35), control: CGPoint(x: -58, y: -28))
        housingPath.addLine(to: CGPoint(x: 45, y: -35))
        housingPath.addQuadCurve(to: CGPoint(x: 50, y: -18), control: CGPoint(x: 53, y: -28))
        housingPath.addLine(to: CGPoint(x: 45, y: -12))
        housingPath.closeSubpath()
        trackHousing.path = housingPath
        trackHousing.fillColor = metalDark
        trackHousing.strokeColor = .black
        trackHousing.lineWidth = 2
        tank.addChild(trackHousing)

        // Track links (segments on track)
        for i in 0..<22 {
            let link = SKShapeNode(rectOf: CGSize(width: 3, height: 6))
            link.fillColor = metalMid
            link.strokeColor = metalDark
            link.lineWidth = 0.5
            let angle = CGFloat(i) * 0.3
            let x: CGFloat
            let y: CGFloat
            if i < 10 {
                x = -45 + CGFloat(i) * 9.5
                y = -33
            } else if i < 12 {
                x = 48 - CGFloat(i - 10) * 3
                y = -30 + CGFloat(i - 10) * 6
            } else {
                x = 45 - CGFloat(i - 12) * 9.5
                y = -17
            }
            link.position = CGPoint(x: x, y: y)
            tank.addChild(link)
        }

        // Road wheels (large, with detail)
        let wheelPositions: [CGFloat] = [-38, -19, 0, 19, 38]
        for (index, xPos) in wheelPositions.enumerated() {
            // Outer wheel
            let wheel = SKShapeNode(circleOfRadius: 10)
            wheel.fillColor = metalMid
            wheel.strokeColor = metalDark
            wheel.lineWidth = 2
            wheel.position = CGPoint(x: xPos, y: -25)
            tank.addChild(wheel)

            // Rubber tire
            let tire = SKShapeNode(circleOfRadius: 8)
            tire.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
            tire.strokeColor = metalDark
            tire.lineWidth = 1
            tire.position = CGPoint(x: xPos, y: -25)
            tank.addChild(tire)

            // Hub
            let hub = SKShapeNode(circleOfRadius: 4)
            hub.fillColor = metalLight
            hub.strokeColor = metalDark
            hub.lineWidth = 1
            hub.position = CGPoint(x: xPos, y: -25)
            tank.addChild(hub)

            // Hub bolts
            for j in 0..<5 {
                let bolt = SKShapeNode(circleOfRadius: 1)
                bolt.fillColor = metalDark
                bolt.strokeColor = .clear
                let boltAngle = CGFloat(j) * .pi * 2 / 5 + CGFloat(index) * 0.5
                bolt.position = CGPoint(x: xPos + cos(boltAngle) * 2.5, y: -25 + sin(boltAngle) * 2.5)
                tank.addChild(bolt)
            }
        }

        // Drive sprocket (rear)
        let sprocket = SKShapeNode(circleOfRadius: 7)
        sprocket.fillColor = metalMid
        sprocket.strokeColor = metalDark
        sprocket.lineWidth = 1.5
        sprocket.position = CGPoint(x: -48, y: -22)
        tank.addChild(sprocket)

        // Idler wheel (front)
        let idler = SKShapeNode(circleOfRadius: 6)
        idler.fillColor = metalMid
        idler.strokeColor = metalDark
        idler.lineWidth = 1.5
        idler.position = CGPoint(x: 48, y: -22)
        tank.addChild(idler)

        // === HULL ===
        // Lower hull (sloped armor)
        let lowerHull = SKShapeNode()
        let lowerPath = CGMutablePath()
        lowerPath.move(to: CGPoint(x: -48, y: -10))
        lowerPath.addLine(to: CGPoint(x: -42, y: 5))
        lowerPath.addLine(to: CGPoint(x: 50, y: 5))
        lowerPath.addLine(to: CGPoint(x: 55, y: -5))
        lowerPath.addLine(to: CGPoint(x: 50, y: -10))
        lowerPath.closeSubpath()
        lowerHull.path = lowerPath
        lowerHull.fillColor = tankGreen
        lowerHull.strokeColor = tankDark
        lowerHull.lineWidth = 2
        tank.addChild(lowerHull)

        // Upper hull
        let upperHull = SKShapeNode()
        let upperPath = CGMutablePath()
        upperPath.move(to: CGPoint(x: -40, y: 5))
        upperPath.addLine(to: CGPoint(x: -35, y: 18))
        upperPath.addLine(to: CGPoint(x: 40, y: 18))
        upperPath.addLine(to: CGPoint(x: 48, y: 5))
        upperPath.closeSubpath()
        upperHull.path = upperPath
        upperHull.fillColor = tankGreen
        upperHull.strokeColor = tankDark
        upperHull.lineWidth = 2
        tank.addChild(upperHull)

        // Hull highlight (top edge)
        let hullHighlight = SKShapeNode()
        let highlightPath = CGMutablePath()
        highlightPath.move(to: CGPoint(x: -35, y: 17))
        highlightPath.addLine(to: CGPoint(x: 40, y: 17))
        hullHighlight.path = highlightPath
        hullHighlight.strokeColor = tankLight
        hullHighlight.lineWidth = 1.5
        tank.addChild(hullHighlight)

        // Engine deck details (rear)
        let engineGrille = SKShapeNode(rectOf: CGSize(width: 20, height: 8))
        engineGrille.fillColor = metalDark
        engineGrille.strokeColor = metalMid
        engineGrille.lineWidth = 1
        engineGrille.position = CGPoint(x: -28, y: 12)
        tank.addChild(engineGrille)

        // Grille lines
        for i in 0..<4 {
            let line = SKShapeNode(rectOf: CGSize(width: 1, height: 6))
            line.fillColor = metalMid
            line.strokeColor = .clear
            line.position = CGPoint(x: -34 + CGFloat(i) * 5, y: 12)
            tank.addChild(line)
        }

        // === TURRET ===
        // Turret base (cast shape)
        let turretBase = SKShapeNode()
        let turretPath = CGMutablePath()
        turretPath.move(to: CGPoint(x: -5, y: 15))
        turretPath.addQuadCurve(to: CGPoint(x: -20, y: 25), control: CGPoint(x: -18, y: 15))
        turretPath.addQuadCurve(to: CGPoint(x: -15, y: 40), control: CGPoint(x: -25, y: 35))
        turretPath.addLine(to: CGPoint(x: 15, y: 40))
        turretPath.addQuadCurve(to: CGPoint(x: 25, y: 28), control: CGPoint(x: 22, y: 38))
        turretPath.addLine(to: CGPoint(x: 20, y: 20))
        turretPath.addLine(to: CGPoint(x: 5, y: 15))
        turretPath.closeSubpath()
        turretBase.path = turretPath
        turretBase.fillColor = tankGreen
        turretBase.strokeColor = tankDark
        turretBase.lineWidth = 2
        tank.addChild(turretBase)

        // Turret highlight
        let turretHighlight = SKShapeNode()
        let tHighPath = CGMutablePath()
        tHighPath.move(to: CGPoint(x: -15, y: 39))
        tHighPath.addLine(to: CGPoint(x: 15, y: 39))
        turretHighlight.path = tHighPath
        turretHighlight.strokeColor = tankLight
        turretHighlight.lineWidth = 1.5
        tank.addChild(turretHighlight)

        // Cupola (commander's hatch)
        let cupola = SKShapeNode(ellipseOf: CGSize(width: 18, height: 8))
        cupola.fillColor = tankDark
        cupola.strokeColor = .black
        cupola.lineWidth = 1.5
        cupola.position = CGPoint(x: -5, y: 42)
        tank.addChild(cupola)

        // Hatch opening
        let hatch = SKShapeNode(ellipseOf: CGSize(width: 14, height: 6))
        hatch.fillColor = SKColor(red: 0.05, green: 0.05, blue: 0.05, alpha: 1.0)
        hatch.strokeColor = tankDark
        hatch.lineWidth = 1
        hatch.position = CGPoint(x: -5, y: 43)
        tank.addChild(hatch)

        // === GUN ===
        // Mantlet (gun shield)
        let mantlet = SKShapeNode()
        let mantletPath = CGMutablePath()
        mantletPath.move(to: CGPoint(x: 18, y: 22))
        mantletPath.addQuadCurve(to: CGPoint(x: 25, y: 30), control: CGPoint(x: 28, y: 24))
        mantletPath.addQuadCurve(to: CGPoint(x: 18, y: 38), control: CGPoint(x: 28, y: 36))
        mantletPath.addLine(to: CGPoint(x: 15, y: 35))
        mantletPath.addLine(to: CGPoint(x: 15, y: 25))
        mantletPath.closeSubpath()
        mantlet.path = mantletPath
        mantlet.fillColor = tankDark
        mantlet.strokeColor = .black
        mantlet.lineWidth = 1.5
        tank.addChild(mantlet)

        // Gun barrel
        let barrel = SKShapeNode(rectOf: CGSize(width: 55, height: 7), cornerRadius: 1)
        barrel.fillColor = metalDark
        barrel.strokeColor = .black
        barrel.lineWidth = 1.5
        barrel.position = CGPoint(x: 52, y: 30)
        tank.addChild(barrel)

        // Barrel highlight
        let barrelHL = SKShapeNode()
        let bhlPath = CGMutablePath()
        bhlPath.move(to: CGPoint(x: 25, y: 32))
        bhlPath.addLine(to: CGPoint(x: 78, y: 32))
        barrelHL.path = bhlPath
        barrelHL.strokeColor = metalLight
        barrelHL.lineWidth = 1
        tank.addChild(barrelHL)

        // Muzzle brake
        let muzzle = SKShapeNode()
        let muzzlePath = CGMutablePath()
        muzzlePath.move(to: CGPoint(x: 78, y: 25))
        muzzlePath.addLine(to: CGPoint(x: 85, y: 24))
        muzzlePath.addLine(to: CGPoint(x: 85, y: 36))
        muzzlePath.addLine(to: CGPoint(x: 78, y: 35))
        muzzlePath.closeSubpath()
        muzzle.path = muzzlePath
        muzzle.fillColor = metalDark
        muzzle.strokeColor = .black
        muzzle.lineWidth = 1.5
        tank.addChild(muzzle)

        // Muzzle slots
        for i in 0..<3 {
            let slot = SKShapeNode(rectOf: CGSize(width: 1.5, height: 4))
            slot.fillColor = .black
            slot.strokeColor = .clear
            slot.position = CGPoint(x: 80 + CGFloat(i) * 2, y: 30)
            tank.addChild(slot)
        }

        // === DETAILS ===
        // Tow cable on hull
        let cable = SKShapeNode()
        let cablePath = CGMutablePath()
        cablePath.move(to: CGPoint(x: 45, y: 0))
        cablePath.addQuadCurve(to: CGPoint(x: 52, y: 8), control: CGPoint(x: 55, y: 2))
        cable.path = cablePath
        cable.strokeColor = SKColor(red: 0.35, green: 0.3, blue: 0.2, alpha: 1.0)
        cable.lineWidth = 3
        cable.lineCap = .round
        tank.addChild(cable)

        // Star emblem on turret
        let star = createStar(size: 12, color: .red)
        star.position = CGPoint(x: 0, y: 28)
        tank.addChild(star)

        // Tool (shovel) on hull side
        let shovelHandle = SKShapeNode(rectOf: CGSize(width: 25, height: 2))
        shovelHandle.fillColor = SKColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1.0)
        shovelHandle.strokeColor = SKColor(red: 0.3, green: 0.2, blue: 0.1, alpha: 1.0)
        shovelHandle.lineWidth = 0.5
        shovelHandle.position = CGPoint(x: 15, y: 8)
        shovelHandle.zRotation = 0.1
        tank.addChild(shovelHandle)

        let shovelHead = SKShapeNode(rectOf: CGSize(width: 6, height: 8))
        shovelHead.fillColor = metalMid
        shovelHead.strokeColor = metalDark
        shovelHead.lineWidth = 0.5
        shovelHead.position = CGPoint(x: 28, y: 9)
        shovelHead.zRotation = 0.1
        tank.addChild(shovelHead)

        // Skull commander sticking out of hatch
        let skull = createProfileSkull()
        skull.position = CGPoint(x: -5, y: 62)
        tank.addChild(skull)

        return tank
    }

    /// Create a small star shape
    private func createStar(size: CGFloat, color: SKColor) -> SKNode {
        let star = SKShapeNode()
        let path = CGMutablePath()
        let points = 5
        let outerRadius = size
        let innerRadius = size * 0.4

        for i in 0..<points * 2 {
            let radius = i % 2 == 0 ? outerRadius : innerRadius
            let angle = CGFloat(i) * .pi / CGFloat(points) - .pi / 2
            let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
            if i == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        star.path = path
        star.fillColor = color
        star.strokeColor = .darkGray
        star.lineWidth = 0.5
        return star
    }

    /// Create a realistic skull in profile view (facing right) with tanker helmet
    private func createProfileSkull() -> SKNode {
        let skull = SKNode()

        // Colors for realistic bone
        let boneLight = SKColor(red: 0.95, green: 0.92, blue: 0.85, alpha: 1.0)
        let boneMid = SKColor(red: 0.85, green: 0.8, blue: 0.7, alpha: 1.0)
        let boneDark = SKColor(red: 0.6, green: 0.55, blue: 0.45, alpha: 1.0)
        let boneShade = SKColor(red: 0.5, green: 0.45, blue: 0.35, alpha: 1.0)

        // Helmet colors
        let helmetMain = SKColor(red: 0.25, green: 0.2, blue: 0.15, alpha: 1.0)
        let helmetDark = SKColor(red: 0.15, green: 0.12, blue: 0.08, alpha: 1.0)
        let helmetLight = SKColor(red: 0.35, green: 0.28, blue: 0.2, alpha: 1.0)

        // === SKULL CRANIUM ===
        // Main skull shape (profile - anatomically correct)
        let cranium = SKShapeNode()
        let craniumPath = CGMutablePath()
        // Start at back of skull
        craniumPath.move(to: CGPoint(x: -18, y: 5))
        // Back curve (occipital)
        craniumPath.addQuadCurve(to: CGPoint(x: -20, y: -5), control: CGPoint(x: -22, y: 0))
        // Base of skull
        craniumPath.addQuadCurve(to: CGPoint(x: -12, y: -12), control: CGPoint(x: -18, y: -10))
        // Mastoid process
        craniumPath.addLine(to: CGPoint(x: -8, y: -10))
        // Mandible angle
        craniumPath.addLine(to: CGPoint(x: -5, y: -15))
        // Lower jaw
        craniumPath.addLine(to: CGPoint(x: 8, y: -18))
        // Chin
        craniumPath.addQuadCurve(to: CGPoint(x: 14, y: -14), control: CGPoint(x: 12, y: -20))
        // Front of mandible
        craniumPath.addLine(to: CGPoint(x: 16, y: -8))
        // Maxilla (upper jaw)
        craniumPath.addLine(to: CGPoint(x: 18, y: -4))
        // Nasal bone
        craniumPath.addQuadCurve(to: CGPoint(x: 14, y: 4), control: CGPoint(x: 20, y: 0))
        // Glabella (brow)
        craniumPath.addLine(to: CGPoint(x: 12, y: 8))
        // Frontal bone
        craniumPath.addQuadCurve(to: CGPoint(x: 5, y: 15), control: CGPoint(x: 12, y: 14))
        // Top of skull (parietal)
        craniumPath.addQuadCurve(to: CGPoint(x: -18, y: 5), control: CGPoint(x: -8, y: 18))
        craniumPath.closeSubpath()
        cranium.path = craniumPath
        cranium.fillColor = boneLight
        cranium.strokeColor = boneDark
        cranium.lineWidth = 2
        skull.addChild(cranium)

        // Temporal fossa (depression on side of skull)
        let temporal = SKShapeNode()
        let temporalPath = CGMutablePath()
        temporalPath.move(to: CGPoint(x: -5, y: 8))
        temporalPath.addQuadCurve(to: CGPoint(x: -10, y: -2), control: CGPoint(x: -12, y: 5))
        temporalPath.addQuadCurve(to: CGPoint(x: -2, y: 2), control: CGPoint(x: -8, y: -2))
        temporalPath.closeSubpath()
        temporal.path = temporalPath
        temporal.fillColor = boneMid
        temporal.strokeColor = .clear
        skull.addChild(temporal)

        // Zygomatic arch (cheekbone)
        let zygomatic = SKShapeNode()
        let zygPath = CGMutablePath()
        zygPath.move(to: CGPoint(x: -2, y: -2))
        zygPath.addLine(to: CGPoint(x: 10, y: -1))
        zygPath.addQuadCurve(to: CGPoint(x: 14, y: -4), control: CGPoint(x: 13, y: -1))
        zygPath.addLine(to: CGPoint(x: 12, y: -6))
        zygPath.addLine(to: CGPoint(x: 0, y: -5))
        zygPath.closeSubpath()
        zygomatic.path = zygPath
        zygomatic.fillColor = boneLight
        zygomatic.strokeColor = boneDark
        zygomatic.lineWidth = 1
        skull.addChild(zygomatic)

        // === EYE SOCKET ===
        // Orbit (eye socket) - proper shape
        let orbit = SKShapeNode()
        let orbitPath = CGMutablePath()
        orbitPath.move(to: CGPoint(x: 2, y: 6))
        orbitPath.addQuadCurve(to: CGPoint(x: 12, y: 4), control: CGPoint(x: 8, y: 8))
        orbitPath.addQuadCurve(to: CGPoint(x: 12, y: -3), control: CGPoint(x: 15, y: 0))
        orbitPath.addQuadCurve(to: CGPoint(x: 4, y: -4), control: CGPoint(x: 8, y: -6))
        orbitPath.addQuadCurve(to: CGPoint(x: 2, y: 6), control: CGPoint(x: 0, y: 2))
        orbitPath.closeSubpath()
        orbit.path = orbitPath
        orbit.fillColor = SKColor(red: 0.08, green: 0.05, blue: 0.02, alpha: 1.0)
        orbit.strokeColor = boneShade
        orbit.lineWidth = 1.5
        skull.addChild(orbit)

        // Eye socket depth shading
        let orbitShade = SKShapeNode(ellipseOf: CGSize(width: 7, height: 8))
        orbitShade.fillColor = SKColor(red: 0.15, green: 0.1, blue: 0.05, alpha: 1.0)
        orbitShade.strokeColor = .clear
        orbitShade.position = CGPoint(x: 7, y: 1)
        skull.addChild(orbitShade)

        // Glowing eye (spooky but friendly)
        let eyeGlow = SKShapeNode(circleOfRadius: 3)
        eyeGlow.fillColor = SKColor(red: 1.0, green: 0.3, blue: 0.1, alpha: 0.8)
        eyeGlow.strokeColor = .clear
        eyeGlow.position = CGPoint(x: 7, y: 1)
        skull.addChild(eyeGlow)

        let eyeCore = SKShapeNode(circleOfRadius: 1.5)
        eyeCore.fillColor = SKColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0)
        eyeCore.strokeColor = .clear
        eyeCore.position = CGPoint(x: 7, y: 1)
        skull.addChild(eyeCore)

        // === NASAL CAVITY ===
        let nasal = SKShapeNode()
        let nasalPath = CGMutablePath()
        nasalPath.move(to: CGPoint(x: 14, y: 0))
        nasalPath.addQuadCurve(to: CGPoint(x: 16, y: -5), control: CGPoint(x: 18, y: -2))
        nasalPath.addLine(to: CGPoint(x: 14, y: -6))
        nasalPath.addQuadCurve(to: CGPoint(x: 14, y: 0), control: CGPoint(x: 12, y: -3))
        nasalPath.closeSubpath()
        nasal.path = nasalPath
        nasal.fillColor = SKColor(red: 0.1, green: 0.08, blue: 0.05, alpha: 1.0)
        nasal.strokeColor = boneShade
        nasal.lineWidth = 1
        skull.addChild(nasal)

        // Nasal bone
        let nasalBone = SKShapeNode()
        let nbPath = CGMutablePath()
        nbPath.move(to: CGPoint(x: 12, y: 5))
        nbPath.addLine(to: CGPoint(x: 14, y: 2))
        nbPath.addLine(to: CGPoint(x: 13, y: 0))
        nasalBone.path = nbPath
        nasalBone.strokeColor = boneDark
        nasalBone.lineWidth = 1
        skull.addChild(nasalBone)

        // === TEETH ===
        // Upper teeth (maxillary)
        let upperTeeth = SKShapeNode()
        let utPath = CGMutablePath()
        utPath.move(to: CGPoint(x: 10, y: -7))
        utPath.addLine(to: CGPoint(x: 17, y: -5))
        utPath.addLine(to: CGPoint(x: 17, y: -8))
        utPath.addLine(to: CGPoint(x: 10, y: -10))
        utPath.closeSubpath()
        upperTeeth.path = utPath
        upperTeeth.fillColor = boneLight
        upperTeeth.strokeColor = boneDark
        upperTeeth.lineWidth = 1
        skull.addChild(upperTeeth)

        // Individual upper teeth lines
        for i in 0..<4 {
            let toothLine = SKShapeNode()
            let tlPath = CGMutablePath()
            let x = CGFloat(11 + i * 2)
            tlPath.move(to: CGPoint(x: x, y: -7))
            tlPath.addLine(to: CGPoint(x: x, y: -10))
            toothLine.path = tlPath
            toothLine.strokeColor = boneDark
            toothLine.lineWidth = 0.5
            skull.addChild(toothLine)
        }

        // Lower teeth (mandibular)
        let lowerTeeth = SKShapeNode()
        let ltPath = CGMutablePath()
        ltPath.move(to: CGPoint(x: 8, y: -11))
        ltPath.addLine(to: CGPoint(x: 16, y: -9))
        ltPath.addLine(to: CGPoint(x: 16, y: -12))
        ltPath.addLine(to: CGPoint(x: 8, y: -14))
        ltPath.closeSubpath()
        lowerTeeth.path = ltPath
        lowerTeeth.fillColor = boneLight
        lowerTeeth.strokeColor = boneDark
        lowerTeeth.lineWidth = 1
        skull.addChild(lowerTeeth)

        // Individual lower teeth
        for i in 0..<4 {
            let toothLine = SKShapeNode()
            let tlPath = CGMutablePath()
            let x = CGFloat(9 + i * 2)
            tlPath.move(to: CGPoint(x: x, y: -11))
            tlPath.addLine(to: CGPoint(x: x, y: -14))
            toothLine.path = tlPath
            toothLine.strokeColor = boneDark
            toothLine.lineWidth = 0.5
            skull.addChild(toothLine)
        }

        // === BONE DETAILS ===
        // Suture lines (skull bone joints)
        let suture1 = SKShapeNode()
        let s1Path = CGMutablePath()
        s1Path.move(to: CGPoint(x: -5, y: 12))
        s1Path.addQuadCurve(to: CGPoint(x: -12, y: 5), control: CGPoint(x: -10, y: 10))
        suture1.path = s1Path
        suture1.strokeColor = boneDark
        suture1.lineWidth = 0.5
        skull.addChild(suture1)

        let suture2 = SKShapeNode()
        let s2Path = CGMutablePath()
        s2Path.move(to: CGPoint(x: 0, y: 10))
        s2Path.addQuadCurve(to: CGPoint(x: -8, y: -5), control: CGPoint(x: -5, y: 3))
        suture2.path = s2Path
        suture2.strokeColor = boneDark
        suture2.lineWidth = 0.5
        skull.addChild(suture2)

        // Highlight on forehead
        let foreheadHL = SKShapeNode(ellipseOf: CGSize(width: 8, height: 5))
        foreheadHL.fillColor = SKColor.white.withAlphaComponent(0.15)
        foreheadHL.strokeColor = .clear
        foreheadHL.position = CGPoint(x: 3, y: 10)
        skull.addChild(foreheadHL)

        // === TANKER HELMET ===
        // Helmet shell
        let helmet = SKShapeNode()
        let helmetPath = CGMutablePath()
        helmetPath.move(to: CGPoint(x: -22, y: 5))
        helmetPath.addQuadCurve(to: CGPoint(x: -18, y: 18), control: CGPoint(x: -25, y: 12))
        helmetPath.addQuadCurve(to: CGPoint(x: 8, y: 22), control: CGPoint(x: -5, y: 24))
        helmetPath.addQuadCurve(to: CGPoint(x: 15, y: 14), control: CGPoint(x: 14, y: 20))
        helmetPath.addLine(to: CGPoint(x: 12, y: 8))
        helmetPath.addQuadCurve(to: CGPoint(x: -22, y: 5), control: CGPoint(x: -5, y: 15))
        helmetPath.closeSubpath()
        helmet.path = helmetPath
        helmet.fillColor = helmetMain
        helmet.strokeColor = helmetDark
        helmet.lineWidth = 2
        skull.addChild(helmet)

        // Helmet padding (visible edge)
        let padding = SKShapeNode()
        let padPath = CGMutablePath()
        padPath.move(to: CGPoint(x: -20, y: 6))
        padPath.addQuadCurve(to: CGPoint(x: 12, y: 9), control: CGPoint(x: -5, y: 13))
        padding.path = padPath
        padding.strokeColor = SKColor(red: 0.5, green: 0.35, blue: 0.2, alpha: 1.0)
        padding.lineWidth = 3
        skull.addChild(padding)

        // Helmet ridge/seam
        let ridge = SKShapeNode()
        let ridgePath = CGMutablePath()
        ridgePath.move(to: CGPoint(x: -5, y: 22))
        ridgePath.addQuadCurve(to: CGPoint(x: -15, y: 10), control: CGPoint(x: -12, y: 18))
        ridge.path = ridgePath
        ridge.strokeColor = helmetDark
        ridge.lineWidth = 1.5
        skull.addChild(ridge)

        // Helmet highlight
        let helmetHL = SKShapeNode()
        let hlPath = CGMutablePath()
        hlPath.move(to: CGPoint(x: -10, y: 18))
        hlPath.addQuadCurve(to: CGPoint(x: 5, y: 20), control: CGPoint(x: -2, y: 21))
        helmetHL.path = hlPath
        helmetHL.strokeColor = helmetLight
        helmetHL.lineWidth = 2
        skull.addChild(helmetHL)

        // Goggles on helmet
        let goggleStrap = SKShapeNode()
        let gsPath = CGMutablePath()
        gsPath.move(to: CGPoint(x: -18, y: 12))
        gsPath.addQuadCurve(to: CGPoint(x: 10, y: 15), control: CGPoint(x: -3, y: 18))
        goggleStrap.path = gsPath
        goggleStrap.strokeColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        goggleStrap.lineWidth = 2.5
        skull.addChild(goggleStrap)

        // Goggle lens
        let goggleLens = SKShapeNode(ellipseOf: CGSize(width: 10, height: 7))
        goggleLens.fillColor = SKColor(red: 0.15, green: 0.2, blue: 0.25, alpha: 1.0)
        goggleLens.strokeColor = SKColor(red: 0.3, green: 0.25, blue: 0.2, alpha: 1.0)
        goggleLens.lineWidth = 2
        goggleLens.position = CGPoint(x: 0, y: 15)
        skull.addChild(goggleLens)

        // Goggle reflection
        let goggleRef = SKShapeNode(ellipseOf: CGSize(width: 3, height: 2))
        goggleRef.fillColor = SKColor.white.withAlphaComponent(0.3)
        goggleRef.strokeColor = .clear
        goggleRef.position = CGPoint(x: -2, y: 16)
        skull.addChild(goggleRef)

        // Red star on helmet
        let star = createStar(size: 6, color: .red)
        star.position = CGPoint(x: -12, y: 14)
        skull.addChild(star)

        return skull
    }

    private func createButton(text: String, position: CGPoint) -> SKNode {
        let container = SKNode()
        container.position = position

        // Button background
        let background = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 8)
        background.fillColor = SKColor(red: 0.2, green: 0.2, blue: 0.2, alpha: 1.0)
        background.strokeColor = .yellow
        background.lineWidth = 2
        container.addChild(background)

        // Button text
        let label = SKLabelNode(text: text)
        label.fontName = "Helvetica-Bold"
        label.fontSize = 24
        label.fontColor = .white
        label.verticalAlignmentMode = .center
        container.addChild(label)

        return container
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        let nodes = nodes(at: location)

        for node in nodes {
            if node.name == "playButton" || node.parent?.name == "playButton" {
                startGame()
                return
            }
            if node.name == "optionsButton" || node.parent?.name == "optionsButton" {
                openOptions()
                return
            }
        }
    }

    private func openOptions() {
        let optionsScene = OptionsScene(size: size)
        optionsScene.scaleMode = scaleMode
        view?.presentScene(optionsScene, transition: .fade(withDuration: 0.3))
    }

    private func startGame() {
        // Generate a new random session seed for this game session
        let sessionSeed = UInt64.random(in: 0..<UInt64.max)
        let gameScene = GameScene(size: size, level: 1, score: 0, sessionSeed: sessionSeed)
        gameScene.scaleMode = scaleMode

        let transition = SKTransition.fade(withDuration: 0.5)
        view?.presentScene(gameScene, transition: transition)
    }
}
