import AppKit
import SpriteKit

/// Borderless, transparent, always-on-top window that never steals focus.
final class BuddyWindow: NSWindow {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SpriteKit view that only accepts clicks that actually land on the buddy,
/// so every other part of the desktop keeps working normally.
final class BuddyView: SKView {
    var hitTester: ((CGPoint) -> Bool)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let local = convert(point, from: superview)
        if let test = hitTester, !test(local) { return nil }
        return super.hitTest(point)
    }
}
