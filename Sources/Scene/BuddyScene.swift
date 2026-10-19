import AppKit
import SpriteKit

/// Transparent, click-through-except-on-the-buddy overlay that owns the simulation.
final class BuddyScene: SKScene {

    let buddy = Buddy()
    let web = WebLine()
    let battle = Battle()
    let batmobile = Batmobile()
    let batSignal = BatSignal()
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
        batSignal.cancel(buddy: buddy)
        batmobile.cancel(world: world, buddy: buddy)
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
        batmobile.update(dt: dt, world: world, scene: self, buddy: buddy)
        buddy.update(dt: dt, world: world, scene: self, web: web)
        batSignal.update(dt: dt, world: world, buddy: buddy)
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

    func selectCharacter(_ character: BuddyCharacter) {
        batSignal.cancel(buddy: buddy)
        batmobile.cancel(world: world, buddy: buddy)
        buddy.selectCharacter(character)
        world.reach = buddy.reach
        buddy.keepInside(world)
        UserDefaults.standard.set(character.rawValue, forKey: "buddyCharacter")
    }

    func commandKatana() {
        guard buddy.character == .deadpool, buddy.grounded,
              buddy.currentState != .grabbed, !frozen else { return }
        buddy.punchAt(buddy.pos + CGPoint(x: buddy.facing * 100, y: 0), scene: self)
    }

    func commandPistol() {
        guard buddy.character == .deadpool, buddy.grounded,
              buddy.currentState != .grabbed, !frozen else { return }
        buddy.pistolShot(at: buddy.pos + CGPoint(x: buddy.facing * 240, y: 0), scene: self)
    }

    func commandSmash() {
        guard buddy.character == .hulk, buddy.grounded, !frozen,
              buddy.currentState != .grabbed else { return }
        buddy.punchAt(buddy.pos + CGPoint(x: buddy.facing * 80, y: 0), scene: self)
    }
    func commandClap() { if !frozen { buddy.thunderclap(self) } }

    func commandBatSignal() {
        _ = batSignal.start(world: world, scene: self, buddy: buddy)
    }

    func commandBatarang() {
        guard !frozen, !buddy.inVehicle else { return }
        buddy.throwBatarang(at: buddy.pos + CGPoint(x: buddy.facing * 230, y: 15), scene: self)
    }
    func commandCombo() {
        guard buddy.character == .batman, buddy.grounded, !buddy.inVehicle, !frozen,
              buddy.currentState != .grabbed else { return }
        buddy.punchAt(buddy.pos + CGPoint(x: buddy.facing * 80, y: 0), scene: self)
    }
    func commandGrapple() {
        guard buddy.character == .batman, !buddy.inVehicle, !frozen, buddy.currentState != .grabbed else { return }
        buddy.webZip(world, self, toCeiling: true)
    }
    func commandGlide() { if !frozen { buddy.glide(world) } }
    func commandBatmobile() {
        guard buddy.character == .batman, !frozen else { return }
        if batmobile.active {
            batmobile.dismiss(world: world, buddy: buddy)
        } else {
            batSignal.cancel(buddy: buddy)
            _ = batmobile.summon(world: world, scene: self, buddy: buddy, drive: true)
        }
    }

    func commandDance() { if !buddy.inVehicle { buddy.dance(self) } }

    func commandJump() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        buddy.jump(world)
    }

    func commandSwing() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        buddy.swing(world, self)
    }

    func commandHang() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        buddy.hangFromWeb(world, self)
    }

    func commandHangUpsideDown() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        if buddy.surface == .ceiling {
            buddy.hangUpsideDown(world, self)
        } else {
            buddy.webZip(world, self, toCeiling: true)
        }
    }

    func commandZipUp() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        buddy.webZip(world, self, toCeiling: true)
    }

    func commandZipSide() {
        guard !buddy.inVehicle, buddy.currentState != .grabbed else { return }
        buddy.webZip(world, self, toCeiling: false)
    }

    func commandComeToCursor() {
        batSignal.cancel(buddy: buddy)
        batmobile.cancel(world: world, buddy: buddy)
        buddy.comeTo(cursorInScene(), world: world, scene: self)
    }

    @discardableResult
    func commandSummonVillain(skin: Skin? = nil) -> Bool {
        guard !buddy.inVehicle, !battle.isActive, buddy.currentState != .grabbed else { return false }
        batmobile.cancel(world: world, buddy: buddy)
        return battle.summon(world: world, scene: self, buddy: buddy, skin: skin)
    }

    func commandReset() {
        batSignal.cancel(buddy: buddy)
        batmobile.cancel(world: world, buddy: buddy)
        buddy.cancelDrag()
        buddy.place(world)
    }

    func setBuddyScale(_ s: CGFloat) {
        batSignal.cancel(buddy: buddy)
        batmobile.cancel(world: world, buddy: buddy)
        buddy.setScale(s)
        world.reach = buddy.reach
        buddy.keepInside(world)
        userScale = s
        UserDefaults.standard.set(Double(s), forKey: "buddyScale")
    }

    var userScale: CGFloat = 0.9

    func loadPreferences() {
        let character = BuddyCharacter(rawValue: UserDefaults.standard.string(forKey: "buddyCharacter") ?? "") ?? .spider
        buddy.selectCharacter(character)
        let stored = UserDefaults.standard.object(forKey: "buddyScale") as? Double
        let s = CGFloat(stored ?? 0.9)
        userScale = clampf(s, 0.4, 2.0)
        buddy.setScale(userScale)
        world.reach = buddy.reach
        buddy.place(world)
    }
}
