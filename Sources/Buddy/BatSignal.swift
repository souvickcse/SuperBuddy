import SpriteKit

/// Bat-Signal spotlight and a flock that converges on Batman, conceals him,
/// then reveals him. Explicit simulation time keeps pause and cleanup reliable.
final class BatSignal {
    enum Phase { case idle, signaling, gathering, camouflaged, revealing, dispersing }
    let root = SKNode()
    private(set) var phase: Phase = .idle
    private(set) var elapsed: TimeInterval = 0
    private let beam = SKShapeNode()
    private let light = SKShapeNode(circleOfRadius: 1)
    private let emblem = SKShapeNode(path: Rig.batShape())
    private let projector = SKShapeNode(rectOf: CGSize(width: 20, height: 12), cornerRadius: 3)
    private let haze = SKShapeNode(ellipseOf: CGSize(width: 60, height: 84))
    private let bats: [SKShapeNode] = (0..<42).map { _ in SKShapeNode(path: Rig.batShape()) }
    private var sky = CGPoint.zero
    private var lamp = CGPoint.zero
    private var automaticIn: TimeInterval = Double(randf(20, 45))
    var active: Bool { phase != .idle }

    init() {
        root.zPosition = 110
        beam.fillColor = SKColor(srgbRed: 1, green: 0.86, blue: 0.45, alpha: 0.12)
        beam.strokeColor = .clear
        light.fillColor = SKColor(srgbRed: 1, green: 0.86, blue: 0.48, alpha: 0.75)
        light.strokeColor = SKColor(srgbRed: 1, green: 0.95, blue: 0.7, alpha: 0.8)
        light.lineWidth = 2; light.glowWidth = 5
        emblem.fillColor = Palette.ink; emblem.strokeColor = .clear
        light.addChild(emblem)
        projector.fillColor = SKColor(white: 0.12, alpha: 1)
        projector.strokeColor = SKColor(white: 0.55, alpha: 1)
        haze.fillColor = SKColor(white: 0.02, alpha: 0.45)
        haze.strokeColor = .clear
        root.addChild(beam); root.addChild(light); root.addChild(projector); root.addChild(haze)
        for (i, bat) in bats.enumerated() {
            bat.fillColor = SKColor(white: 0.025 + CGFloat(i % 3) * 0.025, alpha: 1)
            bat.strokeColor = SKColor(white: 0.4, alpha: 0.8)
            bat.lineWidth = 0.6
            // Front and rear layers surround the whole silhouette.
            bat.zPosition = i % 4 == 0 ? -18 : 4
            root.addChild(bat)
        }
    }

    @discardableResult
    func start(world: World, scene: SKScene, buddy: Buddy) -> Bool {
        guard !active, buddy.character == .batman, !buddy.inVehicle, !buddy.paused,
              buddy.currentState != .grabbed else { return false }
        sky = CGPoint(x: clampf(buddy.pos.x + 130, world.leftX + 80, world.rightX - 80),
                      y: world.floorY + world.height * 0.73)
        lamp = CGPoint(x: world.clampX(buddy.pos.x - 75), y: world.floorY + 8)
        automaticIn = Double(randf(20, 45))
        elapsed = 0; phase = .signaling
        root.isHidden = false
        scene.addChild(root)
        draw(world: world, buddy: buddy)
        return true
    }

    func cancel(buddy: Buddy) {
        buddy.rig.root.alpha = 1
        automaticIn = Double(randf(20, 45))
        elapsed = 0; phase = .idle
        root.removeFromParent()
    }

    func update(dt: TimeInterval, world: World, buddy: Buddy,
                scene: SKScene? = nil, automatic: Bool = false) {
        if !active {
            // Count only normal patrol/idle time, so other actions get to finish.
            guard automatic, let scene, buddy.character == .batman, !buddy.paused,
                  !buddy.inBattle, !buddy.inVehicle, buddy.grounded,
                  [.stand, .walk, .run].contains(buddy.currentState) else { return }
            automaticIn -= Swift.max(0, dt)
            if automaticIn <= 0, buddy.canPerformAutomaticAction,
               start(world: world, scene: scene, buddy: buddy) { buddy.didPerformAutomaticAction() }
            return
        }
        guard buddy.character == .batman, !buddy.inVehicle, buddy.currentState != .grabbed else {
            cancel(buddy: buddy); return
        }
        guard !buddy.paused else { return }
        elapsed += Swift.max(0, dt)
        if elapsed >= 6.8 { cancel(buddy: buddy); return }
        if elapsed < 0.8 { phase = .signaling }
        else if elapsed < 2.4 { phase = .gathering }
        else if elapsed < 4.4 { phase = .camouflaged }
        else if elapsed < 5.4 { phase = .revealing }
        else { phase = .dispersing }
        draw(world: world, buddy: buddy)
    }

    private func draw(world: World, buddy: Buddy) {
        let t = CGFloat(elapsed)
        let scale = buddy.rig.scale
        let center = buddy.pos + CGPoint(x: 0, y: 14 * scale)
        let conceal = smoothstep((t - 1.6) / 0.8) * (1 - smoothstep((t - 4.4) / 1.0))
        buddy.rig.root.alpha = 1 - conceal * 0.96
        let signalAlpha = smoothstep(t / 0.5) * (1 - smoothstep((t - 4.4) / 1.2))
        let radius = Swift.min(62 * scale, world.width * 0.1)
        light.position = sky
        light.xScale = radius; light.yScale = radius * 0.74
        // Child scales compensate for the unit circle's radius so the bat fills the light.
        emblem.setScale(0.063)
        light.alpha = signalAlpha
        projector.position = lamp
        projector.alpha = signalAlpha
        let path = CGMutablePath()
        path.move(to: lamp)
        path.addLine(to: sky + CGPoint(x: -radius, y: 0))
        path.addQuadCurve(to: sky + CGPoint(x: radius, y: 0), control: sky + CGPoint(x: 0, y: -radius * 0.3))
        path.closeSubpath(); beam.path = path; beam.alpha = signalAlpha
        haze.position = center; haze.setScale(scale); haze.alpha = conceal * 0.8
        let gather = smoothstep((t - 0.8) / 1.6)
        let scatter = smoothstep((t - 5.1) / 1.7)
        for (i, bat) in bats.enumerated() {
            let f = CGFloat(i)
            let angle = f * 2.39996 + t * (i % 2 == 0 ? 4.8 : -3.7)
            let tightness = lerp(62, 21, conceal)
            let orbit = CGPoint(x: cos(angle) * (tightness + CGFloat(i % 5) * 2),
                                y: sin(angle * 1.1) * (conceal > 0.5 ? 32 : 44)) * scale
            let start = CGPoint(x: i % 2 == 0 ? world.leftX - 40 : world.rightX + 40,
                                y: world.floorY + world.height * (0.4 + CGFloat(i % 7) * 0.08))
            let cluster = center + orbit
            let end = CGPoint(x: i % 2 == 0 ? world.leftX - 100 : world.rightX + 100,
                              y: world.ceilY + 80 + CGFloat(i % 8) * 16)
            bat.position = lerp(lerp(start, cluster, gather), end, scatter)
            let size = scale * (0.42 + CGFloat(i % 5) * 0.12)
            bat.xScale = size
            bat.yScale = size * (0.25 + 0.75 * abs(sin(t * 18 + f * 1.7)))
            bat.zRotation = sin(angle) * 0.4
            bat.alpha = smoothstep((t - 0.6) / 0.4) * (1 - scatter)
        }
    }
}
