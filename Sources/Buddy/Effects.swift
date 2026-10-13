import AppKit
import SpriteKit

/// Short-lived particle-ish effects: impact rings, dust, cracks, web splats, musical notes.
enum FX {

    static func superheroImpact(at p: CGPoint, in scene: SKScene, power: CGFloat = 1) {
        shockwave(at: p, in: scene, power: power)
        cracks(at: p, in: scene, power: power)
        dust(at: p, in: scene, count: 12, power: power)
    }

    static func sharpLanding(at p: CGPoint, in scene: SKScene, power: CGFloat = 0.6) {
        shockwave(at: p, in: scene, power: power * 0.7)
        dust(at: p, in: scene, count: 6, power: power)
    }

    static func shockwave(at p: CGPoint, in scene: SKScene, power: CGFloat) {
        let ring = SKShapeNode(ellipseOf: CGSize(width: 26, height: 10))
        ring.position = p
        ring.strokeColor = SKColor(white: 1.0, alpha: 0.9)
        ring.lineWidth = 2.2
        ring.fillColor = .clear
        ring.zPosition = 80
        ring.setScale(0.25)
        scene.addChild(ring)
        let scale = 1.6 + 1.4 * power
        ring.run(.sequence([
            .group([
                .scale(to: scale, duration: 0.38),
                .fadeOut(withDuration: 0.42),
                .rotate(byAngle: 0.4, duration: 0.42)
            ]),
            .removeFromParent()
        ]))
    }

    static func cracks(at p: CGPoint, in scene: SKScene, power: CGFloat) {
        let path = CGMutablePath()
        let n = 7
        for i in 0..<n {
            let a = CGFloat(i) / CGFloat(n) * 2 * .pi + randf(-0.25, 0.25)
            let len = randf(14, 30) * (0.7 + 0.5 * power)
            var pt = p
            path.move(to: pt)
            var dir = CGPoint.fromAngle(a)
            for seg in 0..<3 {
                let step = len / 3
                pt = pt + dir * step
                path.addLine(to: pt)
                dir = dir.rotated(by: randf(-0.5, 0.5))
                _ = seg
            }
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = SKColor(white: 0.95, alpha: 0.85)
        shape.lineWidth = 1.5
        shape.fillColor = .clear
        shape.zPosition = 81
        shape.alpha = 0
        scene.addChild(shape)
        shape.run(.sequence([
            .fadeAlpha(to: 0.9, duration: 0.06),
            .wait(forDuration: 0.10),
            .fadeOut(withDuration: 0.75),
            .removeFromParent()
        ]))
    }

    static func dust(at p: CGPoint, in scene: SKScene, count: Int, power: CGFloat) {
        for _ in 0..<count {
            let r = randf(2.0, 5.0)
            let puff = SKShapeNode(circleOfRadius: r)
            puff.position = CGPoint(x: p.x + randf(-10, 10), y: p.y + randf(0, 5))
            puff.fillColor = SKColor(white: 0.92, alpha: 0.55)
            puff.strokeColor = .clear
            puff.zPosition = 79
            scene.addChild(puff)
            let dir = CGPoint(x: randf(-1, 1) * 55 * power, y: randf(0.2, 1) * 40 * power)
            puff.run(.sequence([
                .group([
                    .moveBy(x: dir.x, y: dir.y, duration: 0.55),
                    .scale(to: 2.4, duration: 0.55),
                    .fadeOut(withDuration: 0.55)
                ]),
                .removeFromParent()
            ]))
        }
    }

    static func webSplat(at p: CGPoint, in scene: SKScene) {
        let path = CGMutablePath()
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            path.move(to: p)
            path.addLine(to: p + CGPoint.fromAngle(a, 13))
        }
        for ring in 1...3 {
            path.addEllipse(in: CGRect(x: p.x - CGFloat(ring) * 4.2, y: p.y - CGFloat(ring) * 4.2,
                                       width: CGFloat(ring) * 8.4, height: CGFloat(ring) * 8.4))
        }
        let shape = SKShapeNode(path: path)
        shape.strokeColor = SKColor(white: 1, alpha: 0.75)
        shape.lineWidth = 1.2
        shape.fillColor = .clear
        shape.zPosition = 82
        shape.setScale(0.4)
        scene.addChild(shape)
        shape.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.16), .fadeAlpha(to: 0.7, duration: 0.16)]),
            .wait(forDuration: 0.35),
            .fadeOut(withDuration: 0.4),
            .removeFromParent()
        ]))
    }

    static func hitSpark(at p: CGPoint, in scene: SKScene) {
        for i in 0..<6 {
            let a = CGFloat(i) / 6 * 2 * .pi + randf(-0.2, 0.2)
            let s = SKShapeNode(circleOfRadius: randf(1.2, 2.6))
            s.position = p
            s.fillColor = SKColor(white: 1, alpha: 0.9)
            s.strokeColor = .clear
            s.zPosition = 85
            scene.addChild(s)
            let travel = CGPoint.fromAngle(a, randf(16, 30))
            s.run(.sequence([
                .group([.moveBy(x: travel.x, y: travel.y, duration: 0.3),
                        .fadeOut(withDuration: 0.3)]),
                .removeFromParent()
            ]))
        }
    }

    static func notes(at p: CGPoint, in scene: SKScene, count: Int = 4) {
        let glyphs = ["\u{266A}", "\u{266B}", "\u{266C}"]
        for i in 0..<count {
            let label = SKLabelNode(fontNamed: "Helvetica Neue")
            label.text = glyphs[i % glyphs.count]
            label.fontSize = randf(11, 16)
            label.fontColor = SKColor(white: 1.0, alpha: 0.9)
            label.position = CGPoint(x: p.x + randf(-14, 14), y: p.y + randf(6, 20))
            label.zPosition = 86
            label.alpha = 0
            scene.addChild(label)
            let d = Double(i) * 0.09
            label.run(.sequence([
                .wait(forDuration: d),
                .group([.fadeAlpha(to: 1, duration: 0.12), .scale(to: 1.15, duration: 0.12)]),
                .group([.moveBy(x: randf(-16, 16), y: randf(22, 40), duration: 0.75),
                        .fadeOut(withDuration: 0.75),
                        .rotate(byAngle: randf(-0.5, 0.5), duration: 0.75)]),
                .removeFromParent()
            ]))
        }
    }

    static func text(_ string: String, at p: CGPoint, in scene: SKScene, color: SKColor? = nil) {
        let label = SKLabelNode(fontNamed: "Helvetica Neue Bold")
        label.text = string
        label.fontSize = 13
        label.fontColor = color ?? SKColor(white: 1.0, alpha: 0.95)
        label.position = p
        label.zPosition = 87
        label.alpha = 0
        label.setScale(0.7)
        scene.addChild(label)
        label.run(.sequence([
            .group([.fadeAlpha(to: 1, duration: 0.09), .scale(to: 1.0, duration: 0.9)]),
            .group([.moveBy(x: 0, y: 18, duration: 0.7), .fadeOut(withDuration: 0.7)]),
            .removeFromParent()
        ]))
    }
    static func swordArc(at p: CGPoint, facing: CGFloat, in scene: SKScene) {
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: 27, startAngle: -1.1, endAngle: 1.1, clockwise: false)
        let arc = SKShapeNode(path: path)
        arc.position = p; arc.xScale = facing
        arc.strokeColor = SKColor(white: 0.95, alpha: 0.9)
        arc.lineWidth = 3; arc.zPosition = 110
        scene.addChild(arc)
        arc.run(.sequence([.group([.scale(to: 1.3, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    static func pistolFlash(at p: CGPoint, facing: CGFloat, in scene: SKScene) {
        let flash = SKShapeNode(circleOfRadius: 5)
        flash.position = p + CGPoint(x: facing * 7, y: 0)
        flash.fillColor = SKColor(srgbRed: 1, green: 0.8, blue: 0.2, alpha: 1)
        flash.strokeColor = .white; flash.zPosition = 110
        scene.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.1), .removeFromParent()]))
        let streak = SKShapeNode(rectOf: CGSize(width: 15, height: 1.5))
        streak.position = flash.position
        streak.fillColor = flash.fillColor; streak.strokeColor = .clear; streak.zPosition = 109
        scene.addChild(streak)
        streak.run(.sequence([.group([.moveBy(x: facing * 90, y: 0, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

}
