import CoreGraphics
import Testing
@testable import Swaybles

@Suite struct OverlayGeometryTests {
    typealias G = OverlayGeometry

    @Test func aHangingCharmCentersBelowItsRopeEnd() {
        // Rope attaches at the top middle of a 100x100 image: the middle is 40 below the end.
        let c = G.center(ropeEnd: (200, 150), angle: 0, size: (100, 100), ax: 0.5, ay: 0.1)
        #expect(abs(c.x - 200) < 0.001 && abs(c.y - 190) < 0.001)
    }

    @Test func aQuarterTurnSwingsTheCenterSideways() {
        let c = G.center(ropeEnd: (200, 150), angle: .pi / 2, size: (100, 100), ax: 0.5, ay: 0.1)
        #expect(abs(c.x - 160) < 0.001 && abs(c.y - 150) < 0.001)
    }

    @Test func aCharmAttachedAtItsCenterDoesNotMove() {
        let c = G.center(ropeEnd: (10, 20), angle: 1.2, size: (80, 60), ax: 0.5, ay: 0.5)
        #expect(abs(c.x - 10) < 0.001 && abs(c.y - 20) < 0.001)
    }

    let a = G.Target(center: CGPoint(x: 100, y: 200), radius: 40, pin: CGPoint(x: 100, y: 3))
    let b = G.Target(center: CGPoint(x: 120, y: 200), radius: 40, pin: CGPoint(x: 300, y: 3))

    @Test func missesHitNothing() {
        #expect(G.hit(CGPoint(x: 500, y: 500), in: [a, b]) == nil)
        #expect(G.hit(CGPoint(x: 0, y: 0), in: []) == nil)
    }

    @Test func insideTheCircleGrabsTheCharm() {
        let h = G.hit(CGPoint(x: 90, y: 190), in: [a])
        #expect(h?.index == 0 && h?.isPin == false)
    }

    @Test func theEdgeOfTheCircleIsOutside() {
        #expect(G.hit(CGPoint(x: 140, y: 200), in: [a]) == nil)
    }

    @Test func nearThePinGrabsThePin() {
        let h = G.hit(CGPoint(x: 105, y: 8), in: [a])
        #expect(h?.index == 0 && h?.isPin == true)
    }

    @Test func theTopmostCharmWinsWhereTheyOverlap() {
        let h = G.hit(CGPoint(x: 110, y: 200), in: [a, b])
        #expect(h?.index == 1)
    }

    @Test func aCharmWinsOverItsOwnPin() {
        let t = G.Target(center: CGPoint(x: 50, y: 10), radius: 30, pin: CGPoint(x: 50, y: 10))
        #expect(G.hit(CGPoint(x: 50, y: 10), in: [t])?.isPin == false)
    }

    @Test func aDragWithinTheRopeIsLeftAlone() {
        let p = G.clampedDrag(to: (30, 40), anchor: (0, 0), ropeLength: 100)
        #expect(p.x == 30 && p.y == 40)
    }

    @Test func aDragPastTheRopeIsPulledBack() {
        let p = G.clampedDrag(to: (300, 400), anchor: (0, 0), ropeLength: 100)
        #expect(abs(hypot(p.x, p.y) - 102) < 0.001)       // 2% stretch
        #expect(abs(p.x / p.y - 0.75) < 0.001)            // same direction
    }

    @Test func pinsStayOnScreen() {
        #expect(G.pinFraction(forX: -50, width: 1000) == 0.01)
        #expect(G.pinFraction(forX: 5000, width: 1000) == 0.99)
        #expect(abs(G.pinFraction(forX: 250, width: 1000) - 0.25) < 0.0001)
    }
}
