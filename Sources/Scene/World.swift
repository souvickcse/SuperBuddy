import CoreGraphics

/// The desktop is a rectangle whose four edges are all walkable.
/// Gravity always pulls "down" in world space, but once the buddy latches onto an edge
/// its own "up" is the outward normal of that edge, so it can stand on the walls and ceiling.
struct World {
    enum Surface: CaseIterable {
        case floor, ceiling, left, right

        var opposite: Surface {
            switch self {
            case .floor: return .ceiling
            case .ceiling: return .floor
            case .left: return .right
            case .right: return .left
            }
        }
    }

    var bounds: CGRect = .zero
    var margin: CGFloat = 3
    /// Distance from the surface line to the hip when standing on it (scaled with the buddy).
    var reach: CGFloat = Rig.footReach

    var floorY: CGFloat { bounds.minY + margin }
    var ceilY: CGFloat { bounds.maxY - margin }
    var leftX: CGFloat { bounds.minX + margin }
    var rightX: CGFloat { bounds.maxX - margin }

    var width: CGFloat { Swift.max(1, bounds.width) }
    var height: CGFloat { Swift.max(1, bounds.height) }

    func up(for s: Surface) -> CGPoint {
        switch s {
        case .floor: return CGPoint(x: 0, y: 1)
        case .ceiling: return CGPoint(x: 0, y: -1)
        case .left: return CGPoint(x: 1, y: 0)
        case .right: return CGPoint(x: -1, y: 0)
        }
    }

    /// Direction the buddy travels when it walks "forward" while facing +x.
    func tangent(for s: Surface) -> CGPoint { up(for: s).perpendicular }

    func snap(_ p: CGPoint, to s: Surface) -> CGPoint {
        switch s {
        case .floor: return CGPoint(x: clampX(p.x), y: floorY + reach)
        case .ceiling: return CGPoint(x: clampX(p.x), y: ceilY - reach)
        case .left: return CGPoint(x: leftX + reach, y: clampY(p.y))
        case .right: return CGPoint(x: rightX - reach, y: clampY(p.y))
        }
    }

    func clampX(_ x: CGFloat) -> CGFloat {
        let lo = leftX + reach, hi = rightX - reach
        return hi < lo ? (lo + hi) / 2 : clampf(x, lo, hi)
    }

    func clampY(_ y: CGFloat) -> CGFloat {
        let lo = floorY + reach, hi = ceilY - reach
        return hi < lo ? (lo + hi) / 2 : clampf(y, lo, hi)
    }

    /// Walking past a corner moves the buddy onto the neighbouring edge.
    func cornerTransition(_ p: CGPoint, from s: Surface) -> Surface? {
        let r = reach
        switch s {
        case .floor:
            if p.x >= rightX - r { return .right }
            if p.x <= leftX + r { return .left }
        case .right:
            if p.y >= ceilY - r { return .ceiling }
            if p.y <= floorY + r { return .floor }
        case .ceiling:
            if p.x <= leftX + r { return .left }
            if p.x >= rightX - r { return .right }
        case .left:
            if p.y <= floorY + r { return .floor }
            if p.y >= ceilY - r { return .ceiling }
        }
        return nil
    }

    /// Nearest edge to a point, and how far away it is (perpendicular distance).
    func nearestSurface(to p: CGPoint) -> (Surface, CGFloat) {
        let candidates: [(Surface, CGFloat)] = [
            (.floor, p.y - floorY),
            (.ceiling, ceilY - p.y),
            (.left, p.x - leftX),
            (.right, rightX - p.x)
        ]
        var best = candidates[0]
        for c in candidates where c.1 < best.1 { best = c }
        return best
    }

    func isInside(_ p: CGPoint, slack: CGFloat = 0) -> Bool {
        p.x > bounds.minX - slack && p.x < bounds.maxX + slack &&
        p.y > bounds.minY - slack && p.y < bounds.maxY + slack
    }

    /// Point on the surface where the buddy is touching down.
    func contactPoint(for p: CGPoint, on s: Surface) -> CGPoint {
        let u = up(for: s)
        return p - u * reach
    }
}
