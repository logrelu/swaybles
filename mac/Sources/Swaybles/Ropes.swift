// Rope styles, drawn with Core Graphics. A port of src/ropes.js.
import AppKit
import SwayblesCore

enum RopeDrawer {
    static func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(red: CGFloat((hex >> 16) & 0xff) / 255, green: CGFloat((hex >> 8) & 0xff) / 255,
                blue: CGFloat(hex & 0xff) / 255, alpha: alpha)
    }

    /// A smooth curve through the rope's nodes.
    static func path(_ pts: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        guard let first = pts.first else { return p }
        p.move(to: first)
        if pts.count > 2 {
            for i in 1..<(pts.count - 1) {
                let mid = CGPoint(x: (pts[i].x + pts[i + 1].x) / 2, y: (pts[i].y + pts[i + 1].y) / 2)
                p.addQuadCurve(to: mid, control: pts[i])
            }
        }
        p.addLine(to: pts[pts.count - 1])
        return p
    }

    static func stroke(_ ctx: CGContext, _ path: CGPath, _ color: CGColor, _ width: CGFloat, dash: [CGFloat]? = nil) {
        ctx.saveGState()
        ctx.addPath(path)
        ctx.setStrokeColor(color)
        ctx.setLineWidth(width)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        if let dash { ctx.setLineDash(phase: 0, lengths: dash) }
        ctx.strokePath()
        ctx.restoreGState()
    }

    /// Evenly spaced points along the rope (for chain links and pearls), with the local direction.
    static func sample(_ pts: [CGPoint], every step: CGFloat) -> [(p: CGPoint, angle: CGFloat)] {
        var out: [(p: CGPoint, angle: CGFloat)] = []
        var carry: CGFloat = 0
        for i in 0..<(max(pts.count, 1) - 1) {
            let a = pts[i], b = pts[i + 1]
            let dx = b.x - a.x, dy = b.y - a.y
            let len = max(hypot(dx, dy), 0.0001)
            let ang = atan2(dy, dx)
            var d = carry
            while d < len {
                out.append((p: CGPoint(x: a.x + dx * d / len, y: a.y + dy * d / len), angle: ang))
                d += step
            }
            carry = d - len
        }
        return out
    }

    static func chain(_ ctx: CGContext, _ pts: [CGPoint], fill: CGColor, edge: CGColor, shine: CGColor) {
        for (i, link) in sample(pts, every: 6.5).enumerated() {
            ctx.saveGState()
            ctx.translateBy(x: link.p.x, y: link.p.y)
            ctx.rotate(by: link.angle)
            if i % 2 == 0 {
                let ring = CGRect(x: -4.8, y: -2.9, width: 9.6, height: 5.8)
                ctx.setStrokeColor(edge); ctx.setLineWidth(3.2); ctx.strokeEllipse(in: ring)
                ctx.setStrokeColor(fill); ctx.setLineWidth(1.8); ctx.strokeEllipse(in: ring)
                ctx.setFillColor(shine); ctx.fillEllipse(in: CGRect(x: -3.4, y: -2.2, width: 4.8, height: 1.6))
            } else {
                ctx.setLineCap(.round)
                ctx.move(to: CGPoint(x: -4.6, y: 0)); ctx.addLine(to: CGPoint(x: 4.6, y: 0))
                ctx.setStrokeColor(edge); ctx.setLineWidth(3.4); ctx.strokePath()
                ctx.move(to: CGPoint(x: -4.6, y: 0)); ctx.addLine(to: CGPoint(x: 4.6, y: 0))
                ctx.setStrokeColor(fill); ctx.setLineWidth(1.8); ctx.strokePath()
            }
            ctx.restoreGState()
        }
    }

    static func draw(_ style: RopeStyle, _ ctx: CGContext, _ pts: [CGPoint], time: Double) {
        let p = path(pts)
        switch style {
        case .goldThread:
            stroke(ctx, p, color(0x5a3c0a, 0.55), 3.4)
            stroke(ctx, p, color(0xe0ae2e), 2.2)
            stroke(ctx, p, color(0xfff5be, 0.9), 0.8, dash: [6, 5])
        case .silverChain:
            chain(ctx, pts, fill: color(0xe6ebf2), edge: color(0x5d6673), shine: color(0xffffff, 0.9))
        case .goldChain:
            chain(ctx, pts, fill: color(0xf2c443), edge: color(0x7a5410), shine: color(0xfff8c8, 0.95))
        case .leather:
            stroke(ctx, p, color(0x3a2210), 6)
            stroke(ctx, p, color(0x8a5530), 4.2)
            stroke(ctx, p, color(0xffdcb4, 0.35), 1, dash: [2, 6])
        case .velvet:
            stroke(ctx, p, color(0x3d0c1e), 6)
            stroke(ctx, p, color(0x8e2447), 4.4)
            stroke(ctx, p, color(0xc2466e), 2, dash: [4, 4])
        case .twine:
            stroke(ctx, p, color(0x8c7045), 3.8)
            stroke(ctx, p, color(0xd9c08f), 2.6)
            stroke(ctx, p, color(0x8c7045), 1.2, dash: [3, 3])
        case .pearls:
            stroke(ctx, p, color(0x786e64, 0.5), 1)
            let space = CGColorSpaceCreateDeviceRGB()
            let colors = [color(0xffffff), color(0xf1e9df), color(0xb8aa9b)] as CFArray
            guard let g = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.6, 1]) else { return }
            for q in sample(pts, every: 7.2) {
                ctx.saveGState()
                ctx.addEllipse(in: CGRect(x: q.p.x - 3.3, y: q.p.y - 3.3, width: 6.6, height: 6.6))
                ctx.clip()
                ctx.drawRadialGradient(g, startCenter: CGPoint(x: q.p.x - 1.2, y: q.p.y - 1.2), startRadius: 0.4,
                                       endCenter: q.p, endRadius: 3.6, options: [])
                ctx.restoreGState()
            }
        case .rainbow:
            stroke(ctx, p, CGColor(gray: 0, alpha: 0.35), 4.6)
            for i in 0..<(pts.count - 1) {
                let hue = (Double(i) * 32 + time * 50).truncatingRemainder(dividingBy: 360) / 360
                let c = NSColor(hue: hue, saturation: 0.8, brightness: 0.97, alpha: 1).cgColor
                let seg = CGMutablePath()
                seg.move(to: pts[i]); seg.addLine(to: pts[i + 1])
                stroke(ctx, seg, c, 3)
            }
        }
    }

    /// The little gold pin at the top of each rope. `hot` = under the mouse.
    static func drawPin(_ ctx: CGContext, at p: CGPoint, hot: Bool) {
        let r: CGFloat = hot ? 7 : 5
        let c = CGPoint(x: p.x, y: p.y + 1)
        let space = CGColorSpaceCreateDeviceRGB()
        guard let g = CGGradient(colorsSpace: space, colors: [color(0xfff6c8), color(0xb8841c)] as CFArray, locations: [0, 1]) else { return }
        ctx.saveGState()
        ctx.addEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
        ctx.clip()
        ctx.drawRadialGradient(g, startCenter: CGPoint(x: c.x - 2, y: c.y - 2), startRadius: 1, endCenter: c, endRadius: r, options: [])
        ctx.restoreGState()
        ctx.setStrokeColor(color(0x3c280a, 0.7))
        ctx.setLineWidth(1.5)
        ctx.strokeEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }
}
