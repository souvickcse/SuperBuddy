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

        ctx.restoreGState()

        // A gold superhero shield and white lightning bolt, shared in spirit
        // with the monochrome menu bar symbol. Independent of the chosen buddy.
        let shield = CGMutablePath()
        shield.move(to: CGPoint(x: 512, y: 832))
        shield.addLine(to: CGPoint(x: 796, y: 718))
        shield.addLine(to: CGPoint(x: 760, y: 430))
        shield.addQuadCurve(to: CGPoint(x: 512, y: 200), control: CGPoint(x: 720, y: 290))
        shield.addQuadCurve(to: CGPoint(x: 264, y: 430), control: CGPoint(x: 304, y: 290))
        shield.addLine(to: CGPoint(x: 228, y: 718))
        shield.closeSubpath()
        ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: NSColor(white: 0, alpha: 0.4).cgColor)
        ctx.addPath(shield)
        ctx.setFillColor(NSColor(srgbRed: 1, green: 0.73, blue: 0.16, alpha: 1).cgColor)
        ctx.fillPath()
        ctx.setShadow(offset: .zero, blur: 0)
        ctx.addPath(shield)
        ctx.setStrokeColor(NSColor(srgbRed: 1, green: 0.89, blue: 0.53, alpha: 1).cgColor)
        ctx.setLineWidth(12)
        ctx.strokePath()

        let bolt = CGMutablePath()
        bolt.move(to: CGPoint(x: 568, y: 745))
        bolt.addLine(to: CGPoint(x: 380, y: 480))
        bolt.addLine(to: CGPoint(x: 501, y: 480))
        bolt.addLine(to: CGPoint(x: 453, y: 310))
        bolt.addLine(to: CGPoint(x: 664, y: 572))
        bolt.addLine(to: CGPoint(x: 540, y: 572))
        bolt.closeSubpath()
        ctx.addPath(bolt)
        ctx.setFillColor(ink)
        ctx.fillPath()

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
