import AppKit
import SpriteKit

/// A villain: walks in, squares up to the buddy and fights according to his archetype.
///
///  * `brawler` — closes in and trades punches
///  * `charger` — backs off, winds up, then barrels in at speed
///  * `flyer`   — hovers overhead and dives
///  * `shooter` — keeps its distance and fires
final class Villain {

    enum State: Equatable {
        case entrance, land, approach, windUp, attack, recover, stagger, stuck,
             hover, dive, climb, defeated, flee, gone
    }

    let skin: Skin
    let rig: Rig

    private(set) var pos = CGPoint.zero
    private(set) var state: State = .entrance
    private(set) var health = 5
    private(set) var telegraphing = false
    var facing: CGFloat = 1
    var scale: CGFloat = 0.9

    private var vel = CGPoint.zero
    private var stateTime: TimeInterval = 0
    private var stateDuration: TimeInterval = 1
    private var animTime: TimeInterval = 0
    private var currentPose = Pose.stand
    private var grounded = false
    private var swungThisAttack = false
    private var firedThisAttack = false

    var reach: CGFloat { rig.scale * Rig.footReach }
    var isFinished: Bool { state == .gone }
    var isOut: Bool { state == .defeated || state == .flee || state == .gone }
    var isWindingUp: Bool { telegraphing }
    var isStuck: Bool { state == .stuck }
    var isFlying: Bool { state == .hover || state == .dive || state == .climb }

    init(skin: Skin) {
        self.skin = skin
        self.rig = Rig(skin: skin)
    }

    // MARK: Per-archetype tuning

    private var engageRange: CGFloat {
        switch skin.archetype {
        case .shooter: return 335
        case .charger: return 305
        case .flyer: return 78
        case .brawler: return 104
        }
    }

    private var windUpTime: TimeInterval {
        switch skin.archetype {
        case .charger: return 0.78
        case .shooter: return 0.48
        default: return 0.42
        }
    }

    private var attackTime: TimeInterval {
        switch skin.archetype {
        case .charger: return 0.56
        case .shooter: return 0.34
        default: return 0.30
        }
    }

    private var attackSpeed: CGFloat {
        switch skin.archetype {
        case .charger: return 740 * skin.fightSpeed
        case .brawler: return 445 * skin.fightSpeed
        default: return 0
        }
    }

    private var hitRange: CGFloat {
        skin.archetype == .charger ? 98 : 84
    }

    private var hoverHeight: CGFloat { 165 }

    // MARK: Setup

    func spawn(world: World, near: CGFloat, fromLeft: Bool, scale: CGFloat) {
        self.scale = scale * skin.bodyScale
        rig.scale = self.scale
        rig.root.zPosition = 95          // just behind the buddy
        facing = fromLeft ? 1 : -1
        health = 5
        let x = clampf(near + (fromLeft ? -430 : 430), world.leftX + 90, world.rightX - 90)
        pos = CGPoint(x: x, y: world.ceilY + 70)
        vel = CGPoint(x: 0, y: -140)
        grounded = false
        enter(.entrance)
    }

    func enter(_ s: State) {
        state = s
        stateTime = 0
        telegraphing = false
        switch s {
        case .entrance: stateDuration = 2.0
        case .land: stateDuration = 0.55
        case .approach: stateDuration = Double(randf(1.6, 3.4))
        case .windUp:
            stateDuration = windUpTime
            telegraphing = true
        case .attack:
            stateDuration = attackTime
            swungThisAttack = false
            firedThisAttack = false
        case .recover: stateDuration = 0.45
        case .stagger: stateDuration = 0.55
        case .stuck: stateDuration = 0.95
        case .hover: stateDuration = 1.4
        case .dive:
            stateDuration = 0.7
            swungThisAttack = false
        case .climb: stateDuration = 1.0
        case .defeated: stateDuration = 0.9
        case .flee: stateDuration = 6.0
        case .gone: stateDuration = 1.0
        }
    }

    // MARK: Frame

    /// Returns true on the frame an attack connects.
    @discardableResult
    func update(dt: TimeInterval, world: World, scene: SKScene, opponent: CGPoint) -> Bool {
        let cdt = CGFloat(dt)
        stateTime += dt
        animTime += dt
        var connected = false

        if !isOut, abs(opponent.x - pos.x) > 26 {
            facing = opponent.x < pos.x ? -1 : 1
        }

        let flying = (skin.archetype == .flyer) && !isOut && isFlying

        if flying {
            fly(dt: cdt, world: world, opponent: opponent)
        } else if !grounded {
            vel.y -= 2350 * cdt
            pos = pos + vel * cdt
            if pos.y <= world.floorY + reach {
                pos.y = world.floorY + reach
                vel = .zero
                grounded = true
                if state == .entrance {
                    FX.sharpLanding(at: CGPoint(x: pos.x, y: world.floorY), in: scene, power: 0.9)
                    enter(.land)
                }
            }
        }

        // keep him on screen, except while he is legging it off the edge
        if state != .flee, state != .gone {
            pos.x = clampf(pos.x, world.leftX + reach, world.rightX - reach)
        }

        switch state {
        case .windUp:
            if stateTime > stateDuration { enter(.attack) }
        case .entrance, .defeated, .gone:
            if state == .defeated, stateTime > stateDuration { enter(.flee) }

        case .land:
            if stateTime > stateDuration { enter(nextApproach()) }

        case .approach:
            let dx = opponent.x - pos.x
            if abs(dx) < engageRange {
                enter(.windUp)
            } else {
                let dir: CGFloat = dx < 0 ? -1 : 1
                let closing = abs(dx)
                let speed = (closing > 420 ? 245 : (closing > 200 ? 165 : 120)) * skin.fightSpeed
                pos.x = clampf(pos.x + dir * speed * cdt, world.leftX + reach, world.rightX - reach)
                if stateTime > stateDuration { enter(.windUp) }
            }

        case .attack:
            switch skin.archetype {
            case .shooter:
                // stands still and fires a bolt across the gap
                if !firedThisAttack, stateTime > stateDuration * 0.35 {
                    firedThisAttack = true
                    fireBolt(scene: scene, at: opponent)
                }
                if !swungThisAttack, stateTime > stateDuration * 0.72 {
                    swungThisAttack = true
                    connected = true
                }
            default:
                pos.x = clampf(pos.x + facing * attackSpeed * cdt,
                               world.leftX + reach, world.rightX - reach)
                if !swungThisAttack, abs(opponent.x - pos.x) < hitRange, stateTime > stateDuration * 0.2 {
                    swungThisAttack = true
                    connected = true
                }
            }
            if stateTime > stateDuration { enter(.recover) }

        case .recover:
            if stateTime > stateDuration { enter(nextApproach()) }

        case .stagger:
            pos.x = clampf(pos.x + facing * -150 * cdt, world.leftX + reach, world.rightX - reach)
            if stateTime > stateDuration { enter(nextApproach()) }

        case .stuck:
            if stateTime > stateDuration { enter(nextApproach()) }

        case .hover:
            // drift in above the buddy, then drop on him
            if abs(opponent.x - pos.x) < 120 || stateTime > stateDuration {
                enter(.dive)
            }

        case .dive:
            if !swungThisAttack, abs(opponent.x - pos.x) < 96, pos.y < opponent.y + 96 {
                swungThisAttack = true
                connected = true
            }
            if stateTime > stateDuration { enter(.climb) }

        case .climb:
            if stateTime > stateDuration { enter(.hover) }

        case .flee:
            let dir: CGFloat = opponent.x < pos.x ? 1 : -1
            pos.x = pos.x + dir * 260 * cdt
            if pos.x < world.leftX - 90 || pos.x > world.rightX + 90 { enter(.gone) }
        }

        // ---- pose + transform
        let target = targetPose()
        currentPose = Pose.blend(currentPose, target, blendRate(dt, 15))
        rig.apply(currentPose)
        rig.animateCostume(time: CGFloat(animTime), gliding: false)
        rig.facing = facing
        rig.root.position = pos + (skin.costume == .harley && state == .approach ? CGPoint(x: 0, y: abs(sin(CGFloat(animTime) * 12)) * 5) : .zero)
        rig.root.zRotation = flightTilt()
        return connected
    }

    /// The first state after landing or recovering depends on the archetype.
    private func nextApproach() -> State {
        (skin.archetype == .flyer) ? .hover : .approach
    }

    /// Flyers ignore gravity: the state machine owns their altitude.
    private func fly(dt: CGFloat, world: World, opponent: CGPoint) {
        let cruise = world.floorY + reach + hoverHeight
        switch state {
        case .hover:
            pos.y += (cruise - pos.y) * Swift.min(1, 3.2 * dt)
            let dx = opponent.x - pos.x
            if abs(dx) > 110 {
                let dir: CGFloat = dx < 0 ? -1 : 1
                pos.x = clampf(pos.x + dir * 175 * skin.fightSpeed * dt,
                               world.leftX + reach, world.rightX - reach)
            }
        case .dive:
            let dir: CGFloat = opponent.x < pos.x ? -1 : 1
            pos.x = clampf(pos.x + dir * 330 * dt, world.leftX + reach, world.rightX - reach)
            pos.y = Swift.max(pos.y - 560 * dt, world.floorY + reach)
        case .climb:
            pos.y = Swift.min(pos.y + 380 * dt, world.ceilY - reach)
        default:
            break
        }
    }

    /// Bank the body along the direction of travel while flying.
    private func flightTilt() -> CGFloat {
        guard isFlying else { return 0 }
        switch state {
        case .dive: return -0.55
        case .climb: return 0.35
        default: return 0
        }
    }

    private func fireBolt(scene: SKScene, at target: CGPoint) {
        let from = CGPoint(x: pos.x + facing * reach * 0.8, y: pos.y + reach * 0.5)
        let bolt = SKShapeNode(circleOfRadius: 5)
        bolt.fillColor = SKColor(srgbRed: 1.0, green: 0.95, blue: 0.45, alpha: 1)
        bolt.strokeColor = SKColor(srgbRed: 0.75, green: 0.95, blue: 0.4, alpha: 1)
        bolt.lineWidth = 2
        bolt.glowWidth = 3
        if skin.costume == .freeze {
            bolt.fillColor = .cyan; bolt.strokeColor = .white
        } else if skin.costume == .joker {
            bolt.fillColor = SKColor(srgbRed: 0.3, green: 0.9, blue: 0.1, alpha: 1)
            bolt.strokeColor = .purple
            let fuse = SKShapeNode(rect: CGRect(x: -1, y: 4, width: 2, height: 5))
            fuse.fillColor = .orange; fuse.strokeColor = .clear; bolt.addChild(fuse)
        }
        bolt.position = from
        bolt.zPosition = 88
        scene.addChild(bolt)
        let travel = CGPoint(x: target.x, y: target.y + reach * 0.4) - from
        let steps = 3
        var actions: [SKAction] = []
        for i in 1...steps {
            let p = from + travel * (CGFloat(i) / CGFloat(steps))
            actions.append(.move(to: p, duration: 0.07))
        }
        bolt.run(.sequence(actions + [.fadeOut(withDuration: 0.10), .removeFromParent()]))
    }

    // MARK: Damage

    /// Returns true when this hit finishes him.
    @discardableResult
    func takeHit(from point: CGPoint, scene: SKScene, webbed: Bool = false) -> Bool {
        guard !isOut else { return false }
        health -= 1
        FX.hitSpark(at: CGPoint(x: pos.x, y: pos.y + reach * 0.6), in: scene)
        if health <= 0 {
            enter(.defeated)
            FX.superheroImpact(at: CGPoint(x: pos.x, y: pos.y - reach), in: scene, power: 1.2)
            return true
        }
        if webbed {
            // pinned in place — this is the buddy's chance to close in and swing
            vel = .zero
            grounded = true
            enter(.stuck)
        } else {
            let away: CGFloat = pos.x < point.x ? -1 : 1
            vel = CGPoint(x: away * 80, y: 70)
            grounded = false
            enter(.stagger)
        }
        return false
    }

    func flee(_ world: World) {
        guard !isFinished else { return }
        enter(.flee)
    }

    func remove() {
        rig.root.removeAllActions()
        rig.root.removeFromParent()
    }

    // MARK: Poses

    private func targetPose() -> Pose {
        switch state {
        case .entrance, .land:
            return Motion.heroLanding(clampf(CGFloat(stateTime / 0.55), 0, 1))
        case .approach:
            return Motion.walk(CGFloat(animTime), speed: 1.15)
        case .windUp:
            if skin.costume == .harley { return Motion.deadpoolSlash(CGFloat(stateTime / stateDuration) * 0.2) }
            return Motion.punch(clampf(CGFloat(stateTime / stateDuration) * 0.32, 0, 1))
        case .attack:
            if skin.costume == .harley { return Motion.deadpoolSlash(0.2 + CGFloat(stateTime / stateDuration) * 0.5) }
            if skin.archetype == .shooter {
                return Motion.shootWeb(Swift.min(CGFloat(stateTime), 0.2))
            }
            return Motion.punch(clampf(0.32 + CGFloat(stateTime / stateDuration) * 0.48, 0, 1))
        case .recover:
            return Motion.idle(CGFloat(animTime))
        case .stagger:
            return Motion.stagger(CGFloat(stateTime / stateDuration))
        case .stuck:
            return Motion.webbed(CGFloat(stateTime))
        case .hover:
            return Motion.air(CGFloat(animTime), vertical: 0)
        case .dive:
            return Motion.air(CGFloat(animTime), vertical: -900)
        case .climb:
            return Motion.air(CGFloat(animTime), vertical: 700)
        case .defeated:
            return Motion.defeated(CGFloat(stateTime))
        case .flee:
            return Motion.run(CGFloat(animTime), speed: 1.25)
        case .gone:
            return Motion.defeated(1)
        }
    }
}
