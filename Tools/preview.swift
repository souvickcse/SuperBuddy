import AppKit
import SpriteKit

// preview.swift - renders a contact sheet of every animation of the buddy to a PNG.
//
// It walks the very same SpriteKit node tree the app uses (Rig + Pose + Motions) and
// re-draws it with Core Graphics, so it needs neither a window server nor a GPU and can
// be run over ssh / from a script:
//
//   swiftc -module-cache-path .mcache \
//          Sources/Support/MathUtil.swift Sources/Buddy/Pose.swift \
//          Sources/Buddy/Motions.swift Sources/Buddy/Rig.swift \
//          Tools/preview.swift -o .build/preview && ./.build/preview preview.png

struct Shot {
    let name: String
    let pose: Pose
    var tilt: CGFloat = 0
    var facing: CGFloat = 1
    var anchor: CGPoint? = nil      // draw a web from the near hand to this offset
    var blink: CGFloat = 0          // 0 open, 1 shut
    var footWeb = false             // draw the line from the ankle instead of the hand
    var car = false
    var batSignalTime: TimeInterval? = nil
    var skin: Skin = Skin()         // costume
}

let shots: [Shot] = (Skin.hulkVillains + Skin.batmanVillains + Skin.deadpoolVillains).map { Shot(name: $0.name, pose: Motion.idle(0.4), skin: $0) } + [
    Shot(name: "Smash-Buddy - idle", pose: Motion.hulkIdle(0.5), skin: .hulk),
    Shot(name: "Smash-Buddy - walk", pose: Motion.hulkWalk(0.4), skin: .hulk),
    Shot(name: "Smash-Buddy - leap", pose: Motion.hulkLeap(0.5, rising: true), skin: .hulk),
    Shot(name: "Smash-Buddy - smash", pose: Motion.hulkSmash(0.62), skin: .hulk),
    Shot(name: "Smash-Buddy - thunderclap", pose: Motion.hulkClap(0.55), skin: .hulk),
    Shot(name: "Smash-Buddy - roar", pose: Motion.hulkRoar(0.4), skin: .hulk),
    Shot(name: "Bat-Beacon - spotlight", pose: .stand, batSignalTime: 0.6, skin: .batman),
    Shot(name: "Bat-Beacon - camouflage", pose: .stand, batSignalTime: 3.0, skin: .batman),
    Shot(name: "Bat-Beacon - reveal", pose: .stand, batSignalTime: 5.4, skin: .batman),
    Shot(name: "Buddy-Mobile", pose: .stand, car: true, skin: .batman),
    Shot(name: "Bat-Buddy - idle", pose: Motion.batmanIdle(0.5), skin: .batman),
    Shot(name: "Bat-Buddy - patrol", pose: Motion.batmanWalk(0.35), skin: .batman),
    Shot(name: "Bat-Buddy - glide", pose: Motion.batmanGlide(0.5), skin: .batman),
    Shot(name: "Bat-Buddy - Wingblade", pose: Motion.batmanThrow(0.3), skin: .batman),
    Shot(name: "Bat-Buddy - combo", pose: Motion.batmanCombo(0.7), skin: .batman),
    Shot(name: "Pool-Buddy - idle", pose: Motion.deadpoolIdle(0.4), skin: .deadpool),
    Shot(name: "Pool-Buddy - swagger", pose: Motion.deadpoolWalk(0.34), skin: .deadpool),
    Shot(name: "Pool-Buddy - dance", pose: Motion.deadpoolDance(0.8), skin: .deadpool),
    Shot(name: "Pool-Buddy - slash", pose: Motion.deadpoolSlash(0.4), skin: .deadpool),
    Shot(name: "Pool-Buddy - pistol", pose: Motion.deadpoolShoot(0.3), skin: .deadpool),
    Shot(name: "idle", pose: Motion.idle(0.4)),
    Shot(name: "walk", pose: Motion.walk(0.34)),
    Shot(name: "walk - facing left", pose: Motion.walk(0.34), facing: -1),
    Shot(name: "blink 1/3", pose: Motion.idle(0.4), blink: 0.33),
    Shot(name: "blink 2/3", pose: Motion.idle(0.4), blink: 0.66),
    Shot(name: "blink shut", pose: Motion.idle(0.4), blink: 1.0),
    Shot(name: "run", pose: Motion.run(0.28)),
    Shot(name: "crawl - ground check", pose: Motion.crawl(0.35)),
    Shot(name: "crawl - wall", pose: Motion.crawl(0.35), tilt: -1.5708),
    Shot(name: "crawl - ceiling", pose: Motion.crawl(0.35), tilt: .pi),
    Shot(name: "villain - Goblin-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[0]),
    Shot(name: "villain - Shadow-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[1]),
    Shot(name: "villain - Tentacle-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[2]),
    Shot(name: "villain - Armor-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[3]),
    Shot(name: "villain - Sand-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[4]),
    Shot(name: "villain - Mirage-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[5]),
    Shot(name: "villain - Spark-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[6]),
    Shot(name: "villain - Wing-Baddie", pose: Motion.air(0.3, vertical: 0), skin: Skin.villains[7]),
    Shot(name: "villain - Hunter-Baddie", pose: Motion.punch(0.4), skin: Skin.villains[8]),
    Shot(name: "villain - Boss-Baddie", pose: Motion.idle(0.4), skin: Skin.villains[9]),
    Shot(name: "crawl rest - wall", pose: Motion.crawlRest(1.4), tilt: -1.5708),
    Shot(name: "crawl rest - ceiling", pose: Motion.crawlRest(1.4), tilt: .pi),
    Shot(name: "crawl rest - looking up", pose: Motion.crawlRest(3.9), tilt: .pi),
    Shot(name: "upside-down rest", pose: Motion.hangUpsideDown(0.9), tilt: .pi,
         anchor: CGPoint(x: 4, y: 170), footWeb: true),
    Shot(name: "web zip to ceiling", pose: Motion.webZip(0.4), tilt: -0.5,
         anchor: CGPoint(x: 40, y: 150)),
    Shot(name: "jump", pose: Motion.air(0.2, vertical: 800)),
    Shot(name: "fall", pose: Motion.air(0.5, vertical: -500)),
    Shot(name: "shoot web", pose: Motion.shootWeb(0.16)),
    Shot(name: "swing", pose: Motion.swing(0.35, speed: 1.4), tilt: -0.62,
         anchor: CGPoint(x: 62, y: 140)),
    Shot(name: "hang", pose: Motion.hang(0.6), anchor: CGPoint(x: 6, y: 150)),
    Shot(name: "dance 1", pose: Motion.dance(0.10)),
    Shot(name: "dance 2", pose: Motion.dance(1.15)),
    Shot(name: "dance 3", pose: Motion.dance(2.40)),
    Shot(name: "grabbed", pose: Motion.flail(0.25, drift: CGPoint(x: 300, y: 120)), tilt: -0.20),
    Shot(name: "hero landing", pose: Motion.heroLanding(0.04)),
    Shot(name: "landing rise", pose: Motion.heroLanding(0.55)),
    Shot(name: "free fall spin", pose: Motion.air(0.3, vertical: -900), tilt: .pi * 0.72),
    Shot(name: "crawl - left wall", pose: Motion.crawl(0.6), tilt: 1.5708, facing: -1),
    Shot(name: "celebrate", pose: Motion.celebrate(0.3)),
    Shot(name: "idle - facing left", pose: Motion.idle(0.9), facing: -1)
]

// MARK: - Software renderer for the SKNode tree

final class Painter {
    let ctx: CGContext

    init(ctx: CGContext) { self.ctx = ctx }

    func draw(scene: SKNode) {
        ctx.saveGState()
        drawChildren(of: scene, transform: .identity)
        ctx.restoreGState()
    }

    private func drawChildren(of node: SKNode, transform parent: CGAffineTransform, opacity: CGFloat = 1) {
        let kids = node.children.sorted { a, b in
            a.zPosition == b.zPosition ? false : a.zPosition < b.zPosition
        }
        for child in kids { draw(node: child, transform: parent, opacity: opacity) }
    }

    private func localTransform(_ node: SKNode) -> CGAffineTransform {
        CGAffineTransform.identity
            .translatedBy(x: node.position.x, y: node.position.y)
            .rotated(by: node.zRotation)
            .scaledBy(x: node.xScale, y: node.yScale)
    }

    private func draw(node: SKNode, transform parent: CGAffineTransform, opacity: CGFloat) {
        guard !node.isHidden, node.alpha > 0.004 else { return }
        let t = localTransform(node).concatenating(parent)
        let effectiveAlpha = opacity * node.alpha

        switch node {
        case let shape as SKShapeNode:
            guard let path = shape.path else { return }
            ctx.saveGState()
            ctx.concatenate(t)
            ctx.beginPath()
            ctx.setAlpha(min(1, effectiveAlpha))
            ctx.addPath(path)
            if shape.fillColor.alphaComponent > 0.01 {
                ctx.setFillColor(shape.fillColor.cgColor)
                ctx.fillPath()
                ctx.addPath(path)
            }
            if shape.strokeColor.alphaComponent > 0.01 && shape.lineWidth > 0 {
                ctx.setStrokeColor(shape.strokeColor.cgColor)
                ctx.setLineWidth(shape.lineWidth)
                ctx.setLineJoin(.round)
                ctx.setLineCap(.round)
                ctx.strokePath()
            }
            ctx.beginPath()
            ctx.restoreGState()
            drawChildren(of: shape, transform: t, opacity: effectiveAlpha)

        case let crop as SKCropNode:
            ctx.saveGState()
            if let mask = crop.maskNode as? SKShapeNode, let p = mask.path {
                let mt = localTransform(mask).concatenating(t)
                ctx.concatenate(mt)
                ctx.addPath(p)
                ctx.clip()
                // the clip stays, but the CTM must go back to the parent frame
                // because every draw() call concatenates the full accumulated transform
                ctx.concatenate(mt.inverted())
            }
            drawChildren(of: crop, transform: t, opacity: effectiveAlpha)
            ctx.restoreGState()

        case let label as SKLabelNode:
            guard let text = label.text else { return }
            ctx.saveGState()
            ctx.setAlpha(effectiveAlpha)
            ctx.concatenate(t)
            let font = NSFont(name: label.fontName ?? "Helvetica", size: label.fontSize)
                ?? NSFont.systemFont(ofSize: label.fontSize)
            let attrs: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: label.fontColor ?? .white
            ]
            let str = NSAttributedString(string: text, attributes: attrs)
            let ns = NSGraphicsContext(cgContext: ctx, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = ns
            let sz = str.size()
            var origin = CGPoint(x: -sz.width / 2, y: 0)
            switch label.verticalAlignmentMode {
            case .center: origin.y = -sz.height / 2
            case .top: origin.y = -sz.height
            default: break
            }
            str.draw(at: origin)
            NSGraphicsContext.restoreGraphicsState()
            ctx.restoreGState()

        default:
            drawChildren(of: node, transform: t, opacity: effectiveAlpha)
        }
    }
}

// MARK: - Build the sheet

@main
struct PreviewTool {
    static func main() {
        let args = CommandLine.arguments
        let filter: [String]? = args.count > 2
            ? args[2].split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            : nil
        let shown = filter.map { terms in shots.filter { s in terms.contains { s.name.contains($0) } } } ?? shots
        let big = filter != nil

        let cols = big ? Swift.min(3, Swift.max(1, shown.count)) : 5
        let cellW: CGFloat = big ? 430 : 250
        let cellH: CGFloat = big ? 340 : 200
        let rigScale: CGFloat = big ? 3.1 : 1.9
        let baseY: CGFloat = big ? 150 : 82
        let groundY: CGFloat = big ? baseY - 26 * rigScale : 58
        let labelY: CGFloat = big ? 22 : 24

        let rows = Int(ceil(Double(shown.count) / Double(cols)))
        let sheet = CGSize(width: cellW * CGFloat(cols), height: cellH * CGFloat(rows))

        let scene = SKScene(size: sheet)
        scene.anchorPoint = .zero

        for (index, shot) in shown.enumerated() {
            let col = index % cols
            let row = index / cols
            let origin = CGPoint(x: CGFloat(col) * cellW, y: CGFloat(rows - 1 - row) * cellH)
            let base = CGPoint(x: origin.x + cellW / 2, y: origin.y + baseY)

            let rig = Rig(skin: shot.skin)
            rig.scale = rigScale * (shot.skin.costume == .hulk ? shot.skin.bodyScale : 1)
            rig.facing = shot.facing
            rig.apply(shot.pose)
            rig.animateCostume(time: 0.5, gliding: shot.name == "Bat-Buddy - glide", batarang: shot.name == "Bat-Buddy - Wingblade")
            rig.showWeapons(sword: shot.name == "Pool-Buddy - slash", pistol: shot.name == "Pool-Buddy - pistol")
            rig.blink = shot.blink
            rig.root.position = base + CGPoint(x: 0, y: shot.skin.costume == .hulk ? Rig.footReach * rigScale * (shot.skin.bodyScale - 1) : 0)
            rig.root.zRotation = shot.tilt
            scene.addChild(rig.root)
            if let signalTime = shot.batSignalTime {
                rig.root.isHidden = true
                let owner = Buddy()
                owner.selectCharacter(.batman); owner.setScale(big ? 2.1 : 1.4)
                var world = World()
                world.bounds = CGRect(x: origin.x + 24, y: origin.y + groundY,
                                      width: cellW - 48, height: cellH - groundY - 16)
                world.reach = owner.reach; owner.place(world)
                scene.addChild(owner.rig.root)
                owner.rig.root.position = owner.pos
                owner.rig.apply(Motion.batmanIdle(0))
                let signal = BatSignal()
                _ = signal.start(world: world, scene: scene, buddy: owner)
                signal.update(dt: signalTime, world: world, buddy: owner)
            }
            if shot.car {
                rig.root.isHidden = true
                let car = Batmobile()
                car.root.isHidden = false
                car.root.position = CGPoint(x: base.x, y: origin.y + groundY)
                car.root.setScale(big ? 2.2 : 1.2)
                scene.addChild(car.root)
            }

            if let offset = shot.anchor {
                let line = SKShapeNode()
                let p = CGMutablePath()
                let hand = (shot.footWeb ? rig.nearFootWorld : rig.nearHandWorld) ?? base
                let target = CGPoint(x: origin.x + cellW / 2 + offset.x * shot.facing * rigScale / 1.9,
                                     y: origin.y + offset.y * rigScale / 1.9 + 60)
                p.move(to: hand)
                p.addQuadCurve(to: target,
                               control: CGPoint(x: (hand.x + target.x) / 2, y: (hand.y + target.y) / 2 - 4))
                line.path = p
                line.strokeColor = NSColor(white: 1, alpha: 0.9)
                line.lineWidth = 1.7
                line.fillColor = .clear
                line.zPosition = 50
                scene.addChild(line)

                let splat = SKShapeNode()
                let sp = CGMutablePath()
                for i in 0..<8 {
                    let a = CGFloat(i) / 8 * 2 * .pi
                    sp.move(to: target)
                    sp.addLine(to: CGPoint(x: target.x + cos(a) * 7, y: target.y + sin(a) * 7))
                }
                splat.path = sp
                splat.strokeColor = NSColor(white: 1, alpha: 0.5)
                splat.lineWidth = 1
                splat.fillColor = .clear
                splat.zPosition = 50
                scene.addChild(splat)
            }

            let label = SKLabelNode(fontNamed: "Helvetica")
            label.text = shot.name
            label.fontSize = 12
            label.fontColor = NSColor(white: 0.72, alpha: 1)
            label.verticalAlignmentMode = .center
            label.position = CGPoint(x: base.x, y: origin.y + labelY)
            label.zPosition = 60
            scene.addChild(label)

            let ground = SKShapeNode()
            let gp = CGMutablePath()
            gp.move(to: CGPoint(x: origin.x + 16, y: origin.y + groundY))
            gp.addLine(to: CGPoint(x: origin.x + cellW - 16, y: origin.y + groundY))
            ground.path = gp
            ground.strokeColor = NSColor(white: 0.32, alpha: 1)
            ground.lineWidth = 1
            ground.fillColor = .clear
            scene.addChild(ground)
        }

        // MARK: Rasterise

        let pxW = Int(sheet.width), pxH = Int(sheet.height)
        guard let ctx = CGContext(data: nil,
                                  width: pxW, height: pxH,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            FileHandle.standardError.write("preview: could not create bitmap context\n".data(using: .utf8)!)
            exit(1)
        }

        ctx.setFillColor(NSColor(srgbRed: 0.075, green: 0.085, blue: 0.13, alpha: 1).cgColor)
        ctx.fill(CGRect(origin: .zero, size: sheet))

        Painter(ctx: ctx).draw(scene: scene)

        guard let image = ctx.makeImage() else {
            FileHandle.standardError.write("preview: could not rasterise\n".data(using: .utf8)!)
            exit(1)
        }

        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "preview.png"
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("preview: png encoding failed\n".data(using: .utf8)!)
            exit(1)
        }
        do {
            try data.write(to: URL(fileURLWithPath: out))
            print("preview: wrote \(out) (\(pxW)x\(pxH))")
        } catch {
            FileHandle.standardError.write("preview: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }
}
