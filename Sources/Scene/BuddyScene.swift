import AppKit
import SpriteKit

/// Transparent, click-through-except-on-the-buddy overlay that owns the simulation.
final class BuddyScene: SKScene {

    let buddy = Buddy()
    let web = WebLine()
    let battle = Battle()
    var world = World()

    private var lastTime: TimeInterval = 0
    private var ready = false
    var frozen = false { didSet { buddy.paused = frozen } }

    // MARK: Lifecycle

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .clear
        scaleMode = .resizeFill
        guard !ready else { return }
        ready = true
        world.bounds = CGRect(origin: .zero, size: size)
        world.reach = buddy.reach
        addChild(web)
        addChild(buddy.rig.root)
        buddy.cursor = CGPoint(x: size.width / 2, y: size.height / 2)
        buddy.place(world)
    }


    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        world.bounds = CGRect(origin: .zero, size: size)
        buddy.cursor = cursorInScene()
        buddy.keepInside(world)
    }

    override func update(_ currentTime: TimeInterval) {
        guard ready else { return }
        if lastTime == 0 { lastTime = currentTime }
        var dt = currentTime - lastTime
        lastTime = currentTime
        if dt < 0 { dt = 0 }
        if dt > 0.05 { dt = 0.05 }
        buddy.cursor = cursorInScene()
        buddy.update(dt: dt, world: world, scene: self, web: web)
        if !frozen { battle.update(dt: dt, world: world, scene: self, buddy: buddy) }
    }

    // MARK: Input

    private func scenePoint(_ event: NSEvent) -> CGPoint {
        convertPoint(fromView: event.locationInWindow)
    }

    override func mouseDown(with event: NSEvent) {
        buddy.mouseDown(at: scenePoint(event), clickCount: event.clickCount, scene: self)
    }

    override func mouseDragged(with event: NSEvent) {
        buddy.mouseDragged(to: scenePoint(event), time: event.timestamp)
    }

    override func mouseUp(with event: NSEvent) {
        buddy.mouseUp(at: scenePoint(event), scene: self)
    }

    /// Called by the view with a *view*-coordinate point (bottom-left origin).
    func hitTestBuddy(_ viewPoint: CGPoint) -> Bool {
        buddy.hitTest(convertPoint(fromView: viewPoint))
    }

    func cursorInScene() -> CGPoint {
        guard let window = view?.window else { return buddy.pos }
        let inWindow = window.convertPoint(fromScreen: NSEvent.mouseLocation)
        return convertPoint(fromView: inWindow)
    }

    /// Let clicks fall through to the app underneath unless the pointer is on the buddy
    /// (or the buddy is being held, so a drag never loses its events).
    func syncMousePassthrough() {
        guard let window = view?.window else { return }
        let cursor = cursorInScene()
        let interactive = buddy.isInteractive(withCursor: cursor)
        if window.ignoresMouseEvents == interactive {
            window.ignoresMouseEvents = !interactive
            BuddyDebug.log("passthrough=\(!interactive) cursor=\(Int(cursor.x)),\(Int(cursor.y)) "
                           + "buddy=\(Int(buddy.pos.x)),\(Int(buddy.pos.y))")
        }
    }

    // MARK: Commands (menu bar)

    func commandDance() { buddy.dance(self) }

    func commandJump() {
        guard buddy.currentState != .grabbed else { return }
        buddy.jump(world)
    }

    func commandSwing() {
        guard buddy.currentState != .grabbed else { return }
        buddy.swing(world, self)
    }

    func commandHang() {
        guard buddy.currentState != .grabbed else { return }
        buddy.hangFromWeb(world, self)
    }

    func commandHangUpsideDown() {
        guard buddy.currentState != .grabbed else { return }
        if buddy.surface == .ceiling {
            buddy.hangUpsideDown(world, self)
        } else {
            buddy.webZip(world, self, toCeiling: true)
        }
    }

    func commandZipUp() {
        guard buddy.currentState != .grabbed else { return }
        buddy.webZip(world, self, toCeiling: true)
    }

    func commandZipSide() {
        guard buddy.currentState != .grabbed else { return }
        buddy.webZip(world, self, toCeiling: false)
    }

    func commandComeToCursor() {
        buddy.comeTo(cursorInScene(), world: world, scene: self)
    }

    @discardableResult
    func commandSummonVillain(skin: Skin? = nil) -> Bool {
        guard !battle.isActive, buddy.currentState != .grabbed else { return false }
        return battle.summon(world: world, scene: self, buddy: buddy, skin: skin)
    }

    func commandReset() {
        buddy.place(world)
    }

    func setBuddyScale(_ s: CGFloat) {
        buddy.setScale(s)
        world.reach = buddy.reach
        buddy.keepInside(world)
        userScale = s
        UserDefaults.standard.set(Double(s), forKey: "buddyScale")
    }

    var userScale: CGFloat = 0.9

    func loadPreferences() {
        let stored = UserDefaults.standard.object(forKey: "buddyScale") as? Double
        let s = CGFloat(stored ?? 0.9)
        userScale = clampf(s, 0.4, 2.0)
        buddy.setScale(userScale)
        world.reach = buddy.reach
        buddy.place(world)
    }
}
