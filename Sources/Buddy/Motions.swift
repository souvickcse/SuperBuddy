import CoreGraphics
import Foundation

/// Every animation in the app is a pure function: time + context -> joint angles.
/// The behaviour layer just picks which motion is active and cross-fades between them.
enum Motion {

    // MARK: Idle

    static func idle(_ t: CGFloat) -> Pose {
        var p = Pose.stand
        let breath = sin(t * 2.1)
        let sway = sin(t * 1.15)
        p.hip = CGPoint(x: 0, y: 0.35 * breath)
        p.squash = 1 + 0.018 * breath
        p.torso = 0.03 + 0.035 * sway
        p.head = -0.02 - 0.05 * sway
        p.armNear = 0.20 + 0.06 * sway
        p.foreNear = 0.24 + 0.05 * breath
        p.armFar = -0.34 + 0.05 * sway
        p.foreFar = 0.22 + 0.04 * breath
        p.thighNear = 0.12
        p.shinNear = -0.10 - 0.02 * breath
        p.thighFar = -0.34
        p.shinFar = -0.18
        return p
    }

    static func deadpoolIdle(_ t: CGFloat) -> Pose {
        var p = idle(t)
        p.head = -0.16 + 0.12 * sin(t * 1.4)
        p.armNear = 0.55
        p.foreNear = 1.8
        p.armFar = -0.45
        p.foreFar = 1.4
        return p
    }

    static func deadpoolWalk(_ t: CGFloat) -> Pose {
        var p = walk(t)
        p.torso = -0.06 + 0.08 * sin(t * 4.2)
        p.head = 0.10 - 0.08 * sin(t * 4.2)
        p.foreNear += 0.35
        p.hip.x = 0.8 * sin(t * 4.2)
        return p
    }

    static func deadpoolDance(_ t: CGFloat) -> Pose {
        var p = dance(t)
        p.head += 0.18 * sin(t * 10)
        p.torso += 0.12 * sin(t * 6)
        p.armNear = 1.5 + 0.6 * sin(t * 7)
        p.foreNear = 1.4
        p.armFar = -1.5 - 0.6 * sin(t * 7)
        p.foreFar = -1.4
        return p
    }

    static func deadpoolAir(_ t: CGFloat) -> Pose {
        var p = Pose()
        p.thighNear = 1.25
        p.thighFar = 0.9
        p.shinNear = -1.8
        p.shinFar = -1.6
        p.armNear = 2.2 + 0.15 * sin(t * 8)
        p.armFar = -1.3
        p.foreNear = 1.1
        p.foreFar = 1.4
        p.head = -0.2
        return p
    }

    static let katanaDuration: TimeInterval = 1.6
    static let pistolDuration: TimeInterval = 1.8

    static func deadpoolSlash(_ t: CGFloat) -> Pose {
        var draw = deadpoolIdle(0)
        draw.armNear = 2.8; draw.foreNear = 1.1; draw.head = -0.3
        var wind = draw
        wind.armNear = 3.1; wind.foreNear = 0.2; wind.torso = -0.3
        wind.thighNear = 0.5; wind.shinNear = -0.7
        var cut = wind
        cut.armNear = 0.8; cut.foreNear = 0.1; cut.torso = 0.55
        cut.hip = CGPoint(x: 5, y: -4); cut.head = -0.2
        var reverse = cut
        reverse.armNear = -1.8; reverse.foreNear = -0.3
        reverse.torso = -0.25; reverse.hip.x = -2
        var flourish = draw
        flourish.armNear = 2.2; flourish.foreNear = -1.1
        return Pose.timeline([draw, wind, cut, reverse, flourish, deadpoolIdle(0)], t)
    }

    static func deadpoolShoot(_ t: CGFloat) -> Pose {
        var draw = deadpoolIdle(0)
        draw.armNear = 0.1; draw.foreNear = 1.0
        var aim = draw
        aim.armNear = 1.55; aim.foreNear = 0.05
        aim.armFar = 1.1; aim.foreFar = 0.5
        aim.torso = 0.1; aim.head = -0.12
        aim.thighNear = 0.45; aim.shinNear = -0.5
        var recoil = aim
        recoil.armNear = 1.85; recoil.foreNear = 0.45
        recoil.torso = -0.2; recoil.hip.x = -2
        var inspect = draw
        inspect.armNear = 1.0; inspect.foreNear = 1.7; inspect.head = 0.3
        return Pose.timeline([draw, aim, recoil, aim, recoil, aim, inspect, draw], t)
    }

    static func deadpoolLanding(_ t: CGFloat) -> Pose {
        if t < 0.35 { return heroLanding(t) }
        var p = idle(0)
        p.hip.y = -4
        p.torso = 0.5
        p.head = 0.25
        p.thighNear = 0.7
        p.shinNear = -0.85
        p.armNear = 0.3
        p.foreNear = 0.8 + 0.18 * sin(t * 22)
        p.armFar = -0.6
        p.foreFar = 1.1
        return p
    }

    // MARK: Locomotion

    static func walk(_ t: CGFloat, speed: CGFloat = 1) -> Pose {
        let p0 = t * 8.4 * speed
        let s = sin(p0)
        let c = cos(p0)
        var p = Pose()
        p.thighNear = 0.62 * s
        p.shinNear = -0.62 * Swift.max(0, -s) - 0.08
        p.thighFar = -0.62 * s
        p.shinFar = -0.62 * Swift.max(0, s) - 0.08
        p.armNear = -0.50 * s + 0.06
        p.foreNear = 0.34 + 0.20 * Swift.max(0, -s)
        p.armFar = 0.50 * s + 0.06
        p.foreFar = 0.34 + 0.20 * Swift.max(0, s)
        p.hip = CGPoint(x: 0, y: -1.5 + 1.5 * abs(c))
        p.torso = 0.09
        p.head = -0.07 + 0.05 * s
        p.squash = 1 + 0.02 * s
        return p
    }

    static func run(_ t: CGFloat, speed: CGFloat = 1) -> Pose {
        let p0 = t * 13.0 * speed
        let s = sin(p0)
        let c = cos(p0)
        var p = Pose()
        p.thighNear = 0.95 * s + 0.15
        p.shinNear = -1.05 * Swift.max(0, -s) - 0.35
        p.thighFar = -0.95 * s + 0.15
        p.shinFar = -1.05 * Swift.max(0, s) - 0.35
        p.armNear = -0.95 * s + 0.15
        p.foreNear = 1.35 + 0.25 * Swift.max(0, -s)
        p.armFar = 0.95 * s + 0.15
        p.foreFar = 1.35 + 0.25 * Swift.max(0, s)
        p.hip = CGPoint(x: 0, y: -2.6 + 2.6 * abs(c))
        p.torso = 0.34
        p.head = -0.24 + 0.08 * s
        p.squash = 1 + 0.035 * s
        return p
    }

    /// Hands-and-feet crawl used whenever the buddy is on a wall or the ceiling.
    static func crawl(_ t: CGFloat, speed: CGFloat = 1) -> Pose {
        let p0 = t * 6.2 * speed
        let s = sin(p0)
        let f = sin(p0 + .pi)
        let c = cos(p0)

        // A real crawl: he lies along the surface with his chest towards it, hips sunk
        // close to it and all four hands and feet planted on the wall.
        //
        // Legs hang from the hip, arms hang from the pitched chest, so arm angles come
        // out of the solver relative to `torso`.
        let torso: CGFloat = -1.28
        let drop: CGFloat = -14.0
        let wallY = -(Rig.footReach + drop)                 // the surface in hip space
        let planted = (Rig.footReach + drop) / 13           // cos(thigh)+cos(thigh+shin)

        var p = Pose()
        p.torso = torso
        p.head = 0.92 - 0.05 * s
        p.hip = CGPoint(x: 0, y: drop + 0.7 * abs(c))

        // arms: reach out along the wall, drag back, lift a little and reach again
        let shoulder = CGPoint(x: 5.2, y: 16).rotated(by: torso)
        let shoulderFar = CGPoint(x: -3.0, y: 16).rotated(by: torso)
        for (index, phase) in [s, f].enumerated() {
            let lift = max(0, sin(p0 + (index == 0 ? 0 : .pi)))
            let target = CGPoint(x: 30 - 15 * phase, y: wallY + 5.5 * lift)
            let (world, bend) = solveLimb(from: index == 0 ? shoulder : shoulderFar,
                                          to: target, upper: 10.5, lower: 10.5,
                                          elbowForward: true)
            if index == 0 {
                p.armNear = world - torso
                p.foreNear = bend
            } else {
                p.armFar = world - torso
                p.foreFar = bend
            }
        }

        // legs: knees drawn up, soles planted, diagonal gait
        p.thighNear = 0.58 + 0.22 * s
        p.shinNear = crawlShin(p.thighNear, planted)
        p.thighFar = 0.58 + 0.22 * f
        p.shinFar = crawlShin(p.thighFar, planted)
        p.squash = 1.0
        return p
    }

    /// Two-bone inverse kinematics in body space. Angles are measured from straight
    /// down, positive towards +x — the same convention as every other joint.
    static func solveLimb(from origin: CGPoint, to target: CGPoint,
                          upper: CGFloat, lower: CGFloat,
                          elbowForward: Bool) -> (shoulder: CGFloat, bend: CGFloat) {
        let raw = (target - origin).length
        let d = clampf(raw, abs(upper - lower) + 0.01, upper + lower - 0.01)
        let phi = atan2(target.x - origin.x, -(target.y - origin.y))
        let cosA = clampf((upper * upper + d * d - lower * lower) / (2 * upper * d), -1, 1)
        let cosB = clampf((upper * upper + lower * lower - d * d) / (2 * upper * lower), -1, 1)
        let a = acos(cosA)
        let b = acos(cosB)
        if elbowForward {
            return (phi + a, -(CGFloat.pi - b))
        } else {
            return (phi - a, CGFloat.pi - b)
        }
    }

    /// Holding position on a wall or the ceiling: still a crawl, just not going
    /// anywhere. He breathes and slowly looks up and down the surface.
    static func crawlRest(_ t: CGFloat) -> Pose {
        var p = crawl(t * 0.22, speed: 0.4)
        p.hip.y += 0.45 * sin(t * 1.7)
        p.squash = 1 + 0.015 * sin(t * 2.3)
        // slow scan: up the wall, ahead, then down — with a small settle each time
        let scan = sin(t * 0.85)
        p.head += 0.34 * scan
        p.torso += 0.06 * scan
        p.hip.y += 0.35 * scan
        return p
    }

    /// Resting on the ceiling: a short thread holds him by the ankle and he hangs
    /// head-down, arms dangling past his head.
    static func hangUpsideDown(_ t: CGFloat) -> Pose {
        let s = sin(t * 1.9)
        var p = Pose()
        // the gripping leg points straight at the thread
        p.thighNear = -0.08 + 0.05 * s
        p.shinNear = 0.14
        // the other leg is relaxed and bent
        p.thighFar = 0.34 + 0.07 * s
        p.shinFar = -0.80
        // arms hang towards the ground, which is past his head
        p.armNear = 2.78 + 0.10 * s
        p.foreNear = -0.28
        p.armFar = 2.52 - 0.10 * s
        p.foreFar = -0.38
        p.torso = 0.10 + 0.05 * s
        p.head = -0.26 + 0.06 * s
        p.hip = CGPoint(x: 0, y: 0.5)
        return p
    }

    /// Being pulled along a web line — used for the zip up to the ceiling or a wall.
    static func webZip(_ t: CGFloat) -> Pose {
        let s = sin(t * 13)
        var p = Pose()
        p.armNear = 2.92 + 0.06 * s
        p.foreNear = -0.10
        p.armFar = 2.35 - 0.12 * s
        p.foreFar = 0.45
        p.thighNear = -0.45 + 0.12 * s
        p.shinNear = -0.60
        p.thighFar = 0.18 - 0.10 * s
        p.shinFar = -0.42
        p.torso = -0.12
        p.head = 0.22
        p.hip = CGPoint(x: 0, y: 0.5)
        p.squash = 1.03
        return p
    }

    /// Knee angle that keeps the sole exactly on the surface for a given thigh angle.
    private static func crawlShin(_ thigh: CGFloat, _ planted: CGFloat) -> CGFloat {
        let c = clampf(planted - cos(thigh), -1, 1)
        return -acos(c) - thigh
    }

    // MARK: Air

    static func air(_ t: CGFloat, vertical: CGFloat) -> Pose {
        let rise = clampf(vertical / 900, -1, 1)
        let flutter = sin(t * 11)
        var p = Pose()
        p.torso = -0.14 + 0.30 * rise
        p.head = -0.10 - 0.15 * rise
        p.armNear = 2.15 + 0.55 * rise + 0.10 * flutter
        p.foreNear = 0.75 - 0.35 * rise
        p.armFar = 1.70 + 0.45 * rise - 0.10 * flutter
        p.foreFar = 0.55 - 0.25 * rise
        p.thighNear = -0.35 - 0.55 * rise + 0.10 * flutter
        p.shinNear = -1.25 + 0.35 * rise
        p.thighFar = 0.40 - 0.30 * rise - 0.10 * flutter
        p.shinFar = -0.75 + 0.20 * rise
        p.hip = .zero
        return p
    }

    /// Hanging from a web: body aligned with the rope, one arm up gripping.
    static func swing(_ t: CGFloat, speed: CGFloat) -> Pose {
        let s = sin(t * 6.5)
        var p = Pose()
        p.armNear = 2.95 + 0.10 * s
        p.foreNear = -0.12
        p.armFar = 2.05 - 0.25 * s
        p.foreFar = 0.55 + 0.20 * s
        p.thighNear = -0.55 + 0.35 * s * clampf(speed, 0.2, 2.5)
        p.shinNear = -0.85 - 0.35 * abs(s)
        p.thighFar = -0.20 - 0.30 * s
        p.shinFar = -1.25
        p.torso = -0.16 + 0.10 * s
        p.head = 0.20
        p.hip = CGPoint(x: 0, y: 0.5)
        return p
    }

    /// Dangling from a short web, waiting.
    static func hang(_ t: CGFloat) -> Pose {
        let s = sin(t * 2.6)
        var p = Pose()
        p.armNear = 2.98
        p.foreNear = -0.05
        p.armFar = 2.45 + 0.15 * s
        p.foreFar = 0.9
        p.thighNear = 0.10 * s
        p.shinNear = -0.35 - 0.10 * s
        p.thighFar = 0.05 * s
        p.shinFar = -0.45
        p.torso = 0.06 * s
        p.head = 0.10
        p.hip = CGPoint(x: 0, y: 0.4)
        return p
    }

    /// Being carried around by the mouse.
    static func flail(_ t: CGFloat, drift: CGPoint) -> Pose {
        var p = Pose()
        p.armNear = 2.45 + 0.65 * sin(t * 15)
        p.foreNear = 0.75 + 0.45 * sin(t * 15 + 0.9)
        p.armFar = 2.20 + 0.65 * sin(t * 15 + 2.1)
        p.foreFar = 0.65 + 0.45 * sin(t * 15 + 3.0)
        p.thighNear = 0.45 * sin(t * 12)
        p.shinNear = -0.75 - 0.35 * abs(sin(t * 12))
        p.thighFar = 0.45 * sin(t * 12 + 2.4)
        p.shinFar = -0.75 - 0.35 * abs(sin(t * 12 + 2.4))
        p.torso = clampf(-drift.x * 0.0009, -0.45, 0.45)
        p.head = clampf(-drift.x * 0.0006, -0.3, 0.3)
        p.hip = CGPoint(x: 0, y: 1.2)
        p.squash = 1.02
        return p
    }

    // MARK: Web shooting

    static func shootWeb(_ t: CGFloat) -> Pose {
        var p = Pose()
        let reach = smoothstep(clampf(t / 0.12, 0, 1))
        p.armNear = lerp(1.85, 1.62, reach)
        p.foreNear = lerp(0.55, 0.02, reach)
        p.armFar = -0.75
        p.foreFar = 0.85
        p.thighNear = 0.45
        p.shinNear = -0.55
        p.thighFar = -0.35
        p.shinFar = -0.60
        p.torso = 0.22
        p.head = -0.18
        p.hip = CGPoint(x: 0, y: -1.5)
        p.squash = 0.97
        return p
    }

    // MARK: Superhero landing

    private static let landingKeys: [Pose] = {
        var impact = Pose()
        impact.torso = 0.62
        impact.head = 0.52
        impact.armNear = 0.55
        impact.foreNear = 0.30
        impact.armFar = -1.35
        impact.foreFar = -0.55
        impact.thighNear = 1.45
        impact.shinNear = -1.85
        impact.thighFar = -0.85
        impact.shinFar = -1.95
        impact.hip = CGPoint(x: 1.5, y: -9.5)
        impact.squash = 0.86

        var settle = impact
        settle.torso = 0.55
        settle.hip = CGPoint(x: 1.0, y: -8.5)
        settle.squash = 0.90

        var rise = Pose()
        rise.torso = 0.30
        rise.head = 0.18
        rise.armNear = 0.35
        rise.foreNear = 0.45
        rise.armFar = -0.55
        rise.foreFar = 0.35
        rise.thighNear = 0.75
        rise.shinNear = -0.95
        rise.thighFar = -0.45
        rise.shinFar = -0.75
        rise.hip = CGPoint(x: 0, y: -4.0)
        rise.squash = 0.96

        var up = Pose.stand
        up.squash = 1.03
        up.torso = 0.05
        return [impact, settle, rise, up]
    }()

    static func heroLanding(_ t: CGFloat) -> Pose {
        Pose.timeline(landingKeys, t)
    }

    // MARK: Dance

    private static let danceKeys: [Pose] = {
        var a = Pose()
        a.armNear = 2.72; a.foreNear = 0.22
        a.armFar = 2.95; a.foreFar = 0.18
        a.thighNear = 0.35; a.shinNear = -0.45
        a.thighFar = -0.30; a.shinFar = -0.40
        a.hip = CGPoint(x: -2.2, y: 0.4); a.torso = -0.14; a.head = 0.16; a.squash = 1.02

        var b = Pose()
        b.armNear = 0.55; b.foreNear = 1.55
        b.armFar = -0.35; b.foreFar = 1.25
        b.thighNear = 0.55; b.shinNear = -0.75
        b.thighFar = -0.10; b.shinFar = -0.25
        b.hip = CGPoint(x: 2.2, y: -2.2); b.torso = 0.22; b.head = -0.20; b.squash = 0.93

        var c = Pose()
        c.armNear = 2.05; c.foreNear = 0.05
        c.armFar = -0.85; c.foreFar = 0.65
        c.thighNear = -0.45; c.shinNear = -0.35
        c.thighFar = 0.55; c.shinFar = -0.75
        c.hip = CGPoint(x: 0.5, y: 0.8); c.torso = -0.22; c.head = -0.24; c.squash = 1.0

        var d = Pose()
        d.armNear = 1.55; d.foreNear = 0.10
        d.armFar = -1.35; d.foreFar = -0.15
        d.thighNear = 0.30; d.shinNear = -0.40
        d.thighFar = -0.38; d.shinFar = -0.35
        d.hip = CGPoint(x: -0.6, y: 1.6); d.torso = 0.30; d.head = 0.30; d.squash = 1.05

        var e = Pose()
        e.armNear = 3.05; e.foreNear = 0.15
        e.armFar = 2.85; e.foreFar = 0.30
        e.thighNear = 0.20; e.shinNear = -0.30
        e.thighFar = -0.20; e.shinFar = -0.30
        e.hip = CGPoint(x: 1.4, y: 1.2); e.torso = -0.10; e.head = 0.12; e.squash = 1.06

        var f = Pose()
        f.armNear = 2.92; f.foreNear = 0.05
        f.armFar = 0.65; f.foreFar = 1.85
        f.thighNear = -0.22; f.shinNear = -0.28
        f.thighFar = 0.28; f.shinFar = -0.42
        f.hip = CGPoint(x: -1.6, y: -0.6); f.torso = -0.12; f.head = 0.22; f.squash = 0.98

        return [a, b, c, d, e, f]
    }()

    static let danceBeat: CGFloat = 0.55
    static var danceDuration: TimeInterval { Double(danceBeat) * Double(danceKeys.count) }

    static func dance(_ t: CGFloat) -> Pose {
        var p = Pose.loop(danceKeys, t, beat: danceBeat)
        p.squash *= 1 + 0.045 * sin(t * 2 * .pi / danceBeat)
        p.hip.y += 0.8 * abs(sin(t * .pi / danceBeat))
        return p
    }

    // MARK: Fighting

    /// t: 0 = guard, ~0.35 = fist out, 1 = back to guard.
    static func punch(_ t: CGFloat) -> Pose {
        let x = clampf(t, 0, 1)
        let out = smoothstep(clampf((x - 0.12) / 0.22, 0, 1))
        let back = smoothstep(clampf((x - 0.45) / 0.55, 0, 1))
        let ext = out * (1 - back)
        var p = Pose()
        p.armNear = lerp(1.05, 1.66, ext)
        p.foreNear = lerp(1.55, 0.04, ext)
        p.armFar = lerp(-0.35, -0.95, ext)
        p.foreFar = lerp(1.25, 0.7, ext)
        p.torso = lerp(-0.16, 0.26, ext)
        p.head = lerp(0.06, -0.14, ext)
        p.thighNear = lerp(-0.30, 0.55, ext)
        p.shinNear = lerp(-0.35, -0.55, ext)
        p.thighFar = lerp(0.40, -0.40, ext)
        p.shinFar = -0.60
        p.hip = CGPoint(x: lerp(-2.6, 2.2, ext), y: lerp(-1.4, 0.4, ext))
        p.squash = lerp(0.98, 1.03, ext)
        return p
    }

    /// Taking a hit: thrown back and folded.
    static func stagger(_ t: CGFloat) -> Pose {
        let k = 1 - smoothstep(clampf(t, 0, 1))
        var p = Pose()
        p.torso = -0.55 * k
        p.head = -0.40 * k
        p.armNear = 0.25 + 1.75 * k
        p.foreNear = 0.9 * k
        p.armFar = -0.25 + 1.7 * k
        p.foreFar = 0.8 * k
        p.thighNear = -0.55 * k
        p.shinNear = -0.35 - 0.55 * k
        p.thighFar = 0.60 * k + 0.1
        p.shinFar = -0.75
        p.hip = CGPoint(x: -3.2 * k, y: -2.4 * k)
        p.squash = 1 - 0.07 * k
        return p
    }

    /// Webbed up: arms pinned, squirming.
    static func webbed(_ t: CGFloat) -> Pose {
        let s = sin(t * 15)
        var p = Pose()
        p.armNear = 1.15 + 0.22 * s
        p.foreNear = 1.55
        p.armFar = 0.95 - 0.22 * s
        p.foreFar = 1.45
        p.torso = -0.20 + 0.07 * s
        p.head = 0.22 + 0.10 * s
        p.thighNear = 0.16 * s
        p.thighFar = -0.16 * s
        p.shinNear = -0.28
        p.shinFar = -0.28
        p.hip = CGPoint(x: 1.0 * s, y: -1.6)
        p.squash = 1.0
        return p
    }

    /// Knocked out flat on his back.
    static func defeated(_ t: CGFloat) -> Pose {
        let settle = smoothstep(clampf(t / 0.35, 0, 1))
        var p = Pose()
        p.torso = lerp(-0.55, -1.32, settle)
        p.head = lerp(-0.40, 0.62, settle)
        p.armNear = lerp(2.0, 2.75, settle)
        p.foreNear = lerp(0.9, -0.35, settle)
        p.armFar = lerp(1.7, 2.35, settle)
        p.foreFar = lerp(0.8, -0.45, settle)
        p.thighNear = lerp(-0.55, 0.95, settle)
        p.shinNear = lerp(-0.9, -0.85, settle)
        p.thighFar = lerp(0.7, 0.25, settle)
        p.shinFar = lerp(-0.75, -0.45, settle)
        p.hip = CGPoint(x: lerp(-3.2, 1.0, settle), y: lerp(-2.4, -7.5, settle))
        p.squash = lerp(0.93, 1.0, settle)
        // a small twitch so he is not completely static
        p.head += 0.05 * sin(t * 7)
        return p
    }

    // MARK: Combos

    static func celebrate(_ t: CGFloat) -> Pose {
        var p = Pose.stand
        let s = sin(t * 9)
        p.armNear = 2.9 + 0.15 * s
        p.armFar = 2.5 - 0.35 * s
        p.foreNear = 0.25
        p.foreFar = 0.75
        p.thighNear = 0.25
        p.shinNear = -0.35
        p.thighFar = -0.15
        p.shinFar = -0.25
        p.hip = CGPoint(x: 0, y: 1.4 + 1.2 * abs(s))
        p.torso = -0.08
        p.head = 0.18
        return p
    }
}
