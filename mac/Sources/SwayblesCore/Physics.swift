// Rope physics (Verlet). A straight port of the tested src/physics.js.
// Coordinates are top-left origin, y grows downward, units are points.
import Foundation

public struct RopeNode: Equatable {
    public var x: Double, y: Double     // position now
    public var px: Double, py: Double   // position one step ago (velocity = x - px)
    public var w: Double                // how much this node moves when constraints are solved
    public var pinned = false           // held by the user's mouse

    public init(x: Double, y: Double, w: Double) {
        self.x = x; self.y = y; self.px = x; self.py = y; self.w = w
    }
}

public struct Rope {
    public static let gravity = 2400.0
    public static let iterations = 14
    public static let segments = 12
    public static let step = 1.0 / 120.0

    public var nodes: [RopeNode]
    public private(set) var segmentLength: Double
    public var angle = 0.0          // charm tilt (radians)
    public var angularVelocity = 0.0

    /// A rope hanging straight down from (x, y).
    public init(x: Double, y: Double, length: Double, segments: Int = Rope.segments) {
        precondition(segments >= 2, "a rope needs at least 2 segments")
        segmentLength = length / Double(segments)
        nodes = (0...segments).map { i in
            RopeNode(x: x, y: y + Double(i) * length / Double(segments),
                     w: i == 0 ? 0 : (i == segments ? 0.3 : 1))
        }
    }

    public var end: RopeNode { nodes[nodes.count - 1] }
    public var length: Double { segmentLength * Double(nodes.count - 1) }

    /// One fixed time step. `anchor` pins the top; `wind` is a sideways push (points/s²).
    public mutating func step(anchor: (x: Double, y: Double), dt: Double, damping: Double, wind: Double = 0) {
        let last = nodes.count - 1
        nodes[0].x = anchor.x; nodes[0].px = anchor.x
        nodes[0].y = anchor.y; nodes[0].py = anchor.y
        for i in 1...last where !nodes[i].pinned {
            let vx = (nodes[i].x - nodes[i].px) * damping
            let vy = (nodes[i].y - nodes[i].py) * damping
            nodes[i].px = nodes[i].x; nodes[i].py = nodes[i].y
            nodes[i].x += vx + wind * dt * dt
            nodes[i].y += vy + Rope.gravity * dt * dt
        }
        for _ in 0..<Rope.iterations {
            for i in 0..<last {
                let wa = nodes[i].pinned ? 0 : nodes[i].w
                let wb = nodes[i + 1].pinned ? 0 : nodes[i + 1].w
                let ws = wa + wb
                if ws == 0 { continue }
                let dx = nodes[i + 1].x - nodes[i].x, dy = nodes[i + 1].y - nodes[i].y
                let dist = max((dx * dx + dy * dy).squareRoot(), 0.0001)
                let diff = (dist - segmentLength) / dist / ws
                nodes[i].x += dx * diff * wa; nodes[i].y += dy * diff * wa
                nodes[i + 1].x -= dx * diff * wb; nodes[i + 1].y -= dy * diff * wb
            }
        }
        orient()
    }

    /// The charm's tilt follows the last stretch of rope, with a little inertia.
    public mutating func orient() {
        let l = nodes.count - 1
        let a = nodes[l - 2], b = nodes[l]
        let target = atan2(-(b.x - a.x), b.y - a.y)
        angularVelocity = angularVelocity * 0.86 + (target - angle) * 0.22
        angle += angularVelocity
    }

    /// Give the charm a sideways shove (points per step).
    public mutating func nudge(dx: Double, dy: Double = 0) {
        let l = nodes.count - 1
        nodes[l].px -= dx; nodes[l].py -= dy
    }

    /// Total movement this step; near 0 means the rope is at rest and drawing can sleep.
    public var energy: Double {
        nodes.reduce(0) { $0 + abs($1.x - $1.px) + abs($1.y - $1.py) } + abs(angularVelocity)
    }
}
