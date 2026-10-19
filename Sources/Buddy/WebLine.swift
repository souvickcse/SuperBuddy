import AppKit
import SpriteKit

/// The web strand the buddy shoots. Lives in scene space, not in the rig,
/// so the line can be drawn between the hand and any anchor point.
final class WebLine: SKNode {
    enum Phase { case idle, shooting, attached }

    private(set) var phase: Phase = .idle
    private let glow = SKShapeNode()
    private let core = SKShapeNode()
    private let splat = SKShapeNode()

    private var cable = false
    private var shootT: CGFloat = 0
    private let shootDuration: CGFloat = 0.12
    private var shootTo = CGPoint.zero
    private var tipPoint = CGPoint.zero

    init(zPos: CGFloat = 90) {
        super.init()
        zPosition = zPos
        glow.strokeColor = SKColor(white: 1.0, alpha: 0.22)
        glow.lineWidth = 4.6
        glow.fillColor = .clear
        glow.lineCap = .round
        core.strokeColor = Palette.thread
        core.lineWidth = 1.7
        core.fillColor = .clear
        core.lineCap = .round
        splat.strokeColor = SKColor(white: 1.0, alpha: 0.55)
        splat.lineWidth = 1.0
        splat.fillColor = .clear
        addChild(glow)
        addChild(splat)
        addChild(core)
        isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("unused") }

    func shoot(from: CGPoint, to: CGPoint, cable: Bool = false) {
        self.cable = cable
        core.strokeColor = cable ? SKColor(white: 0.65, alpha: 1) : Palette.thread
        glow.alpha = cable ? 0 : 1
        shootTo = to
        tipPoint = from
        shootT = 0
        phase = .shooting
        isHidden = false
        splat.path = nil
    }

    func attach() {
        phase = .attached
        if !cable { drawSplat(at: shootTo) }
    }

    func release() {
        phase = .idle
        isHidden = true
        splat.path = nil
        core.path = nil
        glow.path = nil
    }

    func update(dt: TimeInterval, hand: CGPoint?, anchor: CGPoint?) {
        guard phase != .idle else { return }
        let origin = hand ?? tipPoint
        switch phase {
        case .idle:
            return
        case .shooting:
            shootT += CGFloat(dt)
            let f = smoothstep(shootT / shootDuration)
            tipPoint = lerp(origin, shootTo, f)
            draw(from: origin, to: tipPoint, sag: 0)
            if f >= 1 { attach() }
        case .attached:
            draw(from: origin, to: anchor ?? shootTo, sag: 4.5)
        }
    }

    private func draw(from a: CGPoint, to b: CGPoint, sag: CGFloat) {
        let d = b - a
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let control = mid + d.normalized.perpendicular * sag
        let path = CGMutablePath()
        path.move(to: a)
        path.addQuadCurve(to: b, control: control)
        core.path = path
        glow.path = path
    }

    private func drawSplat(at p: CGPoint) {
        let path = CGMutablePath()
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * 2 * .pi
            path.move(to: p)
            path.addLine(to: p + CGPoint.fromAngle(a, 7.5))
        }
        path.addEllipse(in: CGRect(x: p.x - 3.6, y: p.y - 3.6, width: 7.2, height: 7.2))
        splat.path = path
        splat.removeAllActions()
        splat.alpha = 1
        splat.run(.sequence([.wait(forDuration: 0.25), .fadeAlpha(to: 0.35, duration: 0.5)]))
    }
}
