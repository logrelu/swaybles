// Draws ropes, charms, the words on charms, and sparkles. Top-left origin (flipped).
import AppKit
import SwayblesCore

final class OverlayView: NSView {
    weak var controller: OverlayController?

    override var isFlipped: Bool { true }
    override var isOpaque: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: Mouse (only arrives while the cursor is over a charm)

    override func mouseDown(with e: NSEvent) { controller?.mouseDown(at: convert(e.locationInWindow, from: nil)) }
    override func mouseDragged(with e: NSEvent) { controller?.mouseDragged(to: convert(e.locationInWindow, from: nil)) }
    override func mouseUp(with e: NSEvent) { controller?.mouseUp() }

    // MARK: Sprites

    /// A charm and its shadow drawn once at the size it's shown at, so each frame only turns a small
    /// ready-made bitmap. (Re-scaling and blurring the full picture 60× a second was most of the CPU.)
    private var sprites: [String: NSImage] = [:]

    private func sprite(for it: Hanging, w: Double, h: Double) -> (image: NSImage, pad: Double)? {
        guard let source = it.image, let k = controller?.model.settings.size else { return nil }
        let scale = Double(window?.backingScaleFactor ?? 2)
        let pad = (16 * k).rounded(.up) + 2
        let key = "\(it.charm.id)@\(k)@\(scale)"
        if let hit = sprites[key] { return (hit, pad) }
        if sprites.count > 40 { sprites.removeAll() }     // sizes the person tried and left behind

        let pw = Int(((w + pad * 2) * scale).rounded(.up)), ph = Int(((h + pad * 2) * scale).rounded(.up))
        guard let ctx = CGContext(data: nil, width: pw, height: ph, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return nil }
        // Shadow offset and blur are in pixels, not affected by the scale below.
        ctx.setShadow(offset: CGSize(width: 0, height: -5 * k * scale), blur: 10 * k * scale,
                      color: CGColor(gray: 0, alpha: 0.28))
        ctx.scaleBy(x: scale, y: scale)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        source.draw(in: NSRect(x: pad, y: pad, width: w, height: h), from: .zero, operation: .sourceOver, fraction: 1,
                    respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high.rawValue])
        NSGraphicsContext.restoreGraphicsState()
        guard let cg = ctx.makeImage() else { return nil }
        let image = NSImage(cgImage: cg, size: NSSize(width: w + pad * 2, height: h + pad * 2))
        sprites[key] = image
        return (image, pad)
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        NSColor.clear.set()
        dirtyRect.fill(using: .copy)
        guard let c = controller, let ctx = NSGraphicsContext.current?.cgContext else { return }
        let model = c.model

        for it in c.items {
            let pts = it.rope.nodes.map { CGPoint(x: $0.x, y: $0.y) }
            RopeDrawer.draw(model.settings.rope, ctx, pts, time: c.time)
            RopeDrawer.drawPin(ctx, at: pts[0], hot: c.hover?.item === it && c.hover?.kind == .pin)

            let (w, h) = c.size(of: it)
            let e = it.rope.end
            ctx.saveGState()
            ctx.translateBy(x: e.x, y: e.y)
            ctx.rotate(by: it.rope.angle)
            if let sprite = sprite(for: it, w: w, h: h) {
                sprite.image.draw(in: NSRect(x: -w * it.charm.ax - sprite.pad, y: -h * it.charm.ay - sprite.pad,
                                             width: w + sprite.pad * 2, height: h + sprite.pad * 2),
                                  from: .zero, operation: .sourceOver, fraction: model.isDozing ? 0.85 : 1,
                                  respectFlipped: true, hints: nil)
            }
            if let t = model.text(for: it.charm) { drawText(t, on: it, w: w, h: h, ctx: ctx) }
            ctx.restoreGState()

            if model.isDozing { drawZzz(near: c.center(of: it), h: h) }
        }

        if let first = c.items.first {
            let (_, h) = c.size(of: first)
            let p = c.center(of: first)
            var tagY = p.y + h * 0.5 + 18
            if let banner = model.looseBanner {
                pill(banner, center: CGPoint(x: p.x, y: tagY))
                tagY += 26
            }
            if let loose = model.looseMessage {
                pill(loose, center: CGPoint(x: p.x, y: tagY))
            }
        }

        for p in c.particles {
            let a = max(0, min(1, p.life / p.maxLife))
            let s = NSAttributedString(string: p.glyph, attributes: [
                .font: NSFont.systemFont(ofSize: 18, weight: .bold),
                .foregroundColor: p.color.withAlphaComponent(a),
            ])
            let size = s.size()
            s.draw(at: CGPoint(x: p.p.x - size.width / 2, y: p.p.y - size.height / 2))
        }
    }

    // MARK: Words on charms

    private func roundedFont(_ size: CGFloat, _ weight: NSFont.Weight = .bold) -> NSFont {
        let f = NSFont.systemFont(ofSize: size, weight: weight)
        return NSFont(descriptor: f.fontDescriptor.withDesign(.rounded) ?? f.fontDescriptor, size: size) ?? f
    }

    /// On the charm's blank surface if it has one (see docs/ART.md), else in a little tag under it.
    /// Called inside the charm's transform: origin = the ring, unrotated charm axes.
    private func drawText(_ t: CharmText, on it: Hanging, w: Double, h: Double, ctx: CGContext) {
        guard let l = it.charm.label else {
            if it.charm.role == .timer && t.progress == nil { return }   // no clock face: only show while running
            pill(t.text, center: CGPoint(x: (0.5 - it.charm.ax) * w, y: (1 - it.charm.ay) * h + 16))
            return
        }
        let rect = CGRect(x: (l.x - it.charm.ax) * w, y: (l.y - it.charm.ay) * h, width: l.w * w, height: l.h * h)
        let chalk = it.charm.role == .quote
        let ink = chalk ? NSColor(white: 0.96, alpha: 0.95) : NSColor(red: 0.23, green: 0.16, blue: 0.12, alpha: 1)

        if let progress = t.progress, progress > 0 {
            let r = min(rect.width, rect.height) / 2 - 3
            let mid = CGPoint(x: rect.midX, y: rect.midY)
            ctx.saveGState()
            ctx.setLineCap(.round)
            ctx.setLineWidth(max(3, r * 0.12))
            ctx.setStrokeColor(NSColor.systemPink.withAlphaComponent(0.85).cgColor)
            ctx.addArc(center: mid, radius: r, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * progress, clockwise: false)
            ctx.strokePath()
            ctx.restoreGState()
        }
        fit(t.text, in: rect.insetBy(dx: rect.width * 0.08, dy: rect.height * 0.1), color: ink)
    }

    /// Largest font (up to 2 lines) that fits the rect, centred.
    private func fit(_ text: String, in rect: CGRect, color: NSColor) {
        let para = NSMutableParagraphStyle()
        para.alignment = .center
        para.lineBreakMode = .byWordWrapping
        var size = max(7, min(rect.height * 0.55, 34))
        var s = NSAttributedString()
        var box = CGRect.zero
        repeat {
            s = NSAttributedString(string: text, attributes: [.font: roundedFont(size), .foregroundColor: color, .paragraphStyle: para])
            box = s.boundingRect(with: CGSize(width: rect.width, height: .greatestFiniteMagnitude),
                                 options: [.usesLineFragmentOrigin], context: nil)
            if box.height <= rect.height && box.width <= rect.width + 0.5 { break }
            size -= 1
        } while size >= 7
        s.draw(with: CGRect(x: rect.minX, y: rect.midY - box.height / 2, width: rect.width, height: box.height),
               options: [.usesLineFragmentOrigin], context: nil)
    }

    /// A small paper tag with text, centred on `center`.
    private func pill(_ text: String, center: CGPoint) {
        let s = NSAttributedString(string: text, attributes: [
            .font: roundedFont(12, .semibold),
            .foregroundColor: NSColor(red: 0.23, green: 0.16, blue: 0.12, alpha: 1),
        ])
        let size = s.size()
        let box = CGRect(x: center.x - size.width / 2 - 9, y: center.y - size.height / 2 - 4,
                         width: size.width + 18, height: size.height + 8)
        NSColor(red: 1, green: 0.98, blue: 0.93, alpha: 0.95).setFill()
        NSBezierPath(roundedRect: box, xRadius: box.height / 2, yRadius: box.height / 2).fill()
        NSColor(white: 0, alpha: 0.12).setStroke()
        NSBezierPath(roundedRect: box, xRadius: box.height / 2, yRadius: box.height / 2).stroke()
        s.draw(at: CGPoint(x: box.minX + 9, y: box.minY + 4))
    }

    private func drawZzz(near c: CGPoint, h: Double) {
        for (i, size) in [11.0, 14, 17].enumerated() {
            let s = NSAttributedString(string: "z", attributes: [
                .font: roundedFont(size), .foregroundColor: NSColor(white: 1, alpha: 0.85),
                .strokeColor: NSColor(white: 0, alpha: 0.35), .strokeWidth: -3,
            ])
            s.draw(at: CGPoint(x: c.x + h * 0.28 + Double(i) * 9, y: c.y - h * 0.35 - Double(i) * 12))
        }
    }
}
