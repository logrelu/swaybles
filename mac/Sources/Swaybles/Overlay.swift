// The overlay: a transparent, click-through panel across the top of the screen where charms hang.
// Clicks pass through to the apps below everywhere except on a charm. We find that out by
// reading the mouse position (no Accessibility or Input Monitoring permission needed).
import AppKit
import QuartzCore
import SwayblesCore

final class OverlayPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        ignoresMouseEvents = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// One charm hanging on screen.
final class Hanging {
    let uid: String
    let charm: Charm
    let image: NSImage?
    var x: Double            // pin position, fraction of screen width
    var rope: Rope
    let phase = Double.random(in: 0...10)

    init(uid: String, charm: Charm, image: NSImage?, x: Double, rope: Rope) {
        self.uid = uid; self.charm = charm; self.image = image; self.x = x; self.rope = rope
    }
}

struct Particle {
    var p: CGPoint
    var v: CGVector
    var life: Double
    let maxLife: Double
    let glyph: String
    let color: NSColor
}

final class OverlayController: NSObject {
    static let baseHeight = 170.0
    static let anchorY = 3.0

    let model: AppModel
    let panel = OverlayPanel()
    let view = OverlayView()
    private(set) var items: [Hanging] = []
    private(set) var particles: [Particle] = []
    private var images: [String: NSImage] = [:]

    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var acc = 0.0
    private var still = 0
    private(set) var time = 0.0
    private var lastDirty = CGRect.null

    private var poll: Timer?
    private var mouse = CGPoint.zero
    private var mouseTime = 0.0
    private var mouseVel = CGVector.zero
    private(set) var hover: (item: Hanging, kind: HitKind)?
    private var drag: (item: Hanging, kind: HitKind, offset: CGVector, start: CGPoint, moved: Bool)?
    private var nudgedAt: [String: Double] = [:]
    private var lastChime = 0.0

    enum HitKind { case charm, pin }

    init(model: AppModel) {
        self.model = model
        super.init()
        view.controller = self
        panel.contentView = view
        rebuild()
        reposition()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged),
                                               name: NSApplication.didChangeScreenParametersNotification, object: nil)
        let link = view.displayLink(target: self, selector: #selector(frame(_:)))
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        self.link = link
        let poll = Timer(timeInterval: 1.0 / 30, repeats: true) { [weak self] _ in self?.pollMouse() }
        poll.tolerance = 0.005
        RunLoop.main.add(poll, forMode: .common)
        self.poll = poll
    }

    // MARK: Showing and layout

    func show(_ on: Bool) {
        if on { panel.orderFrontRegardless(); hello() } else { panel.orderOut(nil) }
    }

    private var screen: NSScreen? { NSScreen.screens.first }   // the one with the menu bar
    var width: Double { Double(view.bounds.width) }

    @objc private func screensChanged() { reposition() }

    /// Full width, from just under the menu bar down as far as the longest charm can swing.
    func reposition() {
        guard let screen else { return }
        let f = screen.frame, top = screen.visibleFrame.maxY
        let k = model.settings.size
        let longest = items.map { $0.rope.length }.max() ?? 200
        let reach = longest * 1.05 + OverlayController.baseHeight * k * 1.4 + 60
        let h = min(top - f.minY, CGFloat(reach))
        panel.setFrame(NSRect(x: f.minX, y: top - h, width: f.width, height: h), display: true)
        for it in items { it.rope.nodes[0].x = it.x * Double(f.width) }
        invalidate(all: true)
        wake()
    }

    private func image(for charm: Charm) -> NSImage? {
        if let im = images[charm.id] { return im }
        let im = NSImage(contentsOf: model.imageURL(for: charm))
        images[charm.id] = im
        return im
    }

    /// Match the hanging charms to the settings, keeping each rope's motion when it's unchanged.
    private func rebuild() {
        let old = Dictionary(items.map { ($0.uid, $0) }, uniquingKeysWith: { a, _ in a })
        let w = max(width, Double(screen?.frame.width ?? 1440))
        items = model.settings.charms.compactMap { placed in
            guard let charm = model.charm(placed.charmID) else { return nil }
            if let o = old[placed.uid], o.charm.id == charm.id, abs(o.rope.length - placed.length) < 0.5 {
                o.x = placed.x
                return o
            }
            let rope = Rope(x: placed.x * w, y: OverlayController.anchorY, length: placed.length)
            return Hanging(uid: placed.uid, charm: charm, image: image(for: charm), x: placed.x, rope: rope)
        }
    }

    func settingsChanged(from before: Settings) {
        if before.hidden != model.settings.hidden { show(!model.settings.hidden) }
        rebuild()
        if before.size != model.settings.size || before.charms.map(\.length) != model.settings.charms.map(\.length)
            || before.charms.count != model.settings.charms.count {
            reposition()
        }
        invalidate(all: true)
        wake()
    }

    // MARK: Geometry

    func size(of it: Hanging) -> (w: Double, h: Double) {
        let h = OverlayController.baseHeight * model.settings.size
        return (h * it.charm.w / it.charm.h, h)
    }

    func center(of it: Hanging) -> CGPoint {
        OverlayGeometry.center(ropeEnd: (it.rope.end.x, it.rope.end.y), angle: it.rope.angle, size: size(of: it),
                               ax: it.charm.ax, ay: it.charm.ay)
    }

    private func hit(_ p: CGPoint) -> (item: Hanging, kind: HitKind)? {
        let targets = items.map { it -> OverlayGeometry.Target in
            let (w, h) = size(of: it)
            return .init(center: center(of: it), radius: min(w, h) * 0.5,
                         pin: CGPoint(x: it.rope.nodes[0].x, y: it.rope.nodes[0].y))
        }
        guard let h = OverlayGeometry.hit(p, in: targets) else { return nil }
        return (items[h.index], h.isPin ? .pin : .charm)
    }

    // MARK: Animation loop (sleeps when everything is still)

    func wake() {
        still = 0
        if link?.isPaused == true { lastTime = 0; link?.isPaused = false }
    }

    @objc private func frame(_ link: CADisplayLink) {
        let t = link.timestamp
        if lastTime == 0 { lastTime = t }
        let dt = min(0.05, t - lastTime)
        acc += dt
        lastTime = t
        time += dt

        let holdStill = model.settings.still
        let damping = holdStill ? 0.9 : model.reduceMotion || model.isDozing ? 0.975 : 0.9955
        let w = width
        while acc >= Rope.step {
            for it in items {
                let wind = model.settings.breeze && !holdStill
                    ? sin(time / 1.3 + it.phase) * 70 + sin(time / 0.47 + it.phase * 2) * 25 : 0
                it.rope.step(anchor: (it.x * w, OverlayController.anchorY), dt: Rope.step, damping: damping, wind: wind)
            }
            acc -= Rope.step
        }
        updateParticles(dt)
        invalidate(all: false)

        let energy = items.reduce(0) { $0 + $1.rope.energy }
        let animated = model.settings.breeze || model.settings.rope == .rainbow
        still = energy < 0.05 && drag == nil && !animated && particles.isEmpty ? still + 1 : 0
        if still > 90 { link.isPaused = true }
    }

    /// Redraw only around the charms (this frame's area plus last frame's).
    func invalidate(all: Bool) {
        var r = CGRect.null
        for it in items {
            let (w, h) = size(of: it)
            let reach = hypot(w, h) + 24
            for n in it.rope.nodes { r = r.union(CGRect(x: n.x - 8, y: n.y - 8, width: 16, height: 16)) }
            let e = it.rope.end
            r = r.union(CGRect(x: e.x - reach, y: e.y - reach, width: reach * 2, height: reach * 2 + 80))
        }
        for p in particles { r = r.union(CGRect(x: p.p.x - 20, y: p.p.y - 20, width: 40, height: 40)) }
        if all { view.needsDisplay = true } else { view.setNeedsDisplay(r.union(lastDirty)) }
        lastDirty = r
    }

    // MARK: Reactions

    private func chime() {
        guard model.settings.sound, time - lastChime > 0.25 else { return }
        lastChime = time
        NSSound(named: "Pop")?.play()
    }

    func nudgeAll(strength: Double) {
        guard !model.settings.still else { return }
        let s = model.reduceMotion ? strength * 0.4 : strength
        for (i, it) in items.enumerated() { it.rope.nudge(dx: (i % 2 == 0 ? 1 : -1) * (s + Double.random(in: 0...s * 0.6))) }
        wake()
    }

    /// First appearance: a friendly little swing hello.
    private func hello() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in self?.nudgeAll(strength: 10) }
    }

    /// Focus finished, or a new 90 days started: a happy wiggle and a burst of sparkles.
    func celebrate() {
        nudgeAll(strength: 16)
        let glyphs = ["✦", "♥", "✧", "★", "♥"]
        let colors: [NSColor] = [.systemPink, .systemYellow, .systemMint, .systemPurple, .systemOrange]
        let calm = model.reduceMotion
        for it in items {
            let c = center(of: it)
            for _ in 0..<(calm ? 4 : 14) {
                let a = Double.random(in: -.pi...0), speed = calm ? 0 : Double.random(in: 120...320)
                particles.append(Particle(p: calm ? CGPoint(x: c.x + .random(in: -40...40), y: c.y + .random(in: -40...40)) : c,
                                          v: CGVector(dx: cos(a) * speed, dy: sin(a) * speed),
                                          life: 1.6, maxLife: 1.6,
                                          glyph: glyphs.randomElement()!, color: colors.randomElement()!))
            }
        }
        wake()
    }

    private func updateParticles(_ dt: Double) {
        guard !particles.isEmpty else { return }
        for i in particles.indices {
            particles[i].p.x += particles[i].v.dx * dt
            particles[i].p.y += particles[i].v.dy * dt
            particles[i].v.dy += 420 * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    func dozeChanged() {
        if !model.isDozing { nudgeAll(strength: 8) }   // a little stretch on waking
        invalidate(all: true)
        wake()
    }

    func labelsChanged() { invalidate(all: true) }

    // MARK: Mouse

    private func viewPoint(_ screenPoint: NSPoint) -> CGPoint {
        CGPoint(x: screenPoint.x - panel.frame.minX, y: panel.frame.maxY - screenPoint.y)
    }

    /// 30×/s: is the mouse over a charm? Flick charms the cursor swipes through.
    private func pollMouse() {
        guard panel.isVisible else { return }
        let p = viewPoint(NSEvent.mouseLocation)
        let now = CACurrentMediaTime()
        let dt = max(0.001, now - mouseTime)
        // Velocity in points per 16 ms, like the Electron version.
        mouseVel = CGVector(dx: (p.x - mouse.x) / dt * 0.016, dy: (p.y - mouse.y) / dt * 0.016)
        let mid = CGPoint(x: (p.x + mouse.x) / 2, y: (p.y + mouse.y) / 2)
        mouse = p
        mouseTime = now
        if drag != nil { return }

        let h = hit(p) ?? hit(mid)
        if let h, h.kind == .charm {
            let since = time - (nudgedAt[h.item.uid] ?? -10)
            let speed = hypot(mouseVel.dx, mouseVel.dy)
            if since > 0.35, speed > 4, !model.settings.still {
                let k = model.reduceMotion ? 0.4 : 0.9
                h.item.rope.nudge(dx: mouseVel.dx * k, dy: mouseVel.dy * 0.4)
                nudgedAt[h.item.uid] = time
                chime()
                wake()
            }
        }
        let over = hit(p)
        let changed = over?.item !== hover?.item || over?.kind != hover?.kind
        hover = over
        panel.ignoresMouseEvents = over == nil
        if changed {
            (over == nil ? NSCursor.arrow : over!.kind == .pin ? NSCursor.resizeLeftRight : NSCursor.openHand).set()
            invalidate(all: true)
        }
    }

    func mouseDown(at p: CGPoint) {
        guard let h = hit(p) else { return }
        if h.kind == .pin {
            drag = (h.item, .pin, .zero, p, false)
        } else {
            let e = h.item.rope.end
            drag = (h.item, .charm, CGVector(dx: p.x - e.x, dy: p.y - e.y), p, false)
            h.item.rope.nodes[h.item.rope.nodes.count - 1].pinned = true
            NSCursor.closedHand.set()
        }
        wake()
    }

    func mouseDragged(to p: CGPoint) {
        guard let d = drag else { return }
        if hypot(p.x - d.start.x, p.y - d.start.y) > 4 { drag?.moved = true }
        if d.kind == .pin {
            d.item.x = OverlayGeometry.pinFraction(forX: Double(p.x), width: width)
        } else {
            let r = d.item.rope, a = r.nodes[0], last = r.nodes.count - 1
            let (tx, ty) = OverlayGeometry.clampedDrag(to: (Double(p.x - d.offset.dx), Double(p.y - d.offset.dy)),
                                                       anchor: (a.x, a.y), ropeLength: r.length)
            d.item.rope.nodes[last].px = d.item.rope.nodes[last].x
            d.item.rope.nodes[last].py = d.item.rope.nodes[last].y
            d.item.rope.nodes[last].x = tx
            d.item.rope.nodes[last].y = ty
        }
        wake()
    }

    func mouseUp() {
        guard let d = drag else { return }
        drag = nil
        if d.kind == .charm {
            d.item.rope.nodes[d.item.rope.nodes.count - 1].pinned = false
            chime()
            NSCursor.openHand.set()
            // A tap (not a drag) on Timer Ghost starts a focus session.
            if !d.moved, d.item.charm.role == .timer, !model.focus.isRunning { model.startFocus() }
        } else {
            let x = (d.item.x * 10000).rounded() / 10000
            model.update { s in
                if let i = s.charms.firstIndex(where: { $0.uid == d.item.uid }) { s.charms[i].x = x }
            }
        }
        wake()
    }
}
