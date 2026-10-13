import AppKit
import SpriteKit

/// The buddy: a small kinematic character with its own gravity, four walkable surfaces
/// (screen bottom, top and both sides), a web-swinging rope, and mouse interactions.
final class Buddy {

    enum State: Equatable {
        case stand, walk, run, jump, fall, swing, hang, zip, webBlast, pistolShot, punch, grabbed, dance, heroLand, recover

        var isAirborne: Bool { self == .jump || self == .fall || self == .swing || self == .hang || self == .zip }
    }

    // MARK: Tuning

    var gravity: CGFloat = 2350
    var walkSpeed: CGFloat = 96
    var runSpeed: CGFloat = 258
    var jumpSpeed: CGFloat = 950
    var speedScale: CGFloat = 1
    var paused = false
    var scale: CGFloat = 0.9 { didSet { rig.scale = scale } }

    // MARK: Rig + simulation

    private(set) var rig = Rig()
    private(set) var character: BuddyCharacter = .spider

    /// Replace the artwork without disturbing physics, the rope, or an active battle.
    func selectCharacter(_ character: BuddyCharacter) {
        guard self.character != character else { return }
        let old = rig
        let parent = old.root.parent
        let replacement = Rig(skin: character.skin)
        replacement.scale = scale
        replacement.facing = old.facing
        replacement.blink = old.blink
        replacement.apply(currentPose)
        replacement.root.position = old.root.position
        replacement.root.zRotation = old.root.zRotation
        old.root.removeFromParent()
        parent?.addChild(replacement.root)
        rig = replacement
        self.character = character
        webShotPending = false
        if character == .deadpool, state.isAirborne || surface != .floor || state == .webBlast {
            surface = .floor
            up = CGPoint(x: 0, y: 1)
            grounded = false
            vel = CGPoint(x: 0, y: -120)
            enter(.fall)
        }
    }
    private(set) var state: State = .stand
    /// True while the pose being played is a crawl stance (never upright on a wall).
    private(set) var crawlingNow = false
    private(set) var pos = CGPoint.zero
    private(set) var vel = CGPoint.zero
    private(set) var up = CGPoint(x: 0, y: 1)
    private(set) var surface: World.Surface = .floor
    private(set) var grounded = true
    var facing: CGFloat = 1

    private var weaponEffectIndex = 0
    private var walkingSlashIn: TimeInterval = Double(randf(6, 14))
    private var resumeWalkAfterSlash = false
    private var stateTime: TimeInterval = 0
    private var stateDuration: TimeInterval = 1
    private var animTime: TimeInterval = 0
    private var currentPose = Pose.stand
    private var tilt: CGFloat = 0
    private var shakeMag: CGFloat = 0

    // web
    private var anchor = CGPoint.zero
    private var ropeLength: CGFloat = 120
    private var hangInverted = false
    private var zipStart = CGPoint.zero
    private var zipEnd = CGPoint.zero
    private var zipArc: CGFloat = 0
    private var zipDuration: TimeInterval = 0.6
    private var ceilingRestFlip = false
    private var blastTarget = CGPoint.zero
    /// While a villain is around the fight director drives him instead of his own AI.
    var inBattle = false
    private var ropeMin: CGFloat = 90
    private var webShotPending = false
    /// Ground contact is ignored for a moment after shooting a web, otherwise the
    /// buddy would "land" on the edge it is still standing on.
    private var noLandBefore: TimeInterval = 0

    // mouse
    private var pressing = false
    private var isGrabbed = false
    private var dragStart = CGPoint.zero
    private var lastDragPoint = CGPoint.zero
    private var lastDragTime: TimeInterval = 0
    private var dragMoved: CGFloat = 0
    private var grabOffset = CGPoint.zero
    private var dragVelocity = CGPoint.zero
    private var forceHeroLand = false

    /// Cursor in scene space, used for eye tracking.
    var cursor = CGPoint.zero

    var reach: CGFloat { rig.scale * Rig.footReach }

    /// Which way he must be drawn: his walking direction on the ground, or the way he
    /// is actually travelling while airborne or being carried.
    var visualFacing: CGFloat {
        var drift: CGPoint?
        switch state {
        case .jump, .fall:
            drift = vel
        case .grabbed:
            drift = dragVelocity
        default:
            drift = nil
        }
        if let d = drift {
            let local = d.rotated(by: -tilt)
            if abs(local.x) > 45 { return local.x < 0 ? -1 : 1 }
        }
        return facing
    }

    // MARK: Setup

    func place(_ world: World) {
        surface = .floor
        up = world.up(for: .floor)
        pos = CGPoint(x: world.bounds.midX, y: world.floorY + reach)
        vel = .zero
        grounded = true
        tilt = 0
        enter(.stand)
    }

    func keepInside(_ world: World) {
        if grounded {
            pos = world.snap(pos, to: surface)
        } else {
            pos.x = clampf(pos.x, world.leftX + 6, world.rightX - 6)
            pos.y = clampf(pos.y, world.floorY + 6, world.ceilY - 6)
        }
    }

    // MARK: Frame

    func update(dt: TimeInterval, world: World, scene: SKScene, web: WebLine) {
        let cdt = CGFloat(dt)
        if !paused {
            animTime += dt
            stateTime += dt
            step(cdt, dt, world, scene)
            updateTilt(cdt, world)
            updateBlink(dt)
        }

        let target = targetPose()
        currentPose = Pose.blend(currentPose, target, blendRate(dt, paused ? 4 : 16))
        rig.apply(currentPose)
        rig.showWeapons(sword: character == .deadpool && state == .punch,
                        pistol: character == .deadpool && state == .pistolShot)
        rig.look(at: cursor)

        let jitter = shakeMag > 0.05
            ? CGPoint(x: randf(-1, 1), y: randf(-1, 1)) * shakeMag
            : .zero
        rig.root.position = pos + jitter
        rig.root.zRotation = tilt

        // The drawn character has to be mirrored to match the way he is actually
        // travelling, otherwise he moonwalks.
        let look = visualFacing
        if rig.facing != look { rig.facing = look }

        updateWeb(dt: dt, web: web, scene: scene)

        if shakeMag > 0 {
            shakeMag *= CGFloat(pow(0.015, Swift.max(0, dt)))
            if shakeMag < 0.06 { shakeMag = 0 }
        }
    }

    private func updateWeb(dt: TimeInterval, web: WebLine, scene: SKScene) {
        guard character == .spider else {
            webShotPending = false
            if web.phase != .idle { web.release() }
            return
        }
        let gripping = (state == .hang && hangInverted) ? rig.nearFootWorld : rig.nearHandWorld
        if webShotPending {
            webShotPending = false
            let from = gripping ?? pos
            web.shoot(from: from, to: anchor)
            FX.text("THWIP!", at: from + CGPoint(x: 0, y: 16), in: scene)
        }
        if state == .swing || state == .hang || state == .zip || state == .webBlast {
            web.update(dt: dt, hand: gripping, anchor: anchor)
        } else if web.phase != .idle {
            web.release()
        }
    }

    // MARK: State machine

    func enter(_ s: State) {
        if s != .punch && s != .walk { resumeWalkAfterSlash = false }
        state = s
        stateTime = 0
        weaponEffectIndex = 0
        switch s {
        case .stand:
            // a proper wait: he stops, looks around and breathes for a few seconds
            let clinging = (surface != .floor)
            stateDuration = clinging ? Double(randf(1.8, 5.4)) : Double(randf(1.4, 4.6))
        case .walk:
            // on a wall keep going: he is usually on his way up to the ceiling
            let onWall = (surface == .left || surface == .right)
            stateDuration = onWall ? Double(randf(11.0, 20.0)) : Double(randf(1.8, 4.6))
        case .run: stateDuration = Double(randf(1.0, 2.2))
        case .dance: stateDuration = Motion.danceDuration
        case .hang: stateDuration = Double(randf(hangInverted ? 2.4 : 1.5, hangInverted ? 4.6 : 2.9))
        case .zip: stateDuration = 2.0
        case .webBlast: stateDuration = 0.52
        case .pistolShot: stateDuration = Motion.pistolDuration
        case .punch: stateDuration = character == .deadpool ? Motion.katanaDuration : 0.50
        case .swing: stateDuration = Double(randf(1.6, 2.6))
        case .heroLand: stateDuration = 0.9
        case .recover: stateDuration = 0.45
        default: stateDuration = 1.0
        }
    }

    private func step(_ dt: CGFloat, _ rawDT: TimeInterval, _ world: World, _ scene: SKScene) {
        switch state {
        case .stand:
            if stateTime > stateDuration { decide(world, scene) }
        case .walk, .run:
            stepGrounded(dt, world, scene)
        case .jump, .fall:
            stepAir(dt, world, scene)
        case .swing:
            stepSwing(dt, world, scene)
        case .hang:
            stepHang(dt, world, scene)
        case .zip:
            stepZip(dt, world, scene)
        case .grabbed:
            break
        case .webBlast, .pistolShot, .punch:
            if character == .deadpool, !paused {
                let cues: [Double] = state == .pistolShot ? [0.48, 1.0] : [0.52, 0.9]
                while weaponEffectIndex < cues.count, stateTime >= cues[weaponEffectIndex] {
                    if state == .pistolShot {
                        FX.pistolFlash(at: rig.nearHandWorld ?? pos, facing: facing, in: scene)
                    } else if state == .punch {
                        FX.swordArc(at: pos + CGPoint(x: facing * 15, y: 20), facing: facing, in: scene)
                    }
                    weaponEffectIndex += 1
                }
            }
            if stateTime > stateDuration {
                if state == .punch && resumeWalkAfterSlash && !inBattle {
                    resumeWalkAfterSlash = false
                    enter(.walk)
                } else {
                    resumeWalkAfterSlash = false
                    enter(.stand)
                }
            }
        case .dance:
            if stateTime > stateDuration { enter(.stand) }
        case .heroLand:
            if stateTime > stateDuration { enter(.recover) }
        case .recover:
            if stateTime > stateDuration { decide(world, scene) }
        }
    }

    // MARK: Grounded locomotion (walks along whichever edge it is standing on)

    private func stepGrounded(_ dt: CGFloat, _ world: World, _ scene: SKScene) {
        if character == .deadpool, state == .walk, !inBattle, !pressing {
            walkingSlashIn -= TimeInterval(dt)
            if walkingSlashIn <= 0 {
                walkingSlashIn = Double(randf(6, 14))
                resumeWalkAfterSlash = true
                enter(.punch)
                return
            }
        }
        // crawling up a wall is a long trip, so he covers ground a little quicker there
        let climbing = (surface == .left || surface == .right || surface == .ceiling)
        let base = state == .run ? runSpeed : (climbing ? walkSpeed * 1.55 : walkSpeed)
        let speed = base * speedScale
        let t = world.tangent(for: surface)
        pos = pos + t * (facing * speed * dt)

        // once in a while he changes his mind about climbing a wall, but never mid-climb
        let probe = pos + t * (facing * 42)
        if surface == .floor, world.cornerTransition(probe, from: surface) != nil,
           stateTime > 0.5, chance(0.012) {
            facing = -facing
        }

        if character == .deadpool, world.cornerTransition(pos, from: .floor) != nil {
            facing = -facing
        }
        if character == .spider, let next = world.cornerTransition(pos, from: surface) {
            surface = next
            up = world.up(for: next)
            FX.dust(at: world.contactPoint(for: pos, on: next), in: scene, count: 3, power: 0.35)
        }

        pos = world.snap(pos, to: surface)
        up = world.up(for: surface)
        vel = .zero
        grounded = true

        if stateTime > stateDuration {
            let onWall = (surface == .left || surface == .right)
            if chance(onWall ? 0.30 : 0.48) {
                enter(.stand)
            } else {
                stateDuration = Double(randf(2.0, 5.0))
                if chance(0.3) { facing = -facing }
            }
        }
    }

    // MARK: Airborne

    private func stepAir(_ dt: CGFloat, _ world: World, _ scene: SKScene) {
        vel.y -= gravity * dt
        vel.x *= (1 - 0.30 * dt)
        pos = pos + vel * dt
        pos.x = clampf(pos.x, world.leftX + 5, world.rightX - 5)
        if character == .deadpool, pos.y > world.ceilY - reach {
            pos.y = world.ceilY - reach
            vel.y = Swift.min(0, vel.y)
        }
        if state == .jump && vel.y <= 0 { enter(.fall) }
        if tryLand(world, scene: scene) { return }
        // safety net: never leave the desktop
        if pos.y < world.floorY - 200 { pos.y = world.floorY + reach; _ = tryLand(world, scene: scene) }
    }

    @discardableResult
    private func tryLand(_ world: World, scene: SKScene) -> Bool {
        let r = world.reach
        var hit: World.Surface?
        if pos.y - world.floorY <= r { hit = .floor }
        else if character == .spider, world.ceilY - pos.y <= r { hit = .ceiling }
        else if character == .spider, pos.x - world.leftX <= r { hit = .left }
        else if character == .spider, world.rightX - pos.x <= r { hit = .right }
        guard let s = hit else { return false }
        let impact = vel.length
        land(on: s, world: world, scene: scene, impact: impact)
        return true
    }

    private func land(on s: World.Surface, world: World, scene: SKScene, impact: CGFloat) {
        // keep travelling the way he arrived instead of reversing on touchdown
        let incoming = vel
        surface = s
        up = world.up(for: s)
        pos = world.snap(pos, to: s)
        let along = world.tangent(for: s)
        let travel = incoming.x * along.x + incoming.y * along.y
        if abs(travel) > 70 { facing = travel < 0 ? -1 : 1 }
        vel = .zero
        grounded = true
        let contact = world.contactPoint(for: pos, on: s)

        if forceHeroLand || (impact > 620 && chance(0.75)) {
            forceHeroLand = false
            enter(.heroLand)
            blinkNow()
            tilt = atan2(-up.x, up.y)
            shakeMag = Swift.min(10, 3.5 + impact / 260)
            FX.superheroImpact(at: contact, in: scene, power: Swift.min(1.7, 0.7 + impact / 900))
            FX.text("TA-DA!", at: pos + CGPoint(x: 0, y: world.up(for: s).y * 40), in: scene)
        } else if impact > 210 {
            enter(.recover)
            FX.sharpLanding(at: contact, in: scene, power: Swift.min(1.1, impact / 700))
        } else {
            enter(.stand)
        }
    }

    // MARK: Web swinging

    private func stepSwing(_ dt: CGFloat, _ world: World, _ scene: SKScene) {
        if stateTime < 0.13 { return }   // still shooting the web out

        // web-zip: reel the line in, which is what actually carries the buddy
        // up and across the desktop
        if ropeLength > ropeMin {
            ropeLength = Swift.max(ropeMin, ropeLength - 430 * dt)
        }

        vel.y -= gravity * dt
        pos = pos + vel * dt
        pos.x = clampf(pos.x, world.leftX + 4, world.rightX - 4)
        pos.y = Swift.min(pos.y, world.ceilY - 6)

        let d = pos - anchor
        let len = d.length
        if len > 0.01 {
            let n = d / len
            if len > ropeLength {
                pos = anchor + n * ropeLength
                vel = vel - n * vel.dot(n)
            }
        }
        if (pos - anchor).length < 20 {
            endSwing(world, scene, boost: false)
            return
        }
        up = (anchor - pos).normalized

        if stateTime > noLandBefore, tryLand(world, scene: scene) { return }

        let rising = vel.y > 60
        if stateTime > stateDuration || (stateTime > 0.95 && rising && stateTime > noLandBefore) {
            endSwing(world, scene, boost: true)
        }
    }

    private func endSwing(_ world: World, _ scene: SKScene, boost: Bool) {
        grounded = false
        if boost {
            let dir = vel.normalized
            vel = vel + dir * 120
            FX.hitSpark(at: rig.nearHandWorld ?? pos, in: scene)
        }
        enter(.fall)
    }

    private func stepHang(_ dt: CGFloat, _ world: World, _ scene: SKScene) {
        if stateTime < 0.13 { return }
        if ropeLength > ropeMin {
            ropeLength = Swift.max(ropeMin, ropeLength - 240 * dt)
        }
        vel.y -= gravity * dt
        vel.x *= (1 - 0.8 * dt)
        pos = pos + vel * dt

        let d = pos - anchor
        let len = d.length
        if len > 0.01 {
            let n = d / len
            if len > ropeLength {
                pos = anchor + n * ropeLength
                vel = vel - n * vel.dot(n) * 0.85
            }
        }
        let toAnchor = (anchor - pos).normalized
        up = hangInverted ? toAnchor * -1 : toAnchor
        if stateTime > noLandBefore, tryLand(world, scene: scene) { return }
        if stateTime > stateDuration { endSwing(world, scene, boost: false) }
    }

    // MARK: Web zip (shoot a line and get pulled straight to an edge)

    private func stepZip(_ dt: CGFloat, _ world: World, _ scene: SKScene) {
        let shoot: TimeInterval = 0.10
        up = (anchor - pos).normalized
        if stateTime < shoot { return }

        let progress = clampf(CGFloat((stateTime - shoot) / Swift.max(0.01, zipDuration)), 0, 1)
        let eased = smoothstep(progress)
        let travel = zipEnd - zipStart
        let bend = travel.normalized.perpendicular
        pos = lerp(zipStart, zipEnd, eased) + bend * (zipArc * sin(.pi * progress))
        up = (anchor - pos).normalized

        if stateTime > noLandBefore, tryLand(world, scene: scene) { return }
        if progress >= 1 {
            let (s, _) = world.nearestSurface(to: pos)
            land(on: s, world: world, scene: scene, impact: 0)
        }
    }

    // MARK: Decisions

    private func decide(_ world: World, _ scene: SKScene) {
        guard !paused, !isGrabbed, !inBattle else { return }
        if character == .deadpool {
            let roll = randf(0, 1)
            if roll < 0.28 { enter(.walk) }
            else if roll < 0.40 { enter(.run) }
            else if roll < 0.55 { jump(world) }
            else if roll < 0.70 { dance(scene) }
            else { enter(.stand) }
            return
        }
        let r = Double.random(in: 0..<1)
        if surface == .floor {
            if r < 0.20 { enter(.walk) }
            else if r < 0.30 { enter(.run) }
            else if r < 0.42 { jump(world) }
            else if r < 0.54 { swing(world, scene) }
            else if r < 0.66 { webZip(world, scene) }
            else if r < 0.78 { dance(scene) }
            else { enter(.stand) }
        } else if surface == .ceiling {
            // he is already at the top: no web swinging up here, just crawling,
            // resting (including hanging upside down from a thread) or letting go
            if r < 0.30 { enter(.walk) }
            else if r < 0.62 {
                // resting up here alternates: crouched on the ceiling, then dangling
                // from a thread by the ankle — so both get seen
                ceilingRestFlip.toggle()
                if ceilingRestFlip { enter(.stand) } else { hangUpsideDown(world, scene) }
            }
            else if r < 0.82 { hangUpsideDown(world, scene) }
            else if r < 0.92 { jump(world) }
            else { dropOff(world) }
        } else {
            // on a side wall: crawl, rest, or web himself off it
            if r < 0.26 { enter(.walk) }
            else if r < 0.56 { enter(.stand) }              // cling and rest, in crawl stance
            else if r < 0.68 { hangFromWeb(world, scene) }
            else if r < 0.80 { jump(world) }
            else if r < 0.92 { swing(world, scene) }
            else { dropOff(world) }
        }
    }

    // MARK: Actions (also used by the menu bar)

    func jump(_ world: World) {
        let t = world.tangent(for: surface)
        if character == .deadpool {
            vel = CGPoint(x: facing * randf(180, 320), y: jumpSpeed * 0.78)
            grounded = false
            forceHeroLand = true
            enter(.jump)
            return
        }
        vel = world.up(for: surface) * randf(jumpSpeed * 0.78, jumpSpeed) + t * (facing * randf(10, 170))
        grounded = false
        forceHeroLand = false
        enter(.jump)
    }

    func swing(_ world: World, _ scene: SKScene, toward target: CGPoint? = nil) {
        guard character == .spider else { return }
        let tx = target?.x ?? (pos.x + facing * randf(90, 300))
        var a = CGPoint(x: clampf(tx, world.leftX + 26, world.rightX - 26), y: world.ceilY - 3)
        if a.distance(to: pos) < 90 {
            a = CGPoint(x: clampf(pos.x - facing * randf(140, 280), world.leftX + 26, world.rightX - 26),
                        y: world.ceilY - 3)
        }
        anchor = a
        let dist = anchor.distance(to: pos)
        ropeLength = dist
        ropeMin = Swift.max(110, dist * 0.45)
        grounded = false
        forceHeroLand = false

        // Leap off the edge you are standing on and let the line catch you:
        // the launch has to be tangential to the rope, otherwise the line never
        // goes taut and there is no swing at all.
        let radial = (anchor - pos).normalized
        let tangent = radial.perpendicular * facing
        vel = vel * 0.3 + tangent * randf(370, 470) + radial * 60
        pos = pos + world.up(for: surface) * 8
        noLandBefore = 0.34
        webShotPending = true
        enter(.swing)
        if target != nil { FX.webSplat(at: anchor, in: scene) }
    }

    func hangFromWeb(_ world: World, _ scene: SKScene) {
        guard character == .spider else { return }
        // dangling only reads well with the web above you and space below
        guard surface != .floor else {
            swing(world, scene)
            return
        }
        let a = CGPoint(x: clampf(pos.x, world.leftX + 30, world.rightX - 30), y: world.ceilY - 3)
        // step off a side wall so the line is carrying the whole weight
        let start = (surface == .left || surface == .right)
            ? pos + world.up(for: surface) * 46
            : pos
        let dist = a.distance(to: start)
        anchor = a
        pos = start
        ropeLength = Swift.max(72, dist)
        ropeMin = ropeLength
        hangInverted = false
        grounded = false
        forceHeroLand = false
        vel = CGPoint(x: randf(-60, 60), y: 10)
        noLandBefore = 0.30
        webShotPending = true
        enter(.hang)
    }

    /// Resting on the ceiling: a short thread catches him by the ankle and he hangs
    /// head-down just below it.
    func hangUpsideDown(_ world: World, _ scene: SKScene) {
        guard character == .spider else { return }
        let a = CGPoint(x: clampf(pos.x + randf(-40, 40), world.leftX + 30, world.rightX - 30),
                        y: world.ceilY - 2)
        anchor = a
        ropeLength = Swift.max(34, reach + randf(3, 15))
        ropeMin = ropeLength
        hangInverted = true
        grounded = false
        forceHeroLand = false
        vel = .zero
        noLandBefore = 0.22
        webShotPending = true
        enter(.hang)
        blinkNow()
    }

    /// Shoot a line at the ceiling (or the nearest wall) and get pulled straight
    /// there, arriving in a crawl stance.
    func webZip(_ world: World, _ scene: SKScene, toCeiling: Bool? = nil) {
        guard character == .spider else { return }
        let goUp = toCeiling ?? chance(0.62)
        let target: CGPoint
        let attach: CGPoint
        if goUp {
            let tx = clampf(pos.x + randf(-280, 280), world.leftX + 60, world.rightX - 60)
            target = CGPoint(x: tx, y: world.ceilY - world.reach)
            attach = CGPoint(x: tx, y: world.ceilY - 2)
        } else {
            let goLeft = pos.x < world.bounds.midX
            let x = goLeft ? world.leftX + world.reach : world.rightX - world.reach
            let y = clampf(pos.y + randf(30, 280),
                           world.floorY + world.reach + 20, world.ceilY - world.reach)
            target = CGPoint(x: x, y: y)
            attach = CGPoint(x: goLeft ? world.leftX + 2 : world.rightX - 2, y: y)
        }
        guard (target - pos).length > 70 else {
            jump(world)
            return
        }
        zipStart = pos
        zipEnd = target
        zipArc = randf(-36, 36)
        zipDuration = Double(clampf((target - pos).length / 900, 0.34, 0.95))
        anchor = attach
        vel = .zero
        grounded = false
        forceHeroLand = false
        hangInverted = false
        webShotPending = true
        noLandBefore = 0.18
        enter(.zip)
    }

    func dropOff(_ world: World) {
        forceHeroLand = false
        grounded = false
        vel = CGPoint(x: facing * randf(-40, 40), y: -60)
        enter(.fall)
    }

    func dance(_ scene: SKScene) {
        if isGrabbed { return }
        forceHeroLand = false
        enter(.dance)
        blinkNow()
        FX.notes(at: pos + CGPoint(x: 0, y: reach + 8), in: scene, count: 5)
        FX.hitSpark(at: pos, in: scene)
    }

    func comeTo(_ point: CGPoint, world: World, scene: SKScene) {
        isGrabbed = false
        pressing = false
        pos = CGPoint(x: clampf(point.x, world.leftX + reach, world.rightX - reach),
                      y: clampf(point.y, world.floorY + reach + 20, world.ceilY - reach))
        vel = CGPoint(x: 0, y: -40)
        grounded = false
        forceHeroLand = true
        enter(.fall)
    }

    func celebrate(_ scene: SKScene) {
        enter(.walk)
        FX.notes(at: pos + CGPoint(x: 0, y: reach + 10), in: scene, count: 3)
    }

    // MARK: Poses

    /// On a wall or the ceiling he is never upright: standing, resting, dancing and
    /// landing are all expressed as a crawl stance there.
    private func targetPose() -> Pose {
        let t = CGFloat(animTime)
        let onFloor = surface == .floor
        crawlingNow = false

        switch state {
        case .stand:
            if onFloor { return character == .deadpool ? Motion.deadpoolIdle(t) : Motion.idle(t) }
            crawlingNow = true
            return Motion.crawlRest(t)
        case .walk:
            if onFloor { return character == .deadpool ? Motion.deadpoolWalk(t) : Motion.walk(t, speed: 1) }
            crawlingNow = true
            return Motion.crawl(t, speed: 1)
        case .run:
            if onFloor { return Motion.run(t, speed: 1) }
            crawlingNow = true
            return Motion.crawl(t, speed: 1.45)
        case .jump, .fall:
            return character == .deadpool ? Motion.deadpoolAir(t) : Motion.air(t, vertical: vel.y)
        case .swing:
            return stateTime < 0.14 ? Motion.shootWeb(CGFloat(stateTime)) : Motion.swing(t, speed: vel.length / 420)
        case .hang:
            return hangInverted ? Motion.hangUpsideDown(t) : Motion.hang(t)
        case .zip:
            return Motion.webZip(t)
        case .webBlast:
            return Motion.shootWeb(Swift.min(CGFloat(stateTime), 0.22))
        case .pistolShot:
            return Motion.deadpoolShoot(CGFloat(stateTime / Motion.pistolDuration))
        case .punch:
            if character == .deadpool { return Motion.deadpoolSlash(CGFloat(stateTime / Motion.katanaDuration)) }
            return Motion.punch(clampf(CGFloat(stateTime / 0.5), 0, 1))
        case .grabbed:
            return Motion.flail(t, drift: dragVelocity)
        case .dance:
            if onFloor { return character == .deadpool ? Motion.deadpoolDance(CGFloat(stateTime)) : Motion.dance(CGFloat(stateTime)) }
            crawlingNow = true
            return Motion.crawlRest(t)
        case .heroLand:
            if onFloor { return character == .deadpool ? Motion.deadpoolLanding(CGFloat(stateTime / 0.9)) : Motion.heroLanding(CGFloat(stateTime / 0.9)) }
            crawlingNow = true
            var p = Motion.crawlRest(t)
            p.squash = lerp(0.84, 1, clampf(CGFloat(stateTime / 0.28), 0, 1))
            return p
        case .recover:
            if onFloor { return Pose.stand }
            crawlingNow = true
            return Motion.crawlRest(t)
        }
    }

    private func updateTilt(_ dt: CGFloat, _ world: World) {
        if character == .deadpool, state == .jump || state == .fall {
            // One somersault on the ascent; settle upright before touching down.
            tilt = vel.y > 0 ? -CGFloat(stateTime) * 8 * facing : lerpAngle(tilt, 0, blendRate(Double(dt), 12))
            return
        }
        var target: CGFloat
        switch state {
        case .swing, .hang, .zip:
            target = atan2(-up.x, up.y)
        case .jump, .fall:
            let (s, dist) = world.nearestSurface(to: pos)
            if dist < world.reach + 24, s == .left || s == .right {
                let u = world.up(for: s)
                target = atan2(-u.x, u.y)
            } else {
                target = 0
            }
        case .grabbed:
            target = closingAngle(vel)
        default:
            let u = world.up(for: surface)
            target = atan2(-u.x, u.y)
        }
        let rate: Double = (state == .jump || state == .fall) ? 7 : 13
        tilt = lerpAngle(tilt, target, blendRate(Double(dt), rate))
    }

    private func closingAngle(_ v: CGPoint) -> CGFloat {
        if v.length < 40 { return 0 }
        return clampf(-v.x * 0.00022, -0.4, 0.4)
    }

    // MARK: Blinking

    private var blinkCountdown: TimeInterval = 1.3
    private var blinkPhase: TimeInterval = -1

    /// Force a blink right now (surprise, impact, being put down).
    func blinkNow() {
        blinkPhase = 0
    }

    /// A human blink: the lid snaps shut, holds for a moment and opens a little slower.
    /// Blinks land every few seconds, with the occasional double blink.
    private func updateBlink(_ dt: TimeInterval) {
        let close: TimeInterval = 0.075
        let hold: TimeInterval = 0.025
        let open: TimeInterval = 0.115
        let total = close + hold + open

        if blinkPhase < 0 {
            blinkCountdown -= dt
            guard blinkCountdown <= 0 else { return }
            blinkPhase = 0
        }

        blinkPhase += dt
        let t = blinkPhase
        var closure: CGFloat
        if t < close {
            closure = CGFloat(t / close)
        } else if t < close + hold {
            closure = 1
        } else if t < total {
            closure = CGFloat(1 - (t - close - hold) / open)
        } else {
            closure = 0
            blinkPhase = -1
            blinkCountdown = chance(0.12) ? 0.22 : Double(randf(2.1, 6.4))
        }
        rig.blink = clampf(closure, 0, 1)
    }

    // MARK: Battle

    /// Turn to look at something (used by the fight director).
    func face(toward x: CGFloat) {
        if abs(x - pos.x) > 22 { facing = x < pos.x ? -1 : 1 }
    }

    /// Snap a web line at a point — used to shoot at a villain.
    func pistolShot(at point: CGPoint, scene: SKScene) {
        guard character == .deadpool, grounded, currentState != .grabbed else { return }
        face(toward: point.x)
        enter(.pistolShot)
        FX.hitSpark(at: rig.nearHandWorld ?? pos, in: scene)
        FX.text("PEW!", at: pos + CGPoint(x: 0, y: reach + 16), in: scene)
    }

    func webBlast(at point: CGPoint, scene: SKScene) {
        guard character == .spider else { return }
        guard currentState != .grabbed else { return }
        blastTarget = point
        anchor = point
        webShotPending = true
        enter(.webBlast)
    }

    /// Move towards an opponent (used by the fight director to close the distance).
    func approach(_ x: CGFloat, scene: SKScene, run fast: Bool = false) {
        guard grounded, currentState != .grabbed, surface == .floor else { return }
        facing = x < pos.x ? -1 : 1
        enter(fast ? .run : .walk)
        stateDuration = 0.6
    }

    func punchAt(_ point: CGPoint, scene: SKScene) {
        guard currentState != .grabbed else { return }
        facing = point.x < pos.x ? -1 : 1
        enter(.punch)
    }

    /// Knocked back by a punch.
    func takeHit(from point: CGPoint, scene: SKScene) {
        guard currentState != .grabbed else { return }
        let away = (pos - point).normalized
        vel = away * 300 + CGPoint(x: 0, y: 330)
        grounded = false
        forceHeroLand = false
        shakeMag = Swift.max(shakeMag, 4.5)
        FX.hitSpark(at: pos, in: scene)
        blinkNow()
        enter(.fall)
    }

    /// Hop clear of an incoming punch.
    func dodge(from point: CGPoint, scene: SKScene) {
        guard grounded else { return }
        let away = (pos - point).normalized
        vel = away * 300 + CGPoint(x: 0, y: 480)
        grounded = false
        forceHeroLand = false
        FX.dust(at: pos - up * reach, in: scene, count: 4, power: 0.5)
        blinkNow()
        enter(.jump)
    }

    // MARK: Mouse interaction

    /// Body-shaped hit area, rotated with the buddy, so poking his head or grabbing a
    /// leg works no matter which surface he is crawling on.
    func hitTest(_ p: CGPoint) -> Bool {
        let d = p - pos
        let local = d.rotated(by: -tilt)
        let lx = local.x * facing
        let ly = local.y
        let halfWidth = 19 * scale
        let bottom = -(Rig.footReach + 8) * scale
        let top = (Rig.headReach + 6) * scale
        return abs(lx) <= halfWidth && ly >= bottom && ly <= top
    }

    /// True when the overlay window should accept mouse events (everything else is
    /// handed back to the app underneath).
    func isInteractive(withCursor p: CGPoint) -> Bool {
        pressing || isGrabbed || state == .grabbed || hitTest(p)
    }

    func mouseDown(at p: CGPoint, clickCount: Int, scene: SKScene) {
        guard hitTest(p) else { return }
        pressing = true
        isGrabbed = false
        dragMoved = 0
        dragStart = p
        lastDragPoint = p
        lastDragTime = 0
        dragVelocity = .zero
        grabOffset = pos - p
        if clickCount >= 2 {
            // double click: an instant bit of showing off
            dance(scene)
        }
    }

    func mouseDragged(to p: CGPoint, time: TimeInterval) {
        guard pressing else { return }
        dragMoved = Swift.max(dragMoved, dragStart.distance(to: p))
        if !isGrabbed && dragMoved > 5 {
            isGrabbed = true
            forceHeroLand = false
            enter(.grabbed)
        }
        guard isGrabbed else { return }
        let newPos = p + grabOffset
        if lastDragTime > 0 {
            let dt = Swift.max(1.0 / 480.0, time - lastDragTime)
            dragVelocity = (newPos - pos) / CGFloat(dt)
            dragVelocity = CGPoint(x: clampf(dragVelocity.x, -2600, 2600),
                                   y: clampf(dragVelocity.y, -2600, 2600))
            vel = dragVelocity * 0.3
        }
        pos = newPos
        lastDragTime = time
        lastDragPoint = p
    }

    func mouseUp(at p: CGPoint, scene: SKScene) {
        guard pressing else { return }
        pressing = false
        if isGrabbed {
            isGrabbed = false
            vel = CGPoint(x: clampf(dragVelocity.x * 0.28, -1200, 1200),
                          y: clampf(dragVelocity.y * 0.28, -1500, 1500))
            if abs(vel.x) < 60 { vel.x = facing * randf(40, 140) }
            if vel.y > -80 { vel.y = -120 }
            forceHeroLand = true          // releasing a drag always ends in a superhero landing
            blinkNow()
            grounded = false
            enter(.fall)
            FX.text("WHEEE!", at: pos + CGPoint(x: 0, y: 24), in: scene)
        } else {
            dance(scene)
        }
        dragVelocity = .zero
    }

    func cancelDrag() {
        pressing = false
        isGrabbed = false
    }

    // MARK: Misc

    func setScale(_ s: CGFloat) {
        scale = s
    }

    var contactPoint: CGPoint { pos - up * reach }

    var currentState: State { state }
    var isHangingUpsideDown: Bool { state == .hang && hangInverted }
    var isGrabbedNow: Bool { isGrabbed }
}
