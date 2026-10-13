import AppKit
import Foundation
import SpriteKit

// simcheck.swift - headless smoke test for the buddy's physics and behaviour.
// Runs the real simulation for a few simulated minutes, then reports where the buddy
// went, which states it used, and whether anything went unstable.
//
//   swiftc ... Sources/... Tools/simcheck.swift -o .build/simcheck && ./.build/simcheck

@main
struct SimCheck {
    static func main() {
        let size = CGSize(width: 1680, height: 1000)
        let scene = SKScene(size: size)
        scene.anchorPoint = .zero

        let web = WebLine()
        scene.addChild(web)

        let buddy = Buddy()
        var world = World()
        world.bounds = CGRect(origin: .zero, size: size)
        world.reach = buddy.reach
        scene.addChild(buddy.rig.root)
        buddy.place(world)

        let dt = 1.0 / 60.0
        let seconds = 600.0   // he rests about half the time now, so sample longer
        var ticks = 0

        var stateFrames: [String: Int] = [:]
        var surfacesSeen: Set<String> = []
        var landings = 0
        var swings = 0
        var previous = buddy.currentState
        var minX = CGFloat.greatestFiniteMagnitude, maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude, maxY = -CGFloat.greatestFiniteMagnitude
        var maxSpeed: CGFloat = 0
        var unstable = false
        var blinks = 0
        var crawlFrames = 0
        var ceilingSwings = 0
        var zips = 0
        var upsideDownFrames = 0
        var rests = 0
        var restFrames = 0
        var zipArrivedHigh = 0
        var zipFellShort = 0
        var uprightOnWall = 0
        var maxBlink: CGFloat = 0
        var wasOpen = true

        while ticks < Int(seconds / dt) {
            buddy.cursor = CGPoint(x: size.width * 0.5 + sin(Double(ticks) / 300) * 400,
                                   y: size.height * 0.5 + cos(Double(ticks) / 220) * 300)
            buddy.update(dt: dt, world: world, scene: scene, web: web)

            let name = "\(buddy.currentState)"
            stateFrames[name, default: 0] += 1
            switch buddy.surface {
            case .floor: surfacesSeen.insert("floor")
            case .ceiling: surfacesSeen.insert("ceiling")
            case .left: surfacesSeen.insert("left wall")
            case .right: surfacesSeen.insert("right wall")
            }
            if previous != .swing && buddy.currentState == .swing { swings += 1 }
            if previous != .heroLand && buddy.currentState == .heroLand { landings += 1 }
            if previous != .zip && buddy.currentState == .zip { zips += 1 }
            if previous == .zip && buddy.currentState != .zip {
                if buddy.surface == .floor { zipFellShort += 1 } else { zipArrivedHigh += 1 }
            }
            if buddy.currentState == .stand { restFrames += 1 }
            if previous != .stand && buddy.currentState == .stand { rests += 1 }
            previous = buddy.currentState

            // on a wall or the ceiling he must always be in a crawl stance
            if buddy.surface != .floor, buddy.currentState != .jump, buddy.currentState != .fall,
               buddy.currentState != .swing, buddy.currentState != .hang,
               buddy.currentState != .grabbed {
                if buddy.crawlingNow { crawlFrames += 1 } else { uprightOnWall += 1 }
            }

            if buddy.currentState == .swing && buddy.surface == .ceiling { ceilingSwings += 1 }
            if buddy.isHangingUpsideDown { upsideDownFrames += 1 }


            let closure = buddy.rig.blink
            maxBlink = max(maxBlink, closure)
            if closure > 0.5 && wasOpen { blinks += 1; wasOpen = false }
            if closure < 0.05 { wasOpen = true }

            let p = buddy.pos
            minX = min(minX, p.x); maxX = max(maxX, p.x)
            minY = min(minY, p.y); maxY = max(maxY, p.y)
            maxSpeed = max(maxSpeed, buddy.vel.length)

            if !p.x.isFinite || !p.y.isFinite || !buddy.vel.x.isFinite || !buddy.vel.y.isFinite {
                unstable = true
                break
            }
            ticks += 1
        }

        let reach = buddy.reach
        let insideX = minX >= -1 && maxX <= size.width + 1
        let insideY = minY >= -1 && maxY <= size.height + 1

        print("simulated            : \(Int(seconds))s  (\(ticks) frames)")
        print("states               : " + stateFrames.sorted { $0.value > $1.value }
            .map { "\($0.key) \(String(format: "%.1f", Double($0.value) * dt))s" }.joined(separator: ", "))
        print("surfaces used        : \(surfacesSeen.sorted().joined(separator: ", "))")
        print("web swings           : \(swings)")
        print("superhero landings   : \(landings)")
        print("hip bounds           : x \(String(format: "%.0f", minX))...\(String(format: "%.0f", maxX))  " +
              "y \(String(format: "%.0f", minY))...\(String(format: "%.0f", maxY))  (screen 0...\(Int(size.width)), 0...\(Int(size.height)))")
        print("max speed            : \(String(format: "%.0f", maxSpeed)) pt/s")
        let restMean = rests > 0 ? Double(restFrames) * dt / Double(rests) : 0
        print("waiting              : \(rests) rests, mean \(String(format: "%.1f", restMean))s, \(String(format: "%.0f", Double(restFrames) * dt / seconds * 100))% of the time")
        print("zip arrivals         : \(zipArrivedHigh) reached an edge, \(zipFellShort) fell back to the floor")
        print("web zip              : \(zips) zips, \(upsideDownFrames) upside-down rest frames, \(ceilingSwings) web swings from the ceiling")
        print("wall posture         : \(crawlFrames) crawl frames, \(uprightOnWall) upright-on-wall frames")
        print("blinks               : \(blinks) (peak closure \(String(format: "%.2f", maxBlink)))")

        var failures: [String] = []
        if unstable { failures.append("simulation went non-finite") }
        if !insideX || !insideY { failures.append("buddy escaped the screen") }
        if !surfacesSeen.contains("floor") { failures.append("never stood on the floor") }
        if !surfacesSeen.contains("ceiling") { failures.append("never crawled on the ceiling") }
        if !surfacesSeen.contains("left wall") || !surfacesSeen.contains("right wall") {
            failures.append("never crawled a side wall")
        }
        if swings < 3 { failures.append("barely used webs (\(swings) swings)") }
        if landings < 3 { failures.append("barely landed like a hero (\(landings))") }
        if minY < -1 { failures.append("fell below the floor") }
        if maxSpeed > 4000 { failures.append("unstable velocity") }
        if maxBlink < 0.95 { failures.append("the buddy never fully closed his eyes (peak \(maxBlink))") }
        if ceilingSwings > 0 { failures.append("swung from the ceiling \(ceilingSwings) frames (should never web up there)") }
        if restMean < 1.5 { failures.append("his rests are too short (\(String(format: "%.1f", restMean))s)") }
        if restFrames < Int(seconds / dt) / 5 { failures.append("he hardly ever waits") }
        if zips < 2 { failures.append("almost never used the web zip (\(zips))") }
        if zipFellShort > zipArrivedHigh { failures.append("most web zips failed to reach an edge (\(zipArrivedHigh) up, \(zipFellShort) short)") }
        if upsideDownFrames < 40 { failures.append("hardly ever rested upside down (\(upsideDownFrames) frames)") }
        if uprightOnWall > 0 { failures.append("stood upright on a wall for \(uprightOnWall) frames") }
        if crawlFrames < 300 { failures.append("hardly ever crawled on a wall (\(crawlFrames) frames)") }
        if blinks < 20 { failures.append("only \(blinks) blinks in 5 minutes") }
        if blinks > 400 { failures.append("blinking far too often (\(blinks))") }

        // ---- interaction checks
        buddy.place(world)
        let hip = buddy.pos
        buddy.mouseDown(at: hip, clickCount: 1, scene: scene)
        buddy.mouseUp(at: hip, scene: scene)
        if buddy.currentState != .dance { failures.append("poke did not start the dance") }
        for _ in 0..<200 { buddy.update(dt: dt, world: world, scene: scene, web: web) }

        buddy.place(world)
        let start = buddy.pos
        buddy.mouseDown(at: start, clickCount: 1, scene: scene)
        for i in 0..<40 {
            buddy.mouseDragged(to: CGPoint(x: start.x + CGFloat(i) * 6, y: start.y + CGFloat(i) * 5),
                               time: Double(i) * dt)
            buddy.update(dt: dt, world: world, scene: scene, web: web)
        }
        let grabbed = buddy.currentState == .grabbed
        let held = buddy.pos
        buddy.mouseUp(at: held, scene: scene)
        let releasedFalling = buddy.currentState == .fall
        var landedHeroically = false
        for _ in 0..<600 {
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            if buddy.currentState == .heroLand { landedHeroically = true; break }
        }
        if !grabbed { failures.append("drag did not pick the buddy up") }
        if !releasedFalling { failures.append("release did not drop the buddy") }
        if !landedHeroically { failures.append("drag release did not end in a superhero landing") }
        if abs(held.x - start.x) < 1 { failures.append("dragging did not move the buddy") }

        // ---- menu commands
        buddy.place(world)
        buddy.swing(world, scene)
        if buddy.currentState != .swing { failures.append("menu swing command failed") }
        for _ in 0..<300 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
        buddy.jump(world)
        if buddy.currentState != .jump { failures.append("menu jump command failed") }
        for _ in 0..<300 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
        if !buddy.pos.x.isFinite { failures.append("state became non-finite after commands") }

        // ---- a full scrap, start to finish
        buddy.place(world)
        let battle = Battle()
        let summoned = battle.summon(world: world, scene: scene, buddy: buddy)
        var villainSeen = false
        var defeated = false
        var blasts = 0
        var punches = 0
        var fightFrames = 0
        var battleOver = false
        var lastState = buddy.currentState
        var lastHealth = 3
        while fightFrames < Int(60.0 / dt) {
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            battle.update(dt: dt, world: world, scene: scene, buddy: buddy)
            if let v = battle.villain {
                villainSeen = true
                if v.health < lastHealth { lastHealth = v.health }
            }
            if lastState != .webBlast && buddy.currentState == .webBlast { blasts += 1 }
            if lastState != .punch && buddy.currentState == .punch { punches += 1 }
            lastState = buddy.currentState
            if villainSeen && !battle.isActive { battleOver = true; break }
            fightFrames += 1
        }
        if lastHealth <= 0 { defeated = true }
        let fightSeconds = Double(fightFrames) * dt
        print("")
        print("battle               : \(summoned ? "summoned" : "FAILED"), \(villainSeen ? "villain appeared" : "no villain"), "
              + "\(defeated ? "knocked out" : "not knocked out"), \(blasts) web blasts, \(punches) punches, "
              + String(format: "over in %.1fs", fightSeconds))
        if !summoned { failures.append("could not summon a villain") }
        if !villainSeen { failures.append("the villain never turned up") }
        if !battleOver { failures.append("the fight never finished") }
        if blasts + punches < 2 { failures.append("the buddy barely fought back (\(blasts) blasts, \(punches) punches)") }
        if fightSeconds > 45 { failures.append("the fight dragged on") }
        if !buddy.pos.x.isFinite || !buddy.pos.y.isFinite { failures.append("buddy went non-finite during the fight") }
        if battle.villain != nil { failures.append("the villain was not cleaned up") }

        // ---- one fight per villain archetype, so every fighting style is exercised
        var archetypeReport: [String] = []
        for archetype in ["brawler", "charger", "flyer", "shooter"] {
            guard let skin = Skin.villains.first(where: { "\($0.archetype)" == archetype }) else {
                failures.append("no villain uses the \(archetype) archetype")
                continue
            }
            buddy.place(world)
            let b = Battle()
            let started = b.summon(world: world, scene: scene, buddy: buddy, skin: skin)
            var frames = 0
            var everActive = false
            var reachedAir = false
            while frames < Int(60.0 / dt) {
                buddy.update(dt: dt, world: world, scene: scene, web: web)
                b.update(dt: dt, world: world, scene: scene, buddy: buddy)
                if b.isActive { everActive = true }
                if let v = b.villain, v.isFlying { reachedAir = true }
                if everActive && !b.isActive { break }
                frames += 1
            }
            let secs = Double(frames) * dt
            let ok = started && everActive && !b.isActive && b.villain == nil
            archetypeReport.append("\(skin.name)(\(archetype)) "
                + (ok ? String(format: "%.0fs ok", secs) : "STUCK"))
            if !started { failures.append("\(archetype): could not summon") }
            if everActive && b.isActive { failures.append("\(archetype): fight never finished") }
            if b.villain != nil { failures.append("\(archetype): villain left behind") }
            if archetype == "flyer", !reachedAir { failures.append("flyer never took to the air") }
            if !buddy.pos.x.isFinite || !buddy.pos.y.isFinite {
                failures.append("\(archetype): buddy went non-finite")
            }
        }
        print("archetypes           : " + archetypeReport.joined(separator: ", "))

        print("")
        if failures.isEmpty {
            print("RESULT: PASS")
        } else {
            print("RESULT: FAIL")
            for f in failures { print("  - \(f)") }
            exit(1)
        }
    }
}
