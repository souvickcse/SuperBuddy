import SpriteKit

/// A small 1989-inspired car. All motion uses simulation time so pause and
/// headless checks follow the same arrival/boarding/drive/exit sequence.
final class Batmobile {
    enum Phase { case absent, arriving, parked, boarding, driving, exiting, departing }
    let root = SKNode()
    private(set) var phase: Phase = .absent
    private var elapsed: TimeInterval = 0
    private var destination: CGFloat = 0
    private var direction: CGFloat = 1
    private var rideRequested = false
    private var automaticIn: TimeInterval = 45
    private let wheels = [SKNode(), SKNode()]
    private let flame = SKShapeNode()
    private let canopy = SKShapeNode(ellipseOf: CGSize(width: 37, height: 18))
    private var smokeIn: TimeInterval = 0
    private var routeProgress: CGFloat = 0
    private var parkingProgress: CGFloat = 0
    private var endsVisited = 0
    private var returningToPark = false
    private(set) var drivingSurface: World.Surface = .floor
    static let boostSpeed: CGFloat = 1100

    /// A U-shaped route: down the left wall, around a smooth corner, along the
    /// floor, then up the right wall. Reversing mirrors the nose without turning
    /// the wheels away from the wall. Batman always disembarks on the floor.
    private struct WallRoute {
        let left: CGFloat, right: CGFloat, bottom: CGFloat, top: CGFloat, radius: CGFloat
        var wall: CGFloat { top - bottom - radius }
        var arc: CGFloat { radius * .pi / 2 }
        var floor: CGFloat { right - left - 2 * radius }
        var length: CGFloat { 2 * wall + 2 * arc + floor }

        init(world: World, scale: CGFloat) {
            left = world.leftX + 2 * scale
            right = world.rightX - 2 * scale
            bottom = world.floorY + 2 * scale
            top = Swift.max(bottom + 20, world.ceilY - 110 * scale)
            radius = Swift.max(1, Swift.min(220 * scale, (right - left) / 4, (top - bottom) / 2))
        }

        func floorProgress(at x: CGFloat) -> CGFloat {
            wall + arc + clampf(x - left - radius, 0, floor)
        }

        func pose(at progress: CGFloat) -> (point: CGPoint, angle: CGFloat, surface: World.Surface) {
            var s = clampf(progress, 0, length)
            if s < wall { return (CGPoint(x: left, y: top - s), -.pi / 2, .left) }
            s -= wall
            if s < arc {
                let a = .pi + s / radius
                let center = CGPoint(x: left + radius, y: bottom + radius)
                return (center + CGPoint.fromAngle(a, radius), a + .pi / 2, .left)
            }
            s -= arc
            if s < floor { return (CGPoint(x: left + radius + s, y: bottom), 0, .floor) }
            s -= floor
            if s < arc {
                let a = -.pi / 2 + s / radius
                let center = CGPoint(x: right - radius, y: bottom + radius)
                return (center + CGPoint.fromAngle(a, radius), a + .pi / 2, .right)
            }
            s -= arc
            return (CGPoint(x: right, y: bottom + radius + s), .pi / 2, .right)
        }
    }
    var active: Bool { phase != .absent }

    init() {
        root.zPosition = 104; root.isHidden = true
        let body = CGMutablePath()
        body.addLines(between: [CGPoint(x: -76, y: 10), CGPoint(x: -65, y: 27), CGPoint(x: -48, y: 24),
            CGPoint(x: -30, y: 34), CGPoint(x: -8, y: 32), CGPoint(x: 6, y: 23),
            CGPoint(x: 58, y: 21), CGPoint(x: 79, y: 12), CGPoint(x: 75, y: 6), CGPoint(x: -73, y: 6)])
        body.closeSubpath()
        let shell = SKShapeNode(path: body)
        shell.fillColor = SKColor(white: 0.055, alpha: 1)
        shell.strokeColor = SKColor(white: 0.35, alpha: 1); shell.lineWidth = 1.3
        root.addChild(shell)
        for i in 0..<2 {
            let wheel = wheels[i]
            wheel.position = CGPoint(x: i == 0 ? -48 : 48, y: 9)
            let tire = SKShapeNode(circleOfRadius: 11)
            tire.fillColor = .black; tire.strokeColor = SKColor(white: 0.4, alpha: 1)
            let hub = SKShapeNode(circleOfRadius: 5)
            hub.fillColor = SKColor(white: 0.35, alpha: 1); hub.strokeColor = .gray
            let spoke = SKShapeNode(rectOf: CGSize(width: 9, height: 1.5))
            spoke.fillColor = .white; spoke.strokeColor = .clear
            wheel.addChild(tire); wheel.addChild(hub); wheel.addChild(spoke)
            root.addChild(wheel)
        }
        canopy.position = CGPoint(x: -18, y: 29)
        canopy.fillColor = SKColor(srgbRed: 0.15, green: 0.3, blue: 0.42, alpha: 1)
        canopy.strokeColor = SKColor(white: 0.5, alpha: 1); root.addChild(canopy)
        for y: CGFloat in [19, 24] {
            let fin = CGMutablePath()
            fin.addLines(between: [CGPoint(x: -66, y: y), CGPoint(x: -78, y: y + 27), CGPoint(x: -42, y: y)])
            fin.closeSubpath()
            let node = SKShapeNode(path: fin)
            node.fillColor = SKColor(white: 0.08, alpha: 1); node.strokeColor = SKColor(white: 0.3, alpha: 1)
            root.addChild(node)
        }
        let headlight = SKShapeNode(ellipseOf: CGSize(width: 6, height: 4))
        headlight.position = CGPoint(x: 71, y: 15)
        headlight.fillColor = SKColor(srgbRed: 1, green: 0.92, blue: 0.6, alpha: 1)
        headlight.strokeColor = .clear; headlight.glowWidth = 2; root.addChild(headlight)
        let beam = CGMutablePath()
        beam.addLines(between: [CGPoint(x: 74, y: 15), CGPoint(x: 125, y: 25), CGPoint(x: 125, y: 5)])
        beam.closeSubpath()
        let light = SKShapeNode(path: beam)
        light.fillColor = SKColor(white: 1, alpha: 0.08); light.strokeColor = .clear; root.addChild(light)
        let fire = CGMutablePath()
        fire.addLines(between: [CGPoint(x: -76, y: 10), CGPoint(x: -112, y: 15), CGPoint(x: -76, y: 20)])
        fire.closeSubpath(); flame.path = fire
        flame.fillColor = SKColor(srgbRed: 1, green: 0.5, blue: 0.1, alpha: 1)
        flame.strokeColor = .yellow; root.addChild(flame)
    }

    @discardableResult
    func summon(world: World, scene: SKScene, buddy: Buddy, drive: Bool = false) -> Bool {
        guard buddy.character == .batman, !buddy.inBattle, !buddy.paused,
              buddy.grounded, buddy.surface == .floor, buddy.currentState != .grabbed else { return false }
        if active {
            if drive { rideRequested = true; if phase == .parked { transition(.boarding) } }
            return true
        }
        if root.parent == nil { scene.addChild(root) }
        root.setScale(buddy.scale)
        root.zRotation = 0
        drivingSurface = .floor
        returningToPark = false
        endsVisited = 0
        direction = buddy.pos.x < world.bounds.midX ? 1 : -1
        root.xScale = buddy.scale * direction
        root.position = CGPoint(x: direction > 0 ? world.leftX - 160 : world.rightX + 160, y: world.floorY + 2 * buddy.scale)
        let route = WallRoute(world: world, scale: buddy.scale)
        destination = clampf(buddy.pos.x, route.left + route.radius, route.right - route.radius)
        root.isHidden = false; rideRequested = drive
        transition(.arriving)
        return true
    }

    private func transition(_ phase: Phase) { self.phase = phase; elapsed = 0 }

    func cancel(world: World, buddy: Buddy) {
        if buddy.inVehicle { buddy.leaveVehicle(world, at: root.position.x) }
        phase = .absent; root.isHidden = true
        root.zRotation = 0; drivingSurface = .floor
        root.removeFromParent(); automaticIn = Double(randf(35, 70))
    }

    func dismiss(world: World, buddy: Buddy) {
        guard active else { return }
        if phase == .driving {
            returningToPark = true
            direction = parkingProgress >= routeProgress ? 1 : -1
            return
        }
        if buddy.inVehicle { buddy.leaveVehicle(world, at: root.position.x) }
        rideRequested = false; transition(.departing)
    }

    func update(dt: TimeInterval, world: World, scene: SKScene, buddy: Buddy, automatic: Bool = true) {
        guard !buddy.paused else { return }
        if buddy.character != .batman || buddy.inBattle {
            if active { cancel(world: world, buddy: buddy) }
            return
        }
        if !active {
            if automatic {
                automaticIn -= dt
                if automaticIn <= 0, summon(world: world, scene: scene, buddy: buddy, drive: true) {
                    automaticIn = Double(randf(35, 70))
                }
            }
            return
        }
        elapsed += dt
        let speed: CGFloat = phase == .driving ? Self.boostSpeed : 330
        let stride = CGFloat(dt) * speed
        let moving = phase == .arriving || phase == .driving || phase == .departing
        flame.isHidden = phase != .driving && phase != .departing
        flame.yScale = 0.8 + 0.2 * sin(CGFloat(elapsed) * 30)
        canopy.yScale = phase == .boarding || phase == .exiting ? 0.45 : 1
        flame.xScale = phase == .driving ? 1.65 : 1
        if moving { for wheel in wheels { wheel.zRotation -= CGFloat(dt) * speed / (11 * buddy.scale) * direction } }
        smokeIn -= dt
        if moving, smokeIn <= 0 {
            smokeIn = 0.15
            FX.dust(at: root.position + CGPoint(x: -direction * 72 * buddy.scale, y: 8 * buddy.scale).rotated(by: root.zRotation), in: scene, count: 1, power: 0.3)
        }
        switch phase {
        case .arriving:
            let dx = destination - root.position.x
            if abs(dx) < stride + 1 {
                root.position.x = destination; transition(rideRequested ? .boarding : .parked)
                FX.dust(at: root.position, in: scene, count: 5, power: 0.5)
            } else { root.position.x += (dx < 0 ? -1 : 1) * stride }
        case .parked:
            if elapsed > 14 { transition(.departing) }
        case .boarding:
            let dx = root.position.x - buddy.pos.x
            if abs(dx) > 5 {
                buddy.facing = dx < 0 ? -1 : 1; buddy.rig.facing = buddy.facing
                buddy.vehicleControl(at: CGPoint(x: buddy.pos.x + (dx < 0 ? -1 : 1) * Swift.min(abs(dx), CGFloat(dt) * 150),
                                                y: world.floorY + buddy.reach), seated: false)
                elapsed = 0
            } else {
                buddy.vehicleControl(at: CGPoint(x: root.position.x, y: world.floorY + buddy.reach), seated: elapsed > 0.25)
                if elapsed > 0.7 {
                    let route = WallRoute(world: world, scale: buddy.scale)
                    routeProgress = route.floorProgress(at: root.position.x)
                    parkingProgress = routeProgress
                    direction = root.position.x < world.bounds.midX ? 1 : -1
                    endsVisited = 0; returningToPark = false
                    transition(.driving)
                }
            }
        case .driving:
            let route = WallRoute(world: world, scale: buddy.scale)
            if returningToPark {
                let distance = parkingProgress - routeProgress
                direction = distance >= 0 ? 1 : -1
                routeProgress += direction * Swift.min(stride, abs(distance))
                if abs(distance) <= stride { transition(.exiting) }
            } else {
                var remaining = stride
                // Consume overshoot at a wall's upper turnaround, even on a slow frame.
                while remaining > 0 {
                    let untilEnd = direction > 0 ? route.length - routeProgress : routeProgress
                    let travel = Swift.min(remaining, Swift.max(0, untilEnd))
                    routeProgress += direction * travel
                    remaining -= travel
                    if travel >= untilEnd {
                        direction = -direction
                        endsVisited += 1
                        if endsVisited >= 2 {
                            returningToPark = true
                            break
                        }
                    } else { break }
                }
            }
            let pose = route.pose(at: routeProgress)
            root.position = pose.point
            root.zRotation = pose.angle
            root.xScale = buddy.scale * direction
            drivingSurface = pose.surface
            buddy.vehicleControl(at: pose.point, seated: true)
        case .exiting:
            root.zRotation = 0; drivingSurface = .floor
            if elapsed > 0.5 {
                buddy.leaveVehicle(world, at: root.position.x - direction * 80 * buddy.scale)
                transition(.departing)
            }
        case .departing:
            root.position.x += direction * stride * 1.4
            if root.position.x < world.leftX - 180 || root.position.x > world.rightX + 180 { cancel(world: world, buddy: buddy) }
        case .absent: break
        }
    }
}
