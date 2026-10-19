import AppKit
import SpriteKit

/// Directs the occasional scrap: picks a villain, lets him drop in, referees the
/// exchange, then clears up and books the next one.
final class Battle {

    enum Phase { case idle, incoming, fighting, victorious }

    private(set) var villain: Villain?
    private(set) var phase: Phase = .idle
    private(set) var lastOpponent: String?

    /// Seconds until the next villain turns up on his own.
    private var nextFightIn: TimeInterval = 90
    private var phaseTime: TimeInterval = 0
    private var buddyCooldown: TimeInterval = 0
    private var wasWindingUp = false
    private var fightTime: TimeInterval = 0

    var isActive: Bool { phase != .idle }

    // MARK: Frame

    func update(dt: TimeInterval, world: World, scene: SKScene, buddy: Buddy) {
        guard !buddy.inVehicle else { return }
        phaseTime += dt

        switch phase {
        case .idle:
            nextFightIn -= dt
            if nextFightIn <= 0 { summon(world: world, scene: scene, buddy: buddy) }

        case .incoming:
            guard let v = villain else { finish(world: world, scene: scene, buddy: buddy); return }
            v.update(dt: dt, world: world, scene: scene, opponent: buddy.pos)
            buddy.face(toward: v.pos.x)
            if phaseTime > 1.0 {
                phase = .fighting
                phaseTime = 0
                fightTime = 0
                buddyCooldown = 0.55
            }

        case .fighting:
            guard let v = villain else { finish(world: world, scene: scene, buddy: buddy); return }
            fightTime += dt
            buddy.face(toward: v.pos.x)

            // he telegraphs, the buddy may read it and hop away
            if v.isWindingUp, !wasWindingUp, chance(0.45) {
                buddy.dodge(from: v.pos, scene: scene)
                FX.text("WHOOSH!", at: buddy.pos + CGPoint(x: 0, y: buddy.reach + 16), in: scene)
            }
            wasWindingUp = v.isWindingUp

            let connected = v.update(dt: dt, world: world, scene: scene, opponent: buddy.pos)
            if connected {
                let airborne = buddy.currentState == .jump || buddy.currentState == .fall
                if airborne {
                    FX.text("MISS!", at: v.pos + CGPoint(x: 0, y: v.reach + 20), in: scene)
                } else {
                    buddy.takeHit(from: v.pos, scene: scene)
                    if v.skin.costume == .freeze {
                        FX.text("ICE!", at: buddy.pos + CGPoint(x: 0, y: 30), in: scene, color: .cyan)
                        FX.hitSpark(at: buddy.pos, in: scene)
                    }
                    FX.text("POW!", at: CGPoint(x: (v.pos.x + buddy.pos.x) / 2, y: buddy.pos.y + buddy.reach + 18),
                            in: scene)
                }
            }

            // the buddy answers with fists up close, webs from a distance, and
            // closes the gap in between instead of plinking from range
            buddyCooldown -= dt
            if buddyCooldown <= 0, buddy.currentState != .fall, buddy.currentState != .grabbed {
                let dx = abs(v.pos.x - buddy.pos.x)
                let overhead = v.pos.y - buddy.pos.y > 70
                if buddy.character == .hulk {
                    if buddy.grounded, buddy.currentState != .punch, buddy.currentState != .thunderclap {
                        if !overhead, dx < 155 {
                            buddy.punchAt(v.pos, scene: scene)
                            buddyCooldown = 1.6
                            registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                        } else if overhead || dx > 300 {
                            buddy.thunderclap(scene)
                            buddyCooldown = 1.5
                            registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                        } else {
                            buddy.approach(v.pos.x, scene: scene, run: true)
                            buddyCooldown = 0.2
                        }
                    }
                } else if buddy.character == .batman {
                    if buddy.grounded, buddy.currentState != .batarang, buddy.currentState != .punch {
                        if !overhead, dx < 128 {
                            buddy.punchAt(v.pos, scene: scene)
                            buddyCooldown = 1.4
                        } else {
                            buddy.throwBatarang(at: v.pos, scene: scene)
                            buddyCooldown = 1.3
                        }
                        registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                    }
                } else if buddy.character == .deadpool {
                    if buddy.grounded, buddy.currentState != .punch, buddy.currentState != .pistolShot {
                        if !overhead, dx < 128 {
                            buddy.punchAt(v.pos, scene: scene)
                            registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                            buddyCooldown = 0.8
                        } else {
                            buddy.pistolShot(at: v.pos, scene: scene)
                            registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                            buddyCooldown = 1.1
                        }
                    }
                } else if !overhead, dx < 128 {
                    // in close: fists
                    buddyCooldown = Double(randf(0.78, 1.30))
                    buddy.punchAt(v.pos, scene: scene)
                    registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                } else if overhead {
                    // he is in the air: web him down
                    buddyCooldown = Double(randf(0.85, 1.45))
                    buddy.webBlast(at: v.pos, scene: scene)
                    registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                } else if v.isStuck {
                    // webbed up: close in and finish it
                    buddy.approach(v.pos.x, scene: scene, run: true)
                    buddyCooldown = 0.16
                } else if dx > 265, chance(0.7) {
                    // still hanging back: web him
                    buddyCooldown = Double(randf(0.85, 1.45))
                    buddy.webBlast(at: v.pos, scene: scene)
                    registerHit(on: v, from: buddy.pos, world: world, scene: scene, buddy: buddy)
                } else {
                    buddy.approach(v.pos.x, scene: scene, run: true)
                    buddyCooldown = 0.16
                }
            }

            if fightTime > 26 {
                // it is dragging on: he gives up and legs it
                v.flee(world)
                phase = .victorious
                phaseTime = 0
            }

        case .victorious:
            guard let v = villain else { finish(world: world, scene: scene, buddy: buddy); return }
            v.update(dt: dt, world: world, scene: scene, opponent: buddy.pos)
            if (phaseTime > 0.7 && v.isFinished) || phaseTime > 7 {
                buddy.celebrate(scene)
                finish(world: world, scene: scene, buddy: buddy)
            }
        }
    }

    private func registerHit(on v: Villain, from point: CGPoint, world: World,
                             scene: SKScene, buddy: Buddy) {
        let isWeb = buddy.character == .spider && buddy.currentState == .webBlast
        let finished = v.takeHit(from: point, scene: scene, webbed: isWeb)
        if isWeb {
            FX.webSplat(at: CGPoint(x: v.pos.x, y: v.pos.y + v.reach * 0.5), in: scene)
            FX.text("THWIP!", at: point + CGPoint(x: 0, y: buddy.reach + 14), in: scene)
        } else {
            FX.text(buddy.character == .deadpool ? (buddy.currentState == .punch ? "SLASH!" : "PEW!") : "BAM!", at: CGPoint(x: (point.x + v.pos.x) / 2, y: v.pos.y + v.reach * 0.8), in: scene)
        }
        if finished {
            phase = .victorious
            phaseTime = 0
            FX.text("K.O.!", at: v.pos + CGPoint(x: 0, y: v.reach + 26), in: scene)
        }
    }

    // MARK: Control

    @discardableResult
    func summon(world: World, scene: SKScene, buddy: Buddy, skin forced: Skin? = nil) -> Bool {
        guard phase == .idle, !buddy.inVehicle else { return false }
        let skin = forced ?? Skin.randomVillain(for: buddy.character)
        lastOpponent = skin.name
        let v = Villain(skin: skin)
        v.spawn(world: world, near: buddy.pos.x, fromLeft: chance(0.5), scale: buddy.scale)
        scene.addChild(v.rig.root)
        villain = v
        phase = .incoming
        phaseTime = 0
        buddy.inBattle = true
        // he drops whatever he is doing and comes down to the floor for the scrap
        if buddy.surface != .floor || !buddy.grounded {
            buddy.dropOff(world)
        }
        FX.text("\(skin.name)!", at: CGPoint(x: world.bounds.midX, y: world.bounds.midY + 120),
                in: scene, color: SKColor(srgbRed: 1.0, green: 0.85, blue: 0.35, alpha: 1))
        BuddyDebug.log("battle: \(skin.name) arrived")
        return true
    }

    private func finish(world: World, scene: SKScene, buddy: Buddy) {
        villain?.remove()
        villain = nil
        buddy.inBattle = false
        phase = .idle
        phaseTime = 0
        nextFightIn = Double(randf(70, 165))
        wasWindingUp = false
        BuddyDebug.log("battle: over, next in \(Int(nextFightIn))s")
    }
}
