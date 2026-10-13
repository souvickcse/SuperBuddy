import CoreGraphics
import Foundation

// MARK: - Scalar helpers

@inline(__always) func clampf(_ v: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat {
    Swift.min(Swift.max(v, lo), hi)
}

@inline(__always) func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    a + (b - a) * t
}

func lerp(_ a: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
    CGPoint(x: lerp(a.x, b.x, t), y: lerp(a.y, b.y, t))
}

/// Shortest-arc angle interpolation (radians).
func lerpAngle(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
    var d = (b - a).truncatingRemainder(dividingBy: 2 * .pi)
    if d > .pi { d -= 2 * .pi }
    if d < -.pi { d += 2 * .pi }
    return a + d * t
}

func smoothstep(_ t: CGFloat) -> CGFloat {
    let x = clampf(t, 0, 1)
    return x * x * (3 - 2 * x)
}

/// Frame-rate independent blend factor for exponential smoothing.
func blendRate(_ dt: Double, _ rate: Double) -> CGFloat {
    CGFloat(1 - exp(-rate * max(0, dt)))
}

func randf(_ a: CGFloat, _ b: CGFloat) -> CGFloat {
    CGFloat.random(in: 0...1) * (b - a) + a
}

func randi(_ a: Int, _ b: Int) -> Int {
    Int.random(in: a...Swift.max(a, b))
}

func chance(_ p: Double) -> Bool {
    Double.random(in: 0..<1) < p
}

// MARK: - CGPoint helpers

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    static func - (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x - b.x, y: a.y - b.y) }
    static func * (a: CGPoint, s: CGFloat) -> CGPoint { CGPoint(x: a.x * s, y: a.y * s) }
    static func / (a: CGPoint, s: CGFloat) -> CGPoint { s == 0 ? .zero : CGPoint(x: a.x / s, y: a.y / s) }
    static func += (a: inout CGPoint, b: CGPoint) { a = a + b }
    static func -= (a: inout CGPoint, b: CGPoint) { a = a - b }

    var length: CGFloat { (x * x + y * y).squareRoot() }

    var normalized: CGPoint {
        let l = length
        return l > 0.0001 ? CGPoint(x: x / l, y: y / l) : .zero
    }

    func dot(_ p: CGPoint) -> CGFloat { x * p.x + y * p.y }
    func distance(to p: CGPoint) -> CGFloat { (self - p).length }

    /// Rotate 90° clockwise: (0,1) -> (1,0)
    var perpendicular: CGPoint { CGPoint(x: y, y: -x) }

    func rotated(by a: CGFloat) -> CGPoint {
        CGPoint(x: x * cos(a) - y * sin(a), y: x * sin(a) + y * cos(a))
    }

    var angle: CGFloat { atan2(y, x) }

    static func fromAngle(_ a: CGFloat, _ r: CGFloat = 1) -> CGPoint {
        CGPoint(x: cos(a) * r, y: sin(a) * r)
    }
}

extension CGFloat {
    static func deg(_ d: CGFloat) -> CGFloat { d * .pi / 180 }
    var inDegrees: CGFloat { self * 180 / .pi }
    var sign1: CGFloat { self < 0 ? -1 : 1 }
}
