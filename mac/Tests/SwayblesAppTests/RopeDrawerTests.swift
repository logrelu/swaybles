import CoreGraphics
import Testing
@testable import Swaybles
import SwayblesCore

/// Draws the way the overlay does: into a context where y grows downward.
@Suite struct RopeDrawerTests {
    static let scale = 4.0

    /// Renders pearls down a vertical rope; returns brightness at (x, y) in points, y from the top.
    func render(_ style: RopeStyle) -> (brightness: (Double, Double) -> Double, pearl: CGPoint)? {
        let w = 40, h = 80, s = Int(Self.scale)
        guard let ctx = CGContext(data: nil, width: w * s, height: h * s, bitsPerComponent: 8, bytesPerRow: w * s * 4,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        ctx.translateBy(x: 0, y: Double(h * s))
        ctx.scaleBy(x: Self.scale, y: -Self.scale)          // y down, like the flipped OverlayView
        let pts = (0...12).map { CGPoint(x: 20, y: 5 + Double($0) * 5) }
        RopeDrawer.draw(style, ctx, pts, time: 0)
        let pearl = RopeDrawer.sample(pts, every: 7.2)[3].p
        let brightness: (Double, Double) -> Double = { x, y in
            withExtendedLifetime(ctx) {}                     // the pixels live in the context
            let i = (Int(y * Self.scale) * w * s + Int(x * Self.scale)) * 4
            return (Double(data[i]) + Double(data[i + 1]) + Double(data[i + 2])) / 3
        }
        return (brightness, pearl)
    }

    @Test func pearlsAreRoundAndShinyUpLeftOnScreen() throws {
        let r = try #require(render(.pearls))
        let c = r.pearl, d = 1.6
        let upLeft = r.brightness(c.x - d, c.y - d), downRight = r.brightness(c.x + d, c.y + d)
        #expect(upLeft > downRight + 15, "highlight should be up and to the left (\(upLeft) vs \(downRight))")
    }

    @Test func pearlsAreDrawnWhereTheRopeIs() throws {
        let r = try #require(render(.pearls))
        let on = r.brightness(r.pearl.x, r.pearl.y)
        let far = r.brightness(r.pearl.x + 12, r.pearl.y)
        #expect(on > 150 && far == 0, "a pearl on the rope, nothing 12pt away (\(on), \(far))")
    }
}
