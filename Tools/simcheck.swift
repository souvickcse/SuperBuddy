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
    static func checkTiming() -> [String] {
        var failures: [String] = []
        let suite = "com.souvickghosh.superbuddy.timing-test.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        if TimingSettings.load(from: defaults) != .defaults { failures.append("Timing defaults changed") }
        let saved = TimingSettings(actionInterval: 75, villainInterval: 600)
        saved.save(to: defaults)
        if TimingSettings.load(from: defaults) != saved { failures.append("Timing settings were not remembered") }
        let disabled = TimingSettings(actionInterval: 0, villainInterval: 0)
        disabled.save(to: defaults)
        if TimingSettings.load(from: defaults) != disabled { failures.append("Disabled timing was not remembered") }

        let scene = SKScene(size: CGSize(width: 1680, height: 1000))
        var world = World(); world.bounds = CGRect(origin: .zero, size: scene.size)
        let buddy = Buddy(); world.reach = buddy.reach
        let web = WebLine(); scene.addChild(web); scene.addChild(buddy.rig.root)
        buddy.place(world)
        buddy.setAutomaticActionInterval(60)
        buddy.update(dt: 10, world: world, scene: scene, web: web)
        buddy.paused = true
        buddy.update(dt: 100, world: world, scene: scene, web: web)
        buddy.paused = false
        buddy.update(dt: 49, world: world, scene: scene, web: web)
        if buddy.canPerformAutomaticAction { failures.append("Action cooldown expired too early or ran while paused") }
        buddy.update(dt: 1, world: world, scene: scene, web: web)
        if !buddy.canPerformAutomaticAction { failures.append("Action cooldown did not expire") }
        buddy.didPerformAutomaticAction()
        if buddy.canPerformAutomaticAction { failures.append("Shared action cooldown was not reset") }
        buddy.setAutomaticActionInterval(0)
        buddy.place(world)
        for _ in 0..<3600 {
            buddy.update(dt: 1.0 / 60.0, world: world, scene: scene, web: web)
            if ![Buddy.State.stand, .walk].contains(buddy.currentState) {
                failures.append("A random special action ran with actions disabled"); break
            }
        }
        buddy.jump(world)
        if buddy.currentState != .jump { failures.append("Timing settings disabled a manual command") }
        buddy.place(world)
        let battle = Battle(); battle.setAutomaticInterval(300)
        battle.update(dt: 299, world: world, scene: scene, buddy: buddy)
        if battle.isActive { failures.append("Villain arrived before configured delay") }
        buddy.paused = true
        battle.update(dt: 600, world: world, scene: scene, buddy: buddy)
        buddy.paused = false
        if battle.isActive { failures.append("Villain timer ran while paused") }
        battle.update(dt: 1, world: world, scene: scene, buddy: buddy)
        if !battle.isActive { failures.append("Villain did not arrive after configured delay") }
        battle.setAutomaticInterval(600)
        if !battle.isActive { failures.append("Changing timing interrupted the active battle") }
        battle.villain?.remove(); buddy.inBattle = false; buddy.place(world)
        let manualBattle = Battle(); manualBattle.setAutomaticInterval(0)
        manualBattle.update(dt: 10000, world: world, scene: scene, buddy: buddy)
        if manualBattle.isActive { failures.append("A disabled villain timer spawned an enemy") }
        if !manualBattle.summon(world: world, scene: scene, buddy: buddy) { failures.append("Disabled timer blocked manual villain summon") }
        manualBattle.villain?.remove(); buddy.inBattle = false
        buddy.selectCharacter(.batman); buddy.place(world)
        let signal = BatSignal(), car = Batmobile()
        for _ in 0..<120 {
            signal.update(dt: 1, world: world, buddy: buddy, scene: scene, automatic: true)
            car.update(dt: 1, world: world, scene: scene, buddy: buddy, automatic: true)
        }
        if signal.active || car.active { failures.append("Beacon or car ignored disabled random actions") }
        if !signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Disabled timer blocked manual beacon") }
        signal.cancel(buddy: buddy)
        if !car.summon(world: world, scene: scene, buddy: buddy, drive: true) { failures.append("Disabled timer blocked manual car") }
        car.cancel(world: world, buddy: buddy)
        print("Timing settings      : persistence, shared cooldown, pause, disabling and manual overrides checked")
        return failures
    }

    static func checkLongBatInterval() -> [String] {
        var failures: [String] = []
        let scene = SKScene(size: CGSize(width: 1680, height: 1000))
        let buddy = Buddy(); buddy.selectCharacter(.batman)
        buddy.setAutomaticActionInterval(200)
        var world = World(); world.bounds = CGRect(origin: .zero, size: scene.size); world.reach = buddy.reach
        buddy.place(world); scene.addChild(buddy.rig.root)
        let web = WebLine(); scene.addChild(web)
        let beacon = BatSignal(), vehicle = Batmobile(), director = AutomaticActions()
        let dt = 1.0 / 30.0
        var actions: [AutomaticActions.BatAction] = []
        var times: [Double] = []
        for frame in 0..<54000 {
            vehicle.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false)
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            beacon.update(dt: dt, world: world, buddy: buddy)
            let previous = director.lastAction
            director.update(world: world, scene: scene, buddy: buddy, beacon: beacon, vehicle: vehicle)
            if director.lastAction != previous, let action = director.lastAction {
                actions.append(action); times.append(Double(frame + 1) * dt)
            }
            if actions.count == 5 { break }
        }
        if Set(actions).count != AutomaticActions.BatAction.allCases.count {
            failures.append("200-second interval starved one or more Bat-Buddy actions: \(actions)")
        }
        if let first = times.first, first < 200 - dt { failures.append("An automatic action started before 200 seconds") }
        for (earlier, later) in zip(times, times.dropFirst()) {
            if later - earlier < 200 - dt { failures.append("Automatic selector ignored the configured 200-second cooldown") }
        }
        beacon.cancel(buddy: buddy); vehicle.cancel(world: world, buddy: buddy)
        buddy.place(world); buddy.setAutomaticActionInterval(0)
        let previous = director.lastAction
        for _ in 0..<900 {
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            director.update(world: world, scene: scene, buddy: buddy, beacon: beacon, vehicle: vehicle)
        }
        if director.lastAction != previous || beacon.active || vehicle.active { failures.append("Shared selector ignored disabled automatic actions") }
        print("200s action selection : \(actions.map { String(describing: $0) }.joined(separator: ", "))")
        return failures
    }

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
        // A skin swap must preserve a live character's physics and scene ownership.
        let oldRoot = buddy.rig.root
        let oldPosition = buddy.pos
        let oldState = buddy.currentState
        buddy.selectCharacter(.deadpool)
        precondition(oldRoot.parent == nil && buddy.rig.root.parent === scene)
        precondition(buddy.pos == oldPosition && buddy.currentState == oldState)
        precondition(buddy.rig.skin.deadpoolDetails && buddy.rig.scale == buddy.scale)
        buddy.selectCharacter(.spider)
        precondition(!buddy.rig.skin.deadpoolDetails && buddy.rig.root.parent === scene)
        if CommandLine.arguments.contains("--deadpool") { buddy.selectCharacter(.deadpool) }
        if CommandLine.arguments.contains("--batman") { buddy.selectCharacter(.batman) }
        if CommandLine.arguments.contains("--hulk") { buddy.selectCharacter(.hulk) }
        world.reach = buddy.reach
        buddy.place(world)
        // Keep the broad animation smoke test fast; timing policy is checked separately.
        buddy.setAutomaticActionInterval(0.5)
        print("character            : \(buddy.character.title)")

        let dt = 1.0 / 60.0
        let seconds = 600.0   // he rests about half the time now, so sample longer
        var ticks = 0
        let patrolDirector = AutomaticActions()
        let patrolBeacon = BatSignal()
        let patrolVehicle = Batmobile()

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
            patrolVehicle.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false)
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            patrolBeacon.update(dt: dt, world: world, buddy: buddy)
            patrolDirector.update(world: world, scene: scene, buddy: buddy, beacon: patrolBeacon, vehicle: patrolVehicle)
            if buddy.character == .deadpool || buddy.character == .hulk { precondition(web.phase == .idle) }

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

        patrolBeacon.cancel(buddy: buddy)
        patrolVehicle.cancel(world: world, buddy: buddy)
        var failures: [String] = checkTiming()
        if buddy.character == .batman { failures += checkLongBatInterval() }
        if unstable { failures.append("simulation went non-finite") }
        if !insideX || !insideY { failures.append("buddy escaped the screen") }
        if !surfacesSeen.contains("floor") { failures.append("never stood on the floor") }
        if buddy.character == .spider {
        if !surfacesSeen.contains("ceiling") { failures.append("never crawled on the ceiling") }
        if !surfacesSeen.contains("left wall") || !surfacesSeen.contains("right wall") {
            failures.append("never crawled a side wall")
        }
        if swings < 3 { failures.append("barely used webs (\(swings) swings)") }
        }
        if buddy.character == .batman && swings > 0 { failures.append("Bat-Buddy used web swinging") }
        if landings < 3 { failures.append("barely landed like a hero (\(landings))") }
        if minY < -1 { failures.append("fell below the floor") }
        if maxSpeed > 4000 { failures.append("unstable velocity") }
        if maxBlink < 0.95 { failures.append("the buddy never fully closed his eyes (peak \(maxBlink))") }
        if ceilingSwings > 0 { failures.append("swung from the ceiling \(ceilingSwings) frames (should never web up there)") }
        if restMean < 1.5 { failures.append("his rests are too short (\(String(format: "%.1f", restMean))s)") }
        if restFrames < Int(seconds / dt) / 5 { failures.append("he hardly ever waits") }
        if buddy.character == .spider {
        if zips < 2 { failures.append("almost never used the web zip (\(zips))") }
        if zipFellShort > zipArrivedHigh { failures.append("most web zips failed to reach an edge (\(zipArrivedHigh) up, \(zipFellShort) short)") }
        if upsideDownFrames < 40 { failures.append("hardly ever rested upside down (\(upsideDownFrames) frames)") }
        if uprightOnWall > 0 { failures.append("stood upright on a wall for \(uprightOnWall) frames") }
        if crawlFrames < 300 { failures.append("hardly ever crawled on a wall (\(crawlFrames) frames)") }
        } else if buddy.character == .deadpool || buddy.character == .hulk {
            if swings != 0 || zips != 0 || upsideDownFrames != 0 { failures.append("Pool-Buddy used Spider-Buddy traversal") }
            if surfacesSeen != ["floor"] { failures.append("Pool-Buddy clung to a wall or ceiling") }
        }
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
        if buddy.character == .spider && buddy.currentState != .swing { failures.append("menu swing command failed") }
        if buddy.character != .spider && buddy.currentState == .swing { failures.append("Pool-Buddy accepted a swing command") }
        if buddy.character == .deadpool || buddy.character == .hulk {
            buddy.webZip(world, scene)
            buddy.hangFromWeb(world, scene)
            buddy.hangUpsideDown(world, scene)
            buddy.webBlast(at: .zero, scene: scene)
            buddy.update(dt: dt, world: world, scene: scene, web: web)
            if web.phase != .idle { failures.append("Pool-Buddy drew a web") }
        }
        for _ in 0..<300 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
        buddy.jump(world)
        if buddy.currentState != .jump { failures.append("menu jump command failed") }
        for _ in 0..<300 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
        if !buddy.pos.x.isFinite { failures.append("state became non-finite after commands") }

        if buddy.character == .hulk {
            buddy.place(world)
            if abs(buddy.rig.scale - buddy.scale * 1.25) > 0.001 { failures.append("Smash-Buddy size multiplier missing") }
            buddy.thunderclap(scene)
            if buddy.currentState != .thunderclap { failures.append("Smash-Buddy thunderclap command failed") }
            for _ in 0..<120 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
            buddy.punchAt(buddy.pos + CGPoint(x: 100, y: 0), scene: scene)
            if buddy.currentState != .punch { failures.append("Smash-Buddy smash command failed") }
            for _ in 0..<120 { buddy.update(dt: dt, world: world, scene: scene, web: web) }
            if !buddy.hitTest(buddy.pos + CGPoint(x: 23 * buddy.rig.scale, y: 0)) { failures.append("Smash-Buddy broad hit area missing") }
            buddy.setScale(1.35)
            world.reach = buddy.reach
            buddy.place(world)
            if abs(buddy.pos.y - world.floorY - buddy.reach) > 0.01 { failures.append("Smash-Buddy large scale floor alignment failed") }
            buddy.setScale(0.9)
            world.reach = buddy.reach
        }

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
            if lastState != buddy.currentState && (buddy.currentState == .webBlast || buddy.currentState == .pistolShot || buddy.currentState == .batarang || buddy.currentState == .thunderclap) { blasts += 1 }
            if lastState != .punch && buddy.currentState == .punch { punches += 1 }
            lastState = buddy.currentState
            if villainSeen && !battle.isActive { battleOver = true; break }
            fightFrames += 1
        }
        if lastHealth <= 0 { defeated = true }
        let fightSeconds = Double(fightFrames) * dt
        print("")
        print("battle               : \(summoned ? "summoned" : "FAILED"), \(villainSeen ? "villain appeared" : "no villain"), "
              + "\(defeated ? "knocked out" : "not knocked out"), \(blasts) ranged attacks, \(punches) melee attacks, "
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
        let roster = Skin.villains(for: buddy.character)
        let opponents = buddy.character != .spider ? roster : ["brawler", "charger", "flyer", "shooter"].compactMap { name in
            roster.first { "\($0.archetype)" == name }
        }
        for skin in opponents {
            let archetype = "\(skin.archetype)"
            // An uninterrupted opponent must progress from its telegraph to an attack.
            let attacker = Villain(skin: skin)
            attacker.spawn(world: world, near: world.bounds.midX, fromLeft: true, scale: buddy.scale)
            scene.addChild(attacker.rig.root)
            var attacks = 0
            for _ in 0..<1200 {
                if attacker.update(dt: dt, world: world, scene: scene,
                                   opponent: CGPoint(x: world.bounds.midX, y: world.floorY + buddy.reach)) { attacks += 1 }
            }
            attacker.remove()
            if attacks == 0 { failures.append("\(skin.name) never completed an attack") }
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
        if buddy.character == .batman {
            // The signal must conceal/reveal Batman and restore opacity on every interruption.
            buddy.place(world)
            let signal = BatSignal()
            if !signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Bat-Beacon did not start") }
            if signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Bat-Beacon allowed duplicate swarms") }
            var concealed = false
            for _ in 0..<180 {
                buddy.update(dt: dt, world: world, scene: scene, web: web)
                signal.update(dt: dt, world: world, buddy: buddy)
                concealed = concealed || buddy.rig.root.alpha < 0.1
            }
            if !concealed || signal.phase != .camouflaged { failures.append("Bat swarm did not camouflage Bat-Buddy") }
            buddy.paused = true
            let signalTime = signal.elapsed
            let hiddenAlpha = buddy.rig.root.alpha
            for _ in 0..<120 { signal.update(dt: dt, world: world, buddy: buddy) }
            if signal.elapsed != signalTime || buddy.rig.root.alpha != hiddenAlpha { failures.append("Bat-Beacon advanced while paused") }
            buddy.paused = false
            for _ in 0..<300 { signal.update(dt: dt, world: world, buddy: buddy) }
            if signal.active || signal.root.parent != nil || buddy.rig.root.alpha != 1 { failures.append("Bat-Beacon did not reveal/clean up") }
            for replacement in [BuddyCharacter.spider, .deadpool, .hulk] {
                buddy.place(world)
                _ = signal.start(world: world, scene: scene, buddy: buddy)
                signal.update(dt: 3, world: world, buddy: buddy)
                buddy.selectCharacter(replacement)
                signal.update(dt: dt, world: world, buddy: buddy)
                if signal.active || buddy.rig.root.alpha != 1 { failures.append("Bat-Beacon left a switched character hidden") }
                if signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Non-Bat-Buddy buddy summoned the Bat-Beacon") }
                buddy.selectCharacter(.batman)
            }
            buddy.place(world)
            _ = signal.start(world: world, scene: scene, buddy: buddy)
            signal.update(dt: 3, world: world, buddy: buddy)
            buddy.mouseDown(at: buddy.pos, clickCount: 1, scene: scene)
            buddy.mouseDragged(to: buddy.pos + CGPoint(x: 30, y: 30), time: 1)
            signal.update(dt: dt, world: world, buddy: buddy)
            if signal.active || buddy.rig.root.alpha != 1 { failures.append("Dragging did not reveal Bat-Buddy") }
            buddy.cancelDrag(); buddy.place(world)
            _ = signal.start(world: world, scene: scene, buddy: buddy)
            signal.update(dt: 3, world: world, buddy: buddy)
            signal.cancel(buddy: buddy)
            if signal.active || buddy.rig.root.alpha != 1 { failures.append("Bat-Beacon cancellation did not restore opacity") }
            _ = signal.start(world: world, scene: scene, buddy: buddy)
            signal.update(dt: 3, world: world, buddy: buddy)
            buddy.vehicleControl(at: buddy.pos, seated: true)
            signal.update(dt: dt, world: world, buddy: buddy)
            if signal.active || buddy.rig.root.alpha != 1 { failures.append("Boarding did not clear camouflage") }
            if signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Bat-Beacon started in the car") }
            buddy.leaveVehicle(world, at: world.bounds.midX)
            buddy.paused = true
            if signal.start(world: world, scene: scene, buddy: buddy) { failures.append("Bat-Beacon started while paused") }
            buddy.paused = false
            print("Bat-Beacon           : conceal/reveal, pause, duplicate prevention, switch/drag/boarding cleanup passed")
            // Automatic signals wait through pause/combat, start during a patrol,
            // and respect their cooldown after revealing Batman.
            buddy.place(world)
            let automaticSignal = BatSignal()
            buddy.update(dt: 1, world: world, scene: scene, web: web)
            buddy.paused = true
            for _ in 0..<3600 { automaticSignal.update(dt: dt, world: world, buddy: buddy, scene: scene, automatic: true) }
            if automaticSignal.active { failures.append("Automatic Bat-Beacon started while paused") }
            buddy.paused = false; buddy.inBattle = true
            for _ in 0..<3600 { automaticSignal.update(dt: dt, world: world, buddy: buddy, scene: scene, automatic: true) }
            if automaticSignal.active { failures.append("Automatic Bat-Beacon started during combat") }
            buddy.inBattle = false
            var automaticStarted = false
            for _ in 0..<2800 {
                automaticSignal.update(dt: dt, world: world, buddy: buddy, scene: scene, automatic: true)
                if automaticSignal.active { automaticStarted = true; break }
            }
            if !automaticStarted { failures.append("Bat-Beacon never started automatically during patrol") }
            for _ in 0..<420 { automaticSignal.update(dt: dt, world: world, buddy: buddy, scene: scene, automatic: true) }
            for _ in 0..<600 { automaticSignal.update(dt: dt, world: world, buddy: buddy, scene: scene, automatic: true) }
            if automaticSignal.active || buddy.rig.root.alpha != 1 { failures.append("Automatic Bat-Beacon ignored cooldown or failed to reveal Bat-Buddy") }
            automaticSignal.cancel(buddy: buddy)
            print("Automatic Bat-Beacon : patrol activation, pause/combat guards and cooldown passed")
            // Grapple should draw a cable, release it, and transition into a glide.
            buddy.place(world)
            buddy.webZip(world, scene, toCeiling: true)
            var sawCable = false, sawGlide = false
            for _ in 0..<900 {
                buddy.update(dt: dt, world: world, scene: scene, web: web)
                sawCable = sawCable || web.phase != .idle
                sawGlide = sawGlide || buddy.currentState == .glide
            }
            if !sawCable || !sawGlide { failures.append("Bat-Buddy grapple/glide sequence failed") }
            // A vehicle trip must board, drive, return the buddy, and remove the car.
            buddy.place(world)
            let car = Batmobile()
            if !car.summon(world: world, scene: scene, buddy: buddy, drive: true) { failures.append("Buddy-Mobile summon failed") }
            var boarded = false, drove = false
            var climbs: Set<String> = []
            var maxDriveSpeed: CGFloat = 0
            var lastCarPosition = car.root.position
            var wasDriving = false
            for _ in 0..<2400 {
                car.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false)
                buddy.update(dt: dt, world: world, scene: scene, web: web)
                boarded = boarded || buddy.inVehicle
                drove = drove || car.phase == .driving
                if car.phase == .driving, wasDriving {
                    let delta = car.root.position - lastCarPosition
                    maxDriveSpeed = max(maxDriveSpeed, delta.length / CGFloat(dt))
                    if delta.y > 1, abs(cos(car.root.zRotation)) < 0.01 {
                        climbs.insert("\(car.drivingSurface)")
                    }
                    if !world.bounds.contains(car.root.position) { failures.append("Buddy-Mobile escaped the display while wall driving"); break }
                }
                if car.phase == .exiting {
                    if abs(car.root.zRotation) > 0.001 || abs(car.root.position.y - world.floorY - 2 * buddy.scale) > 0.01 {
                        failures.append("Bat-Buddy tried to exit away from the floor")
                    }
                }
                wasDriving = car.phase == .driving
                lastCarPosition = car.root.position
                if !car.active { break }
            }
            if !boarded || !drove || car.active || buddy.inVehicle || buddy.rig.root.isHidden {
                failures.append("Buddy-Mobile trip did not board/drive/exit/clean up")
            }
            if !climbs.contains("left") || !climbs.contains("right") { failures.append("Buddy-Mobile did not climb both side walls") }
            if maxDriveSpeed < 1000 { failures.append("Buddy-Mobile did not reach boost speed") }
            // Pause on a wall must freeze position and rotation; dismiss returns to the floor.
            buddy.place(world)
            _ = car.summon(world: world, scene: scene, buddy: buddy, drive: true)
            var pausedOnWall = false
            for _ in 0..<1200 {
                car.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false)
                if car.phase == .driving, car.root.position.y > world.floorY + 250 {
                    pausedOnWall = true; break
                }
            }
            if !pausedOnWall { failures.append("Buddy-Mobile did not reach a wall for pause test") }
            buddy.paused = true
            let parkedAt = car.root.position
            let parkedAngle = car.root.zRotation
            for _ in 0..<120 { car.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false) }
            if car.root.position != parkedAt || car.root.zRotation != parkedAngle { failures.append("Buddy-Mobile moved or rotated while paused") }
            buddy.paused = false
            car.dismiss(world: world, buddy: buddy)
            if !buddy.inVehicle { failures.append("Bat-Buddy was ejected in mid-climb") }
            for _ in 0..<2400 {
                car.update(dt: dt, world: world, scene: scene, buddy: buddy, automatic: false)
                if !car.active { break }
            }
            if car.active || buddy.inVehicle || buddy.rig.root.isHidden { failures.append("Wall-ride dismissal did not restore Bat-Buddy") }
            car.cancel(world: world, buddy: buddy)
            if buddy.inVehicle || buddy.rig.root.isHidden || car.root.parent != nil { failures.append("Buddy-Mobile cancel left hidden buddy or car") }
            print("Buddy-Mobile            : boarded=\(boarded), climbs=\(climbs.sorted()), speed=\(Int(maxDriveSpeed))pt/s, cleaned up=\(!car.active)")
            // Different scales, portrait geometry and coarse frames must still finish a trip.
            for (testSize, testScale, testDT) in [(CGSize(width: 900, height: 1440), CGFloat(1.35), 1.0 / 30.0),
                                                  (CGSize(width: 800, height: 600), CGFloat(0.62), 0.05)] {
                let driver = Buddy()
                driver.selectCharacter(.batman); driver.setScale(testScale)
                var testWorld = World()
                testWorld.bounds = CGRect(origin: .zero, size: testSize); testWorld.reach = driver.reach
                driver.place(testWorld)
                let vehicle = Batmobile()
                _ = vehicle.summon(world: testWorld, scene: scene, buddy: driver, drive: true)
                var visitedLeft = false, visitedRight = false
                for _ in 0..<2400 {
                    vehicle.update(dt: testDT, world: testWorld, scene: scene, buddy: driver, automatic: false)
                    if vehicle.phase == .driving {
                        visitedLeft = visitedLeft || vehicle.drivingSurface == .left
                        visitedRight = visitedRight || vehicle.drivingSurface == .right
                        if !testWorld.bounds.contains(vehicle.root.position) { failures.append("Scaled Buddy-Mobile left screen"); break }
                    }
                    if !vehicle.active { break }
                }
                if vehicle.active || driver.inVehicle || !visitedLeft || !visitedRight { failures.append("Scaled/coarse-frame wall ride failed") }
                vehicle.cancel(world: testWorld, buddy: driver)
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
