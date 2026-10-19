import AppKit
import SpriteKit

enum Palette {
    static let red = SKColor(srgbRed: 0.85, green: 0.11, blue: 0.17, alpha: 1)
    static let redDark = SKColor(srgbRed: 0.58, green: 0.06, blue: 0.12, alpha: 1)
    static let blue = SKColor(srgbRed: 0.10, green: 0.16, blue: 0.48, alpha: 1)
    static let blueDark = SKColor(srgbRed: 0.06, green: 0.10, blue: 0.33, alpha: 1)
    static let ink = SKColor(srgbRed: 0.05, green: 0.05, blue: 0.09, alpha: 1)
    static let eye = SKColor(srgbRed: 0.96, green: 0.98, blue: 1.0, alpha: 1)
    static let eyeFar = SKColor(srgbRed: 0.72, green: 0.79, blue: 0.92, alpha: 1)
    static let webLine = SKColor(srgbRed: 0.16, green: 0.02, blue: 0.03, alpha: 0.7)
    static let thread = SKColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 0.95)
}

final class Limb {
    let pivot: SKNode
    let elbow: SKNode
    let tip: SKNode
    let length: CGFloat
    init(pivot: SKNode, elbow: SKNode, tip: SKNode, length: CGFloat) {
        self.pivot = pivot
        self.elbow = elbow
        self.tip = tip
        self.length = length
    }
}

/// Procedurally drawn mini web-hero with 8 animated joints.
/// Body space origin = hip. Limbs hang down at 0 radians and swing toward +x when positive.
final class Rig {
    static let footReach: CGFloat = 26   // hip -> sole
    static let headReach: CGFloat = 42   // hip -> top of head
    static let grabRadius: CGFloat = 34

    let root = SKNode()
    private let hipNode = SKNode()
    private let upper = SKNode()
    private let headPivot = SKNode()
    private let headNode = SKNode()

    private var armNear: Limb!
    private var armFar: Limb!
    private var legNear: Limb!
    private var legFar: Limb!

    private let cape = SKShapeNode()
    private let heldBat = SKNode()
    private let mallet = SKNode()
    private var heldSword = SKNode()
    private var heldPistol = SKNode()

    private var eyes: [SKShapeNode] = []
    private var eyeHome: [CGPoint] = []
    private var eyeSize: [CGSize] = []
    private var eyeLook = CGPoint.zero

    /// 0 = eyes wide open, 1 = fully shut. Driven by the blink reflex in `Buddy`.
    var blink: CGFloat = 0 {
        didSet { if blink != oldValue { updateEyes() } }
    }

    private var muscular: Bool { [.hulk, .redHulk, .abomination, .absorbingMan].contains(skin.costume) }
    private var shortsColor: SKColor { skin.costume == .redHulk ? SKColor(white: 0.12, alpha: 1) : SKColor(srgbRed: 0.35, green: 0.14, blue: 0.5, alpha: 1) }
    let skin: Skin

    var facing: CGFloat = 1 { didSet { applyTransform() } }
    var scale: CGFloat = 0.9 { didSet { applyTransform() } }
    private(set) var pose = Pose.stand

    init(skin: Skin = Skin()) {
        self.skin = skin
        build()
        applyTransform()
        apply(Pose.stand)
    }

    // MARK: - Construction

    private func build() {
        root.zPosition = 100
        root.name = "buddy"
        root.addChild(hipNode)
        hipNode.addChild(upper)

        // far leg -------------------------------------------------------
        legFar = makeLeg(shaded: true)
        legFar.pivot.position = CGPoint(x: -2.5, y: -1)
        legFar.pivot.zPosition = 1
        hipNode.addChild(legFar.pivot)

        // far arm (behind the torso) ------------------------------------
        armFar = makeArm(shaded: true)
        armFar.pivot.position = CGPoint(x: muscular ? -7 : -3, y: 16)
        armFar.pivot.zPosition = 2
        upper.addChild(armFar.pivot)

        // pelvis --------------------------------------------------------
        let pelvis = SKShapeNode(rect: CGRect(x: -7.5, y: -7, width: 15, height: 13), cornerRadius: 5.5)
        pelvis.fillColor = muscular ? shortsColor : skin.limb
        pelvis.strokeColor = skin.ink
        pelvis.lineWidth = 1.4
        pelvis.zPosition = 3
        hipNode.addChild(pelvis)

        // torso ---------------------------------------------------------
        let torsoRect = CGRect(x: muscular ? -13 : -9.5, y: -2, width: muscular ? 26 : 19, height: 24)
        let torso = SKShapeNode(rect: torsoRect, cornerRadius: 8)
        torso.fillColor = skin.suit
        torso.strokeColor = skin.ink
        torso.lineWidth = 1.5
        torso.zPosition = 4
        upper.addChild(torso)

        let chest = SKCropNode()
        chest.maskNode = {
            let m = SKShapeNode(rect: torsoRect, cornerRadius: 8)
            m.fillColor = .white
            m.strokeColor = .clear
            return m
        }()
        chest.zPosition = 5
        if skin.webbing { chest.addChild(webPattern()) }
        if skin.emblem { chest.addChild(spiderEmblem()) }
        if skin.webbing || skin.emblem { upper.addChild(chest) }
        switch skin.backGear {
        case .none: break
        case .tentacles: buildTentacles()
        case .wings: buildWings()
        case .swords: buildSwords()
        }

        if skin.deadpoolDetails { buildDeadpoolSuit() }

        // head ----------------------------------------------------------
        headPivot.position = CGPoint(x: 0.5, y: 21)
        headPivot.zPosition = 8
        upper.addChild(headPivot)
        headNode.position = CGPoint(x: 1.5, y: 9)
        headPivot.addChild(headNode)
        buildHead()

        // near leg ------------------------------------------------------
        legNear = makeLeg(shaded: false)
        legNear.pivot.position = CGPoint(x: 1.5, y: -1)
        legNear.pivot.zPosition = 6
        hipNode.addChild(legNear.pivot)

        // near arm ------------------------------------------------------
        armNear = makeArm(shaded: false)
        armNear.pivot.position = CGPoint(x: muscular ? 9 : 5.2, y: 16)
        armNear.pivot.zPosition = 9
        upper.addChild(armNear.pivot)
        if skin.deadpoolDetails { buildWeapons() }
        if skin.costume == .batman { buildBatman() }
        if skin.costume == .harley { buildMallet() }
        if muscular { buildMuscles() }
    }

    static func batShape() -> CGPath {
        let path = CGMutablePath()
        let points: [CGPoint] = [CGPoint(x: -12, y: 5), CGPoint(x: -8, y: -4), CGPoint(x: -4, y: -1),
            CGPoint(x: 0, y: -6), CGPoint(x: 4, y: -1), CGPoint(x: 8, y: -4), CGPoint(x: 12, y: 5),
            CGPoint(x: 4, y: 2), CGPoint(x: 2, y: 5), CGPoint(x: 0, y: 3), CGPoint(x: -2, y: 5), CGPoint(x: -4, y: 2)]
        path.addLines(between: points); path.closeSubpath()
        return path
    }

    private func buildBatman() {
        cape.fillColor = SKColor(white: 0.065, alpha: 1)
        cape.strokeColor = SKColor(white: 0.25, alpha: 1)
        cape.lineWidth = 0.8; cape.zPosition = -2
        upper.addChild(cape)
        let badge = SKShapeNode(ellipseOf: CGSize(width: 16, height: 9))
        badge.position = CGPoint(x: 0, y: 12); badge.zPosition = 6
        badge.fillColor = SKColor(srgbRed: 1, green: 0.76, blue: 0.15, alpha: 1)
        badge.strokeColor = skin.ink
        let bat = SKShapeNode(path: Rig.batShape())
        bat.setScale(0.52); bat.fillColor = skin.ink; bat.strokeColor = .clear
        badge.addChild(bat); upper.addChild(badge)
        let belt = SKShapeNode(rectOf: CGSize(width: 17, height: 4))
        belt.fillColor = badge.fillColor; belt.strokeColor = skin.ink; belt.zPosition = 7
        hipNode.addChild(belt)
        let batarang = SKShapeNode(path: Rig.batShape())
        batarang.setScale(0.5); batarang.fillColor = SKColor(white: 0.55, alpha: 1)
        batarang.strokeColor = skin.ink
        heldBat.addChild(batarang); armNear.tip.addChild(heldBat)
        heldBat.isHidden = true
        animateCostume(time: 0, gliding: false)
    }

    private func buildMuscles() {
        for x: CGFloat in [-6, 6] {
            let pec = SKShapeNode(ellipseOf: CGSize(width: 10, height: 9))
            pec.position = CGPoint(x: x, y: 15); pec.zPosition = 5
            pec.fillColor = skin.suit; pec.strokeColor = skin.suitDark; pec.lineWidth = 0.8
            upper.addChild(pec)
        }
        let absPath = CGMutablePath()
        absPath.move(to: CGPoint(x: 0, y: 1)); absPath.addLine(to: CGPoint(x: 0, y: 11))
        for y: CGFloat in [4, 8] { absPath.move(to: CGPoint(x: -5, y: y)); absPath.addLine(to: CGPoint(x: 5, y: y)) }
        let absNode = SKShapeNode(path: absPath)
        absNode.strokeColor = skin.suitDark; absNode.lineWidth = 0.8; absNode.zPosition = 5
        upper.addChild(absNode)
    }

    private func buildHulkFace() {
        if skin.costume != .absorbingMan {
            let hair = CGMutablePath()
            hair.addLines(between: [CGPoint(x: -11, y: 5), CGPoint(x: -10, y: 12), CGPoint(x: -6, y: 9),
                CGPoint(x: -3, y: 13), CGPoint(x: 0, y: 10), CGPoint(x: 4, y: 13), CGPoint(x: 10, y: 10), CGPoint(x: 11, y: 5)])
            hair.closeSubpath()
            let node = SKShapeNode(path: hair)
            node.fillColor = skin.ink; node.strokeColor = skin.ink; node.zPosition = 2
            headNode.addChild(node)
        }
        let teeth = SKShapeNode(rect: CGRect(x: -5, y: -7, width: 11, height: 3.5), cornerRadius: 1)
        teeth.fillColor = .white; teeth.strokeColor = skin.ink; teeth.lineWidth = 1; teeth.zPosition = 3
        headNode.addChild(teeth)
        if skin.costume == .abomination {
            for x: CGFloat in [-13, 13] {
                let ear = SKShapeNode(ellipseOf: CGSize(width: 8, height: 12))
                ear.position = CGPoint(x: x, y: 0); ear.fillColor = skin.suitDark; ear.strokeColor = skin.ink
                headNode.addChild(ear)
            }
        }
    }

    private func buildMallet() {
        let handle = SKShapeNode(rect: CGRect(x: -1, y: -4, width: 2, height: 20))
        handle.fillColor = SKColor.brown; handle.strokeColor = skin.ink
        mallet.addChild(handle)
        let head = SKShapeNode(rectOf: CGSize(width: 15, height: 10), cornerRadius: 2)
        head.position.y = 17; head.fillColor = Palette.redDark; head.strokeColor = skin.ink
        mallet.addChild(head); armNear.tip.addChild(mallet)
    }

    func animateCostume(time: CGFloat, gliding: Bool, batarang: Bool = false) {
        guard skin.costume == .batman else { return }
        heldBat.isHidden = !batarang
        let w: CGFloat = gliding ? 34 : 17
        let flutter = sin(time * 5) * (gliding ? 3 : 2)
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -7, y: 20))
        path.addLine(to: CGPoint(x: -w - 8, y: -12 + flutter))
        path.addQuadCurve(to: CGPoint(x: -w / 2, y: -12), control: CGPoint(x: -w / 2 - 2, y: -6))
        path.addQuadCurve(to: CGPoint(x: 0, y: -16 + flutter), control: CGPoint(x: -2, y: -7))
        path.addQuadCurve(to: CGPoint(x: w, y: -12), control: CGPoint(x: 8, y: -5))
        path.addLine(to: CGPoint(x: 7, y: 20))
        path.closeSubpath(); cape.path = path
    }

    private func buildWeapons() {
        let blade = SKShapeNode(rect: CGRect(x: -1, y: 0, width: 2, height: 28), cornerRadius: 0.6)
        blade.fillColor = SKColor(white: 0.85, alpha: 1)
        blade.strokeColor = skin.ink
        blade.lineWidth = 0.7
        heldSword.addChild(blade)
        let guardBar = SKShapeNode(rectOf: CGSize(width: 9, height: 2))
        guardBar.fillColor = SKColor(white: 0.45, alpha: 1)
        heldSword.addChild(guardBar)
        armNear.tip.addChild(heldSword)
        let barrel = SKShapeNode(rect: CGRect(x: -2, y: -10, width: 4, height: 10), cornerRadius: 1)
        barrel.fillColor = SKColor(white: 0.28, alpha: 1)
        barrel.strokeColor = skin.ink
        heldPistol.addChild(barrel)
        armNear.tip.addChild(heldPistol)
        showWeapons(sword: false, pistol: false)
    }

    func showWeapons(sword: Bool, pistol: Bool) {
        heldSword.isHidden = !sword
        heldPistol.isHidden = !pistol
    }

    private func buildHead() {
        let head = SKShapeNode(rect: CGRect(x: -11, y: -10, width: 22, height: 20), cornerRadius: 8.5)
        head.fillColor = skin.costume == .batman || skin.costume == .bane ? skin.ink : (skin.costume == .joker || skin.costume == .harley ? SKColor(white: 0.93, alpha: 1) : skin.suit)
        head.strokeColor = skin.ink
        head.lineWidth = 1.6
        head.zPosition = 0
        headNode.addChild(head)

        if skin.deadpoolDetails {
            for x: CGFloat in [-4.8, 4.4] {
                let patch = SKShapeNode(ellipseOf: CGSize(width: 10, height: 15))
                patch.position = CGPoint(x: x, y: 0.5)
                patch.fillColor = skin.ink
                patch.strokeColor = .clear
                patch.zPosition = 0.5
                headNode.addChild(patch)
            }
        }
        let k = skin.eyeScale
        _ = makeEye(size: CGSize(width: 9.4 * k, height: 8.0 * k), color: skin.eye,
                    tilt: -0.30, at: CGPoint(x: 4.0, y: 1.0), outline: 1.7)
        _ = makeEye(size: CGSize(width: 7.6 * k, height: 6.6 * k), color: skin.eyeFar,
                    tilt: -0.30, at: CGPoint(x: -4.6, y: 1.5), outline: 1.4)
        if muscular { buildHulkFace() }
        if skin.costume == .leader {
            let cranium = SKShapeNode(rect: CGRect(x: -10, y: 5, width: 20, height: 19), cornerRadius: 7)
            cranium.fillColor = skin.suit; cranium.strokeColor = skin.ink
            headNode.addChild(cranium)
            let folds = CGMutablePath()
            for y: CGFloat in [10, 15, 20] {
                folds.move(to: CGPoint(x: -6, y: y))
                folds.addQuadCurve(to: CGPoint(x: 6, y: y), control: CGPoint(x: 0, y: y + 4))
            }
            let ridges = SKShapeNode(path: folds)
            ridges.strokeColor = skin.suitDark; ridges.lineWidth = 0.8; ridges.zPosition = 1
            headNode.addChild(ridges)
        }
        buildHeadgear()
    }

    private func buildHeadgear() {
        let ink = skin.ink
        switch skin.headgear {
        case .cowl:
            for x: CGFloat in [-8, 8] {
                let path = CGMutablePath()
                path.move(to: CGPoint(x: x - 3, y: 6))
                path.addLine(to: CGPoint(x: x, y: 21))
                path.addLine(to: CGPoint(x: x + 3, y: 6))
                path.closeSubpath()
                let ear = SKShapeNode(path: path)
                ear.fillColor = ink; ear.strokeColor = ink
                headNode.addChild(ear)
            }
            let jaw = SKShapeNode(rect: CGRect(x: -6, y: -8, width: 13, height: 5), cornerRadius: 2)
            jaw.fillColor = SKColor(srgbRed: 0.8, green: 0.62, blue: 0.43, alpha: 1)
            jaw.strokeColor = .clear; jaw.zPosition = 2
            headNode.addChild(jaw)
        case .greenHair, .jester:
            for x: CGFloat in [-8, 0, 8] {
                let tuft = SKShapeNode(ellipseOf: CGSize(width: 9, height: 9))
                tuft.position = CGPoint(x: x, y: 10 + (x == 0 ? 2 : 0))
                tuft.fillColor = skin.headgear == .greenHair ? SKColor(srgbRed: 0.2, green: 0.8, blue: 0.18, alpha: 1) : (x < 0 ? Palette.red : ink)
                tuft.strokeColor = ink; tuft.zPosition = 2
                headNode.addChild(tuft)
            }
            let smile = SKShapeNode(rect: CGRect(x: -6, y: -7, width: 13, height: 2), cornerRadius: 1)
            smile.fillColor = Palette.red; smile.strokeColor = .clear; smile.zPosition = 3
            headNode.addChild(smile)
        case .respirator:
            let mask = SKShapeNode(rectOf: CGSize(width: 10, height: 11), cornerRadius: 2)
            mask.position.y = -3; mask.fillColor = SKColor(white: 0.5, alpha: 1)
            mask.strokeColor = ink; mask.zPosition = 3
            headNode.addChild(mask)
            for x: CGFloat in [-3, 0, 3] {
                let vent = SKShapeNode(rectOf: CGSize(width: 1, height: 7))
                vent.position = CGPoint(x: x, y: -3); vent.fillColor = ink
                vent.strokeColor = .clear; vent.zPosition = 4
                headNode.addChild(vent)
            }
        case .helmet:
            let helmet = SKShapeNode(rect: CGRect(x: -13, y: -9, width: 26, height: 23), cornerRadius: 9)
            helmet.fillColor = skin.suitDark
            helmet.strokeColor = skin.ink
            helmet.lineWidth = 1.5
            helmet.zPosition = 0.4
            headNode.addChild(helmet)
        case .skull:
            let jaw = SKShapeNode(rect: CGRect(x: -5, y: -9, width: 10, height: 5), cornerRadius: 1)
            jaw.fillColor = .white
            jaw.strokeColor = skin.ink
            jaw.lineWidth = 1
            jaw.zPosition = 2
            headNode.addChild(jaw)
            let teeth = CGMutablePath()
            for x in [-3, 0, 3] {
                teeth.move(to: CGPoint(x: x, y: -8))
                teeth.addLine(to: CGPoint(x: x, y: -5))
            }
            let lines = SKShapeNode(path: teeth)
            lines.strokeColor = skin.ink
            lines.lineWidth = 0.8
            lines.zPosition = 3
            headNode.addChild(lines)
        case .none:
            break
        case .hat:
            let crown = SKShapeNode(ellipseOf: CGSize(width: 26, height: 17))
            crown.fillColor = SKColor(srgbRed: 0.40, green: 0.20, blue: 0.58, alpha: 1)
            crown.strokeColor = ink
            crown.lineWidth = 1.4
            crown.position = CGPoint(x: -1, y: 8)
            crown.zPosition = 2
            headNode.addChild(crown)
        case .horns:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -9, y: 6))
            path.addLine(to: CGPoint(x: -13, y: 15))
            path.addLine(to: CGPoint(x: -5, y: 8))
            path.closeSubpath()
            path.move(to: CGPoint(x: 8, y: 6))
            path.addLine(to: CGPoint(x: 12, y: 15))
            path.addLine(to: CGPoint(x: 4, y: 8))
            path.closeSubpath()
            let horns = SKShapeNode(path: path)
            horns.fillColor = SKColor(srgbRed: 0.90, green: 0.87, blue: 0.80, alpha: 1)
            horns.strokeColor = ink
            horns.lineWidth = 1.2
            horns.zPosition = 2
            headNode.addChild(horns)
        case .bowl:
            let dome = SKShapeNode(ellipseOf: CGSize(width: 30, height: 28))
            dome.fillColor = SKColor(white: 0.88, alpha: 0.34)
            dome.strokeColor = SKColor(white: 0.95, alpha: 0.85)
            dome.lineWidth = 1.2
            dome.position = CGPoint(x: -0.5, y: 1)
            dome.zPosition = 2
            headNode.addChild(dome)
        case .beak:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 8, y: 3))
            path.addLine(to: CGPoint(x: 19, y: -2))
            path.addLine(to: CGPoint(x: 8, y: -5))
            path.closeSubpath()
            let beak = SKShapeNode(path: path)
            beak.fillColor = SKColor(srgbRed: 0.82, green: 0.70, blue: 0.32, alpha: 1)
            beak.strokeColor = ink
            beak.lineWidth = 1.2
            beak.zPosition = 2
            headNode.addChild(beak)
        case .mane:
            let mane = SKShapeNode(ellipseOf: CGSize(width: 34, height: 30))
            mane.fillColor = SKColor(srgbRed: 0.30, green: 0.21, blue: 0.11, alpha: 1)
            mane.strokeColor = ink
            mane.lineWidth = 1.3
            mane.position = CGPoint(x: -1.5, y: 0.5)
            mane.zPosition = -1
            headNode.addChild(mane)
            let fringe = CGMutablePath()
            for i in 0..<5 {
                let a = CGFloat.pi * (0.12 + 0.76 * CGFloat(i) / 4)
                let px = cos(a) * 16.5 - 1.5
                let py = sin(a) * 15 + 0.5
                fringe.move(to: CGPoint(x: px, y: py))
                fringe.addLine(to: CGPoint(x: px + cos(a) * 6, y: py + sin(a) * 6))
            }
            let spikes = SKShapeNode(path: fringe)
            spikes.strokeColor = SKColor(srgbRed: 0.20, green: 0.14, blue: 0.08, alpha: 1)
            spikes.lineWidth = 3.4
            spikes.fillColor = .clear
            spikes.lineCap = .round
            spikes.zPosition = -1
            headNode.addChild(spikes)
        case .crest:
            let path = CGMutablePath()
            path.move(to: CGPoint(x: -7, y: 8))
            path.addLine(to: CGPoint(x: 0, y: 19))
            path.addLine(to: CGPoint(x: 7, y: 8))
            path.closeSubpath()
            let crest = SKShapeNode(path: path)
            crest.fillColor = SKColor(srgbRed: 0.95, green: 0.90, blue: 0.25, alpha: 1)
            crest.strokeColor = ink
            crest.lineWidth = 1.2
            crest.zPosition = 2
            headNode.addChild(crest)
        }
    }

    private func buildSwords() {
        for angle: CGFloat in [-0.55, 0.55] {
            let sword = SKNode()
            sword.position = CGPoint(x: 0, y: 7)
            sword.zRotation = angle
            sword.zPosition = 0
            let sheath = SKShapeNode(rect: CGRect(x: -1.8, y: -18, width: 3.6, height: 42), cornerRadius: 1.5)
            sheath.fillColor = skin.ink
            sheath.strokeColor = SKColor(white: 0.28, alpha: 1)
            sheath.lineWidth = 0.8
            sword.addChild(sheath)
            let grip = SKShapeNode(rect: CGRect(x: -2, y: 24, width: 4, height: 11), cornerRadius: 1)
            grip.fillColor = SKColor(white: 0.2, alpha: 1)
            grip.strokeColor = skin.ink
            sword.addChild(grip)
            let guardBar = SKShapeNode(rectOf: CGSize(width: 10, height: 2))
            guardBar.position.y = 24
            guardBar.fillColor = SKColor(white: 0.6, alpha: 1)
            guardBar.strokeColor = skin.ink
            sword.addChild(guardBar)
            upper.addChild(sword)
        }
    }

    private func buildDeadpoolSuit() {
        for x: CGFloat in [-6, 6] {
            let panel = SKShapeNode(rect: CGRect(x: x - 2, y: 2, width: 4, height: 17), cornerRadius: 1.5)
            panel.fillColor = skin.ink
            panel.strokeColor = .clear
            panel.zPosition = 5
            upper.addChild(panel)
        }
        let belt = SKShapeNode(rectOf: CGSize(width: 17, height: 4))
        belt.fillColor = SKColor(white: 0.12, alpha: 1)
        belt.strokeColor = skin.ink
        belt.zPosition = 7
        hipNode.addChild(belt)
        for x: CGFloat in [-6, 6] {
            let pouch = SKShapeNode(rectOf: CGSize(width: 4, height: 6), cornerRadius: 1)
            pouch.position = CGPoint(x: x, y: -1)
            pouch.fillColor = SKColor(srgbRed: 0.38, green: 0.23, blue: 0.14, alpha: 1)
            pouch.strokeColor = skin.ink
            pouch.zPosition = 8
            hipNode.addChild(pouch)
        }
        let buckle = SKShapeNode(circleOfRadius: 2.8)
        buckle.fillColor = skin.suit
        buckle.strokeColor = skin.ink
        buckle.lineWidth = 1
        buckle.zPosition = 9
        hipNode.addChild(buckle)
    }

    /// Vulture style wings, flapping gently.
    private func buildWings() {
        let feather = SKColor(srgbRed: 0.30, green: 0.37, blue: 0.25, alpha: 1)
        let tip = SKColor(srgbRed: 0.22, green: 0.28, blue: 0.18, alpha: 1)
        for i in 0..<2 {
            let wing = SKNode()
            wing.position = CGPoint(x: -4, y: 15)
            // swept back behind him (he faces +x, so the wings point up-left / left)
            wing.zRotation = i == 0 ? 3.90 : 4.50
            wing.zPosition = 2
            let blade = SKShapeNode(ellipseOf: CGSize(width: 44, height: 13))
            blade.fillColor = feather
            blade.strokeColor = skin.ink
            blade.lineWidth = 1.2
            blade.position = CGPoint(x: 0, y: -19)
            wing.addChild(blade)
            let feathers = CGMutablePath()
            for f in 0..<4 {
                let y = CGFloat(f) * 4.2 - 30
                feathers.move(to: CGPoint(x: 0, y: y))
                feathers.addLine(to: CGPoint(x: 17, y: y - 4.5))
            }
            let lines = SKShapeNode(path: feathers)
            lines.strokeColor = tip
            lines.lineWidth = 1.1
            lines.fillColor = .clear
            wing.addChild(lines)
            let flap = SKAction.sequence([
                .rotate(byAngle: i == 0 ? 0.26 : -0.26, duration: 0.42),
                .rotate(byAngle: i == 0 ? -0.26 : 0.26, duration: 0.42)
            ])
            wing.run(.repeatForever(flap))
            upper.addChild(wing)
        }
    }

    /// Doctor Octopus style mechanical arms sprouting from the back.
    private func buildTentacles() {
        let metal = SKColor(srgbRed: 0.74, green: 0.76, blue: 0.80, alpha: 1)
        // fan the four arms out behind him so they all read in silhouette
        let baseAngles: [CGFloat] = [1.85, 2.30, 2.78, 3.26]
        let baseHeights: [CGFloat] = [17, 14, 11, 8]
        for i in 0..<4 {
            let base = SKNode()
            base.position = CGPoint(x: -5 - CGFloat(i % 2) * 2, y: baseHeights[i])
            base.zRotation = baseAngles[i]
            base.zPosition = 3
            let seg1 = SKShapeNode(rect: CGRect(x: -1.7, y: -16, width: 3.4, height: 18), cornerRadius: 1.6)
            seg1.fillColor = metal
            seg1.strokeColor = skin.ink
            seg1.lineWidth = 1.0
            base.addChild(seg1)
            let joint = SKNode()
            joint.position = CGPoint(x: 0, y: -15)
            joint.zRotation = 0.75 - CGFloat(i) * 0.22
            base.addChild(joint)
            let seg2 = SKShapeNode(rect: CGRect(x: -1.5, y: -17, width: 3.0, height: 18), cornerRadius: 1.4)
            seg2.fillColor = metal
            seg2.strokeColor = skin.ink
            seg2.lineWidth = 1.0
            joint.addChild(seg2)
            let claw = SKShapeNode(circleOfRadius: 2.6)
            claw.fillColor = metal
            claw.strokeColor = skin.ink
            claw.lineWidth = 1.0
            claw.position = CGPoint(x: 0, y: -16)
            joint.addChild(claw)

            let sway = SKAction.sequence([
                .rotate(byAngle: 0.22, duration: 1.1 + Double(i) * 0.13),
                .rotate(byAngle: -0.22, duration: 1.1 + Double(i) * 0.13)
            ])
            base.run(.repeatForever(sway))
            upper.addChild(base)
        }
    }

    @discardableResult
    private func makeEye(size: CGSize, color: SKColor, tilt: CGFloat, at p: CGPoint, outline: CGFloat) -> SKShapeNode {
        let e = SKShapeNode(ellipseOf: size)
        e.fillColor = color
        e.strokeColor = skin.ink
        e.lineWidth = outline
        e.zPosition = 1
        e.position = p
        e.zRotation = tilt
        headNode.addChild(e)
        eyes.append(e)
        eyeHome.append(p)
        eyeSize.append(size)
        return e
    }

    // MARK: - Eyes

    /// Applies the current gaze offset and lid closure in one place so the two never
    /// fight over the eye nodes.
    private func updateEyes() {
        let openness = Swift.max(0.05, 1 - blink * 0.95)
        for i in eyes.indices {
            eyes[i].yScale = openness
            // keep the lower lid still and let the upper one come down, like a real blink
            let drop = -(eyeSize[i].height / 2) * (1 - openness)
            eyes[i].position = eyeHome[i] + eyeLook + CGPoint(x: 0, y: drop)
        }
    }

    private func webPattern() -> SKNode {
        let path = CGMutablePath()
        let c = CGPoint(x: 0, y: 1.5)
        for i in 0...6 {
            let a = CGFloat.pi * (0.10 + 0.80 * CGFloat(i) / 6)
            path.move(to: c)
            path.addLine(to: c + CGPoint.fromAngle(a, 12.0))
        }
        for ring in 1...3 {
            path.addArc(center: c, radius: CGFloat(ring) * 3.8,
                        startAngle: .pi * 0.10, endAngle: .pi * 0.90, clockwise: false)
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = skin.pattern
        shape.lineWidth = 1.0
        shape.fillColor = .clear
        shape.isAntialiased = true
        return shape
    }

    private func spiderEmblem() -> SKNode {
        let node = SKNode()
        node.position = CGPoint(x: 0, y: 9.5)
        let path = CGMutablePath()
        path.addEllipse(in: CGRect(x: -1.9, y: -4.2, width: 3.8, height: 5.4))
        for i in 0..<4 {
            let y = CGFloat(i) * 2.0 - 2.6
            path.move(to: CGPoint(x: -1.3, y: y))
            path.addLine(to: CGPoint(x: -5.6, y: y + 1.9))
            path.move(to: CGPoint(x: 1.3, y: y))
            path.addLine(to: CGPoint(x: 5.6, y: y + 1.9))
        }
        let body = SKShapeNode(path: path)
        body.strokeColor = skin.ink
        body.fillColor = skin.ink
        body.lineWidth = 0.95
        body.alpha = 0.85
        node.addChild(body)
        return node
    }

    private func makeArm(shaded: Bool) -> Limb {
        let upperLen: CGFloat = 10.5
        let foreLen: CGFloat = 10.5
        let w: CGFloat = muscular ? 10 : 6.4
        let base = shaded ? skin.limbDark : skin.limb

        let pivot = SKNode()
        let seg = SKShapeNode(rect: CGRect(x: -w / 2, y: -upperLen, width: w, height: upperLen + 2.4),
                              cornerRadius: w / 2)
        seg.fillColor = base
        seg.strokeColor = skin.ink
        seg.lineWidth = 1.3
        pivot.addChild(seg)

        let elbow = SKNode()
        elbow.position = CGPoint(x: 0, y: -upperLen)
        pivot.addChild(elbow)

        let fw = w * 0.92
        let fore = SKShapeNode(rect: CGRect(x: -fw / 2, y: -foreLen, width: fw, height: foreLen + 2.0),
                               cornerRadius: fw / 2)
        fore.fillColor = base
        fore.strokeColor = skin.ink
        fore.lineWidth = 1.3
        elbow.addChild(fore)

        let hand = SKShapeNode(circleOfRadius: muscular ? 5.8 : 3.5)
        hand.fillColor = shaded ? skin.suitDark : skin.suit
        hand.strokeColor = skin.ink
        hand.lineWidth = 1.3
        hand.position = CGPoint(x: 0, y: -foreLen)
        hand.zPosition = 1
        elbow.addChild(hand)

        let tip = SKNode()
        tip.position = CGPoint(x: 0, y: -foreLen)
        elbow.addChild(tip)

        return Limb(pivot: pivot, elbow: elbow, tip: tip, length: upperLen + foreLen)
    }

    private func makeLeg(shaded: Bool) -> Limb {
        let thigh: CGFloat = 13
        let shin: CGFloat = 13
        let w: CGFloat = muscular ? 10 : 7.2
        let base = shaded ? skin.limbDark : skin.limb

        let pivot = SKNode()
        let up = SKShapeNode(rect: CGRect(x: -w / 2, y: -thigh, width: w, height: thigh + 2.6), cornerRadius: w / 2)
        up.fillColor = muscular ? shortsColor : base
        up.strokeColor = skin.ink
        up.lineWidth = 1.3
        pivot.addChild(up)

        let knee = SKNode()
        knee.position = CGPoint(x: 0, y: -thigh)
        pivot.addChild(knee)

        let sw = w * 0.88
        let lo = SKShapeNode(rect: CGRect(x: -sw / 2, y: -shin, width: sw, height: shin + 2.2), cornerRadius: sw / 2)
        lo.fillColor = base
        lo.strokeColor = skin.ink
        lo.lineWidth = 1.3
        knee.addChild(lo)

        let foot = SKShapeNode(rect: CGRect(x: -2.2, y: -2.6, width: 10.0, height: 5.2), cornerRadius: 2.4)
        foot.fillColor = shaded ? skin.suitDark : skin.suit
        foot.strokeColor = skin.ink
        foot.lineWidth = 1.3
        foot.position = CGPoint(x: 2.4, y: -shin)
        foot.zPosition = 1
        knee.addChild(foot)

        let tip = SKNode()
        tip.position = CGPoint(x: 2.4, y: -shin)
        knee.addChild(tip)

        return Limb(pivot: pivot, elbow: knee, tip: tip, length: thigh + shin)
    }

    // MARK: - Puppeteering

    private func applyTransform() {
        root.xScale = facing * scale
        root.yScale = scale
    }

    func apply(_ p: Pose) {
        pose = p
        hipNode.position = p.hip
        hipNode.yScale = p.squash
        upper.zRotation = p.torso
        headPivot.zRotation = p.head

        armNear.pivot.zRotation = p.armNear
        armNear.elbow.zRotation = p.foreNear
        armFar.pivot.zRotation = p.armFar
        armFar.elbow.zRotation = p.foreFar

        legNear.pivot.zRotation = p.thighNear
        legNear.elbow.zRotation = p.shinNear
        legFar.pivot.zRotation = p.thighFar
        legFar.elbow.zRotation = p.shinFar
    }

    /// Eyes track a point in scene space.
    func look(at world: CGPoint) {
        guard let scene = root.scene else { return }
        let local = headPivot.convert(world, from: scene)
        let dx = local.x - headNode.position.x
        let dy = local.y - headNode.position.y
        eyeLook = CGPoint(x: clampf(dx * 0.030, -1.7, 1.7), y: clampf(dy * 0.030, -1.5, 1.5))
        updateEyes()
    }

    var nearHandWorld: CGPoint? {
        guard let scene = root.scene else { return nil }
        return armNear.tip.convert(.zero, to: scene)
    }

    /// Ankle of the near leg — used when he hangs upside down from a thread.
    var nearFootWorld: CGPoint? {
        guard let scene = root.scene else { return nil }
        return legNear.tip.convert(.zero, to: scene)
    }

    var hipWorld: CGPoint { root.position }

    var totalHeight: CGFloat { (Rig.footReach + Rig.headReach) * scale }
}
