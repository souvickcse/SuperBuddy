import AppKit
import CoreGraphics
import Foundation

// icon.swift - draws the SuperBuddy app icon (1024x1024 PNG).
// Usage: swiftc ... Tools/icon.swift -o .build/icon && ./.build/icon out.png

@main
struct IconTool {
    static func main() {
        let side = 1024
        guard let ctx = CGContext(data: nil, width: side, height: side,
                                  bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            exit(1)
        }
        let S = CGFloat(side)
        let ink = NSColor(srgbRed: 0.05, green: 0.05, blue: 0.09, alpha: 1).cgColor

        // ---- rounded app tile with a dark gradient background
        let inset: CGFloat = 76
        let tile = CGRect(x: inset, y: inset, width: S - inset * 2, height: S - inset * 2)
        let tilePath = CGPath(roundedRect: tile, cornerWidth: 210, cornerHeight: 210, transform: nil)

        ctx.saveGState()
        ctx.addPath(tilePath)
        ctx.clip()
        let space = CGColorSpaceCreateDeviceRGB()
        let gradient = CGGradient(colorsSpace: space, colors: [
            NSColor(srgbRed: 0.10, green: 0.13, blue: 0.30, alpha: 1).cgColor,
            NSColor(srgbRed: 0.26, green: 0.06, blue: 0.13, alpha: 1).cgColor
        ] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: S), end: CGPoint(x: 0, y: 0), options: [])

        // faint web in the background
        ctx.setStrokeColor(NSColor(white: 1, alpha: 0.10).cgColor)
        ctx.setLineWidth(3)
        for i in 0...10 {
            let a = CGFloat(i) / 10 * .pi
            ctx.move(to: CGPoint(x: S / 2, y: -100))
            ctx.addLine(to: CGPoint(x: S / 2 + cos(a) * 1400, y: -100 + sin(a) * 1400))
        }
        ctx.strokePath()
        for r in stride(from: CGFloat(180), through: 900, by: 180) {
            ctx.addArc(center: CGPoint(x: S / 2, y: -100), radius: r, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.strokePath()
        }
        ctx.restoreGState()

        // tile outline
        ctx.addPath(tilePath)
        ctx.setStrokeColor(NSColor(white: 0, alpha: 0.35).cgColor)
        ctx.setLineWidth(8)
        ctx.strokePath()

        // ---- the mask
        let head = CGRect(x: S / 2 - 300, y: S / 2 - 250, width: 600, height: 530)
        let headPath = CGPath(roundedRect: head, cornerWidth: 230, cornerHeight: 230, transform: nil)

        ctx.saveGState()
        ctx.addPath(headPath)
        ctx.clip()
        ctx.setFillColor(NSColor(srgbRed: 0.85, green: 0.11, blue: 0.17, alpha: 1).cgColor)
        ctx.fill(head)

        // webbing on the mask
        ctx.setStrokeColor(NSColor(srgbRed: 0.16, green: 0.02, blue: 0.03, alpha: 0.75).cgColor)
        ctx.setLineWidth(7)
        let fan = CGPoint(x: S / 2, y: head.minY + 120)
        for i in 0...8 {
            let a = CGFloat.pi * (0.08 + 0.84 * CGFloat(i) / 8)
            ctx.move(to: fan)
            ctx.addLine(to: CGPoint(x: fan.x + cos(a) * 660, y: fan.y + sin(a) * 660))
        }
        ctx.strokePath()
        ctx.setLineWidth(6)
        for r in stride(from: CGFloat(70), through: 560, by: 78) {
            ctx.addArc(center: fan, radius: r, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.strokePath()
        }
        ctx.restoreGState()

        ctx.addPath(headPath)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(14)
        ctx.strokePath()

        // ---- the lenses
        drawLens(ctx, center: CGPoint(x: S / 2 + 118, y: S / 2 + 40), size: CGSize(width: 250, height: 208),
                 tilt: -0.30, tint: NSColor(srgbRed: 0.97, green: 0.98, blue: 1.0, alpha: 1), ink: ink)
        drawLens(ctx, center: CGPoint(x: S / 2 - 132, y: S / 2 + 62), size: CGSize(width: 205, height: 172),
                 tilt: -0.30, tint: NSColor(srgbRed: 0.70, green: 0.78, blue: 0.92, alpha: 1), ink: ink)

        guard let image = ctx.makeImage() else { exit(1) }
        let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
        let rep = NSBitmapImageRep(cgImage: image)
        guard let data = rep.representation(using: .png, properties: [:]) else { exit(1) }
        do {
            try data.write(to: URL(fileURLWithPath: out))
            print("icon: wrote \(out)")
        } catch {
            FileHandle.standardError.write("icon: \(error)\n".data(using: .utf8)!)
            exit(1)
        }
    }

    static func drawLens(_ ctx: CGContext, center: CGPoint, size: CGSize, tilt: CGFloat,
                         tint: NSColor, ink: CGColor) {
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: tilt)
        let rect = CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height)
        ctx.addEllipse(in: rect)
        ctx.setFillColor(tint.cgColor)
        ctx.fillPath()
        ctx.addEllipse(in: rect)
        ctx.setStrokeColor(ink)
        ctx.setLineWidth(15)
        ctx.strokePath()
        ctx.restoreGState()
    }
}
