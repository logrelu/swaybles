// The overlay's maths with no AppKit: where a charm hangs, what the mouse is over, how far a drag
// may stretch the rope. Pulled out of OverlayController so it can be tested.
import CoreGraphics
import Foundation

enum OverlayGeometry {
    /// Where the middle of a charm is, given where its rope ends, the tilt, and where the rope attaches.
    static func center(ropeEnd e: (x: Double, y: Double), angle: Double, size: (w: Double, h: Double),
                       ax: Double, ay: Double) -> CGPoint {
        let ox = (0.5 - ax) * size.w, oy = (0.5 - ay) * size.h
        let c = cos(angle), s = sin(angle)
        return CGPoint(x: e.x + ox * c - oy * s, y: e.y + ox * s + oy * c)
    }

    /// What the mouse can grab on one hanging charm.
    struct Target {
        var center: CGPoint
        var radius: Double       // the charm's grab circle
        var pin: CGPoint         // where the rope is pinned at the top
    }

    static let pinRadius = 14.0

    /// The topmost (last drawn) charm or pin under `p`. A charm wins over its own pin.
    static func hit(_ p: CGPoint, in targets: [Target]) -> (index: Int, isPin: Bool)? {
        for i in targets.indices.reversed() {
            let t = targets[i]
            if hypot(p.x - t.center.x, p.y - t.center.y) < t.radius { return (i, false) }
            if hypot(p.x - t.pin.x, p.y - t.pin.y) < pinRadius { return (i, true) }
        }
        return nil
    }

    /// Where a dragged charm may go: the rope can stretch 2% past its length, no more.
    static func clampedDrag(to target: (x: Double, y: Double), anchor a: (x: Double, y: Double),
                            ropeLength: Double) -> (x: Double, y: Double) {
        let dx = target.x - a.x, dy = target.y - a.y, dist = hypot(dx, dy), maxLen = ropeLength * 1.02
        guard dist > maxLen else { return target }
        return (a.x + dx / dist * maxLen, a.y + dy / dist * maxLen)
    }

    /// A dragged pin stays on screen: 1% to 99% of the width.
    static func pinFraction(forX x: Double, width: Double) -> Double {
        min(0.99, max(0.01, x / width))
    }
}
