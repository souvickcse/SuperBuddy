import CoreGraphics

/// A full snapshot of every joint of the buddy.
/// All angles are radians, measured in body space where:
///   * the limb hangs straight down at 0
///   * positive rotation swings the tip toward +x ("forward", the direction the buddy faces)
///   * the far (background) limbs are drawn darker behind the torso
struct Pose {
    var torso: CGFloat = 0          // lean of the upper body about the hip
    var head: CGFloat = 0           // head tilt relative to the chest

    var armNear: CGFloat = 0.20     // near shoulder
    var foreNear: CGFloat = 0.24    // near elbow (relative to upper arm)
    var armFar: CGFloat = -0.16
    var foreFar: CGFloat = 0.22

    var thighNear: CGFloat = 0.07
    var shinNear: CGFloat = -0.10   // near knee (relative to thigh, negative = heel back)
    var thighFar: CGFloat = -0.07
    var shinFar: CGFloat = -0.10

    var hip: CGPoint = .zero        // hip offset in body space (bob / crouch)
    var squash: CGFloat = 1         // vertical stretch, < 1 = crouch

    static let stand = Pose()

    static func blend(_ a: Pose, _ b: Pose, _ t: CGFloat) -> Pose {
        let k = clampf(t, 0, 1)
        var p = Pose()
        p.torso = lerpAngle(a.torso, b.torso, k)
        p.head = lerpAngle(a.head, b.head, k)
        p.armNear = lerpAngle(a.armNear, b.armNear, k)
        p.foreNear = lerpAngle(a.foreNear, b.foreNear, k)
        p.armFar = lerpAngle(a.armFar, b.armFar, k)
        p.foreFar = lerpAngle(a.foreFar, b.foreFar, k)
        p.thighNear = lerpAngle(a.thighNear, b.thighNear, k)
        p.shinNear = lerpAngle(a.shinNear, b.shinNear, k)
        p.thighFar = lerpAngle(a.thighFar, b.thighFar, k)
        p.shinFar = lerpAngle(a.shinFar, b.shinFar, k)
        p.hip = lerp(a.hip, b.hip, k)
        p.squash = lerp(a.squash, b.squash, k)
        return p
    }

    /// Walk through a list of key poses with `t` going 0 -> 1 across the whole list.
    static func timeline(_ keys: [Pose], _ t: CGFloat) -> Pose {
        guard let first = keys.first else { return .stand }
        guard keys.count > 1 else { return first }
        let x = clampf(t, 0, 1) * CGFloat(keys.count - 1)
        let i = Swift.min(Int(x), keys.count - 2)
        return blend(keys[i], keys[i + 1], smoothstep(x - CGFloat(i)))
    }

    /// Blend `keys` as an endless loop, `t` in seconds, `beat` seconds per key.
    static func loop(_ keys: [Pose], _ t: CGFloat, beat: CGFloat) -> Pose {
        guard !keys.isEmpty else { return .stand }
        let x = t / beat
        let i = Int(floor(x)) % keys.count
        let f = x - floor(x)
        return blend(keys[i], keys[(i + 1) % keys.count], smoothstep(f))
    }
}
