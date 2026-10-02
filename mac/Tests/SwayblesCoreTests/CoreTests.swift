import Foundation
import Testing
@testable import SwayblesCore

// MARK: - Rope physics (mirrors tests/physics.test.js)

@Suite struct PhysicsTests {
    func settle(_ rope: inout Rope, steps: Int = 2400, anchor: (Double, Double) = (100, 0)) {
        for _ in 0..<steps { rope.step(anchor: (anchor.0, anchor.1), dt: Rope.step, damping: 0.9955) }
    }

    @Test func hangsStraightDownAtRest() {
        var r = Rope(x: 100, y: 0, length: 150)
        r.nudge(dx: 20)
        settle(&r)
        #expect(abs(r.end.x - 100) < 1)
        #expect(abs(r.end.y - 150) < 3)
        #expect(abs(r.angle) < 0.02)
    }

    @Test func segmentsKeepTheirLength() {
        var r = Rope(x: 0, y: 0, length: 120)
        r.nudge(dx: 30, dy: 10)
        for _ in 0..<200 { r.step(anchor: (0, 0), dt: Rope.step, damping: 0.9955) }
        for i in 0..<(r.nodes.count - 1) {
            let a = r.nodes[i], b = r.nodes[i + 1]
            let d = ((b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y)).squareRoot()
            #expect(abs(d - r.segmentLength) < r.segmentLength * 0.08)
        }
    }

    @Test func topFollowsTheAnchor() {
        var r = Rope(x: 0, y: 0, length: 100)
        r.step(anchor: (50, 2), dt: Rope.step, damping: 0.9955)
        #expect(r.nodes[0].x == 50 && r.nodes[0].y == 2)
    }

    @Test func swingDiesDown() {
        var r = Rope(x: 0, y: 0, length: 150)
        r.nudge(dx: 25)
        for _ in 0..<10 { r.step(anchor: (0, 0), dt: Rope.step, damping: 0.9955) }
        let early = r.energy
        settle(&r, anchor: (0, 0))
        #expect(r.energy < early)
        #expect(r.energy < 0.05)
    }

    @Test func nudgeTiltsTheCharm() {
        var r = Rope(x: 0, y: 0, length: 150)
        r.nudge(dx: 15)
        for _ in 0..<30 { r.step(anchor: (0, 0), dt: Rope.step, damping: 0.9955) }
        #expect(abs(r.angle) > 0.01)
    }

    @Test func pinnedEndStaysPut() {
        var r = Rope(x: 0, y: 0, length: 150)
        r.nodes[r.nodes.count - 1].x = 60
        r.nodes[r.nodes.count - 1].px = 60
        r.nodes[r.nodes.count - 1].pinned = true
        for _ in 0..<50 { r.step(anchor: (0, 0), dt: Rope.step, damping: 0.9955) }
        #expect(r.end.x == 60)
    }
}

// MARK: - 90 days

@Suite struct NinetyDaysTests {
    var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }
    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    @Test func startDayIsDayOne() {
        let n = NinetyDays(goal: "write", start: date(2026, 10, 1, 23))
        #expect(n.day(on: date(2026, 10, 1, 1), calendar: cal) == 1)
        #expect(n.day(on: date(2026, 10, 2, 0), calendar: cal) == 2)
    }

    @Test func seriesDayNinetyIsDecember29() {
        let n = NinetyDays(goal: "", start: date(2026, 10, 1))
        #expect(n.day(on: date(2026, 12, 29), calendar: cal) == 90)
        #expect(n.bannerText(on: date(2026, 12, 29), calendar: cal) == "90 days done")
        #expect(n.bannerText(on: date(2026, 10, 12), calendar: cal) == "Day 12 / 90")
    }

    @Test func nothingResetsAfterAGap() {
        let n = NinetyDays(goal: "", start: date(2026, 10, 1))
        // Two weeks away changes nothing but the date.
        #expect(n.day(on: date(2026, 10, 20), calendar: cal) == 20)
    }

    @Test func neverBelowDayOne() {
        let n = NinetyDays(goal: "", start: date(2026, 11, 5))
        #expect(n.day(on: date(2026, 11, 1), calendar: cal) == 1)
    }

    @Test func daysLeftInYear() {
        #expect(NinetyDays.daysLeftInYear(on: date(2026, 10, 1), calendar: cal) == 92)
        #expect(NinetyDays.daysLeftInYear(on: date(2026, 12, 31), calendar: cal) == 1)
    }

    @Test func hoursLeft() {
        #expect(NinetyDays.hoursLeftToday(on: date(2026, 10, 1, 23), calendar: cal) == 1)
        #expect(NinetyDays.hoursLeftToday(on: date(2026, 10, 1, 0), calendar: cal) == 24)
        #expect(NinetyDays.hoursLeftInYear(on: date(2026, 12, 31, 12), calendar: cal) == 12)
        // Half past the hour rounds up, and the last minute of the year still says 1, never 0.
        #expect(NinetyDays.hoursLeftToday(on: date(2026, 10, 1, 23).addingTimeInterval(1800), calendar: cal) == 1)
        #expect(NinetyDays.hoursLeftInYear(on: date(2026, 12, 31, 23).addingTimeInterval(3540), calendar: cal) == 1)
    }

    @Test func hoursLeftOnClockChangeDays() {
        // New York: 8 Mar 2026 has 23 hours (spring forward), 1 Nov 2026 has 25 (fall back).
        var ny = Calendar(identifier: .gregorian)
        ny.timeZone = TimeZone(identifier: "America/New_York")!
        let spring = ny.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 0))!
        let fall = ny.date(from: DateComponents(year: 2026, month: 11, day: 1, hour: 0))!
        #expect(NinetyDays.hoursLeftToday(on: spring, calendar: ny) == 23)
        #expect(NinetyDays.hoursLeftToday(on: fall, calendar: ny) == 25)
    }

    @Test func bannerAlwaysFitsACharmAndNeverShames() {
        let n = NinetyDays(goal: "", start: date(2026, 10, 1))
        // Sweep every slot of the longest-text day of the year (1 Jan: "8,760 hours left…").
        for day in [date(2026, 1, 1, 0), date(2026, 10, 12, 0), date(2026, 12, 31, 0)] {
            for slot in 0..<144 {
                let t = day.addingTimeInterval(Double(slot) * 600)
                for line in [Copy.bannerLine(ninety: n, preferYearCountdown: false, on: t, calendar: cal),
                             Copy.bannerLine(ninety: nil, preferYearCountdown: false, on: t, calendar: cal),
                             Copy.bannerLine(ninety: n, preferYearCountdown: true, on: t, calendar: cal)] {
                    #expect(!line.isEmpty && line.count <= 28, "“\(line)” at \(t)")
                    for word in Copy.banned { #expect(!line.lowercased().contains(word)) }
                }
            }
        }
    }

    @Test func singularWordsReadRight() {
        #expect(Copy.hoursLeftToday(1) == "1 hour left of today")
        #expect(Copy.daysLeftInYear(1, year: 2026) == "last day of 2026!")
        #expect(Copy.daysLeftInYear(92, year: 2026) == "92 days left in 2026")
        #expect(Copy.hoursLeftInYear(2184, year: 2026) == "2,184 hours left in 2026")
    }

    @Test func bannerRotatesThroughTheDay() {
        let n = NinetyDays(goal: "", start: date(2026, 10, 1))
        func at(_ h: Int, _ m: Int) -> Date {
            cal.date(from: DateComponents(year: 2026, month: 10, day: 12, hour: h, minute: m))!
        }
        // Even ten-minute slots anchor on the day counter; the slots between rotate the time facts.
        #expect(Copy.bannerLine(ninety: n, preferYearCountdown: false, on: at(10, 0), calendar: cal) == "Day 12 / 90")
        #expect(Copy.bannerLine(ninety: n, preferYearCountdown: false, on: at(10, 10), calendar: cal) == "14 hours left of today")
        #expect(Copy.bannerLine(ninety: n, preferYearCountdown: false, on: at(10, 30), calendar: cal) == "81 days left in 2026")
        #expect(Copy.bannerLine(ninety: n, preferYearCountdown: false, on: at(10, 50), calendar: cal) == "1,934 hours left in 2026")
        // No 90 days started yet: the year countdown anchors instead.
        #expect(Copy.bannerLine(ninety: nil, preferYearCountdown: false, on: at(10, 0), calendar: cal) == "81 days left in 2026")
        #expect(Copy.bannerLine(ninety: nil, preferYearCountdown: false, on: at(10, 10), calendar: cal) == "14 hours left of today")
    }

    @Test func winsOnlyCountUp() {
        var jar = WinsJar()
        jar.add(date(2026, 10, 1)); jar.add(date(2026, 10, 5)); jar.add(date(2026, 10, 7))
        #expect(jar.total == 3)
        #expect(jar.thisWeek(on: date(2026, 10, 7), calendar: cal) == 3)
        #expect(jar.thisWeek(on: date(2026, 10, 9), calendar: cal) == 2)
    }
}

// MARK: - Focus clock

@Suite struct FocusClockTests {
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func countsDown() {
        var f = FocusClock()
        f.start(minutes: 25, at: t0)
        #expect(f.remainingText(at: t0) == "25")
        #expect(f.remainingText(at: t0.addingTimeInterval(60 * 24 + 18)) == "0:42")
        #expect(abs(f.progress(at: t0.addingTimeInterval(750)) - 0.5) < 0.001)
        #expect(!f.isDone(at: t0.addingTimeInterval(1499)))
        #expect(f.isDone(at: t0.addingTimeInterval(1500)))
    }

    @Test func stopClears() {
        var f = FocusClock()
        f.start(minutes: 15, at: t0)
        f.stop()
        #expect(!f.isRunning && !f.isDone(at: t0.addingTimeInterval(5000)))
    }

    @Test func lastMinuteReadsAsSeconds() {
        var f = FocusClock()
        f.start(minutes: 15, at: t0)
        #expect(f.remainingText(at: t0.addingTimeInterval(14 * 60)) == "1")      // exactly 1:00 left
        #expect(f.remainingText(at: t0.addingTimeInterval(14 * 60 + 1)) == "0:59")
        #expect(f.remainingText(at: t0.addingTimeInterval(15 * 60 - 1)) == "0:01")
        #expect(f.remainingText(at: t0.addingTimeInterval(15 * 60)) == "0:00")
    }

    @Test func sillyLengthsAreClamped() {
        var f = FocusClock()
        f.start(minutes: 0, at: t0)
        #expect(f.minutes == 1)      // never a zero-length session
        #expect(!f.isDone(at: t0))
    }
}

// MARK: - Never-shame copy

@Suite struct CopyTests {
    @Test func nothingShaming() {
        for line in Copy.everything {
            for word in Copy.banned {
                #expect(!line.lowercased().contains(word), "“\(line)” contains “\(word)”")
            }
        }
    }

    @Test func linesFitOnACharm() {
        for line in Copy.everything { #expect(line.count <= 28, "“\(line)” is too long for a charm") }
    }
}

// MARK: - Catalog + settings

@Suite struct CatalogTests {
    // mac/Tests/SwayblesCoreTests/CoreTests.swift → mac/Resources/Charms
    var charmsFolder: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Resources/Charms")
    }

    @Test func loadsAndEveryRingIsAtTheTop() throws {
        let cat = try Catalog(folder: charmsFolder)
        #expect(cat.charms.count >= 5)
        for c in cat.charms {
            #expect(c.ax > 0.3 && c.ax < 0.7, "\(c.id) ring off-centre")
            #expect(c.ay < 0.1, "\(c.id) ring not at the top")
        }
    }

    @Test func firstLaunchPicksInstalledCharms() throws {
        let cat = try Catalog(folder: charmsFolder)
        let s = Settings.firstLaunch(catalog: cat)
        #expect(!s.charms.isEmpty && s.charms.count <= 5)
        for p in s.charms { #expect(cat.charm(p.charmID) != nil) }
        #expect(s.charms.allSatisfy { $0.x > 0 && $0.x < 1 })
    }

    @Test func firstLaunchWithNoArtInstalledIsCalm() {
        let empty = Catalog(charms: [], folder: URL(fileURLWithPath: "/nowhere"))
        let s = Settings.firstLaunch(catalog: empty)
        #expect(s.charms.isEmpty)   // no crash, no ghosts of missing charms
    }

    @Test func oldSettingsStillLoad() throws {
        let json = #"{"size": 1.4, "rope": "no-such-rope"}"#.data(using: .utf8)!
        let s = try JSONDecoder().decode(Settings.self, from: json)
        #expect(s.size == 1.4 && s.rope == .goldThread && s.focusMinutes == 25)
        #expect(!s.still)   // settings saved before "Hold still" existed default to swinging
    }

    @Test func holdStillRoundTrips() throws {
        var s = Settings()
        s.still = true
        let back = try JSONDecoder().decode(Settings.self, from: JSONEncoder().encode(s))
        #expect(back.still)
    }
}
