import Foundation
import Testing
import SwayblesCore
@testable import Swaybles

// A model that reads and writes its own throwaway defaults, with a small made-up catalog.
@MainActor
struct Fixture {
    let defaults: UserDefaults
    let model: AppModel
    let suite: String

    static let charms = [
        Charm(id: "boo", name: "Boo", pack: "p", theme: "Spooky", file: "charms/p/boo.png", w: 100, h: 100, ax: 0.5, ay: 0.1),
        Charm(id: "ghost", name: "Timer Ghost", pack: "p", theme: "Spooky", file: "charms/p/ghost.png", w: 100, h: 100, ax: 0.5, ay: 0.1, role: .timer),
        Charm(id: "bat", name: "Banner Bat", pack: "p", theme: "Spooky", file: "charms/p/bat.png", w: 100, h: 100, ax: 0.5, ay: 0.1, role: .banner),
        Charm(id: "lantern", name: "Task Lantern", pack: "p", theme: "Spooky", file: "charms/p/lantern.png", w: 100, h: 100, ax: 0.5, ay: 0.1, role: .task),
        Charm(id: "cat", name: "Chalkboard Cat", pack: "p", theme: "Spooky", file: "charms/p/cat.png", w: 100, h: 100, ax: 0.5, ay: 0.1, role: .quote),
        Charm(id: "cocoa", name: "Cocoa Buddy", pack: "p", theme: "Spooky", file: "charms/p/cocoa.png", w: 100, h: 100, ax: 0.5, ay: 0.1, role: .break),
    ]
    static var catalog: Catalog { Catalog(charms: charms, folder: URL(fileURLWithPath: "/nonexistent")) }
    static var noPhotos: Catalog { Catalog(charms: [], folder: URL(fileURLWithPath: "/nonexistent")) }

    init(saved: Settings? = nil) {
        suite = "swaybles-tests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        if let saved { defaults.set(try! JSONEncoder().encode(saved), forKey: AppModel.key) }
        model = AppModel(defaults: defaults, catalog: Fixture.catalog, photos: Fixture.noPhotos)
        model.idleSeconds = { 0 }
    }

    func cleanUp() { defaults.removePersistentDomain(forName: suite) }

    func reload() -> AppModel { AppModel(defaults: defaults, catalog: Fixture.catalog, photos: Fixture.noPhotos) }
}

@MainActor @Suite struct LaunchTests {
    @Test func firstLaunchHangsJustBoo() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.settings.charms.map(\.charmID) == ["boo"])
    }

    @Test func savedSettingsComeBack() {
        var s = Settings(); s.focusMinutes = 45; s.charms = [PlacedCharm(charmID: "cat", x: 0.3, length: 120)]
        let f = Fixture(saved: s); defer { f.cleanUp() }
        #expect(f.model.settings.focusMinutes == 45)
        #expect(f.model.settings.charms.map(\.charmID) == ["cat"])
    }

    @Test func aRemovedPackDropsItsCharmsButKeepsTheRest() {
        var s = Settings(); s.sound = false
        s.charms = [PlacedCharm(charmID: "boo", x: 0.3, length: 120), PlacedCharm(charmID: "gone", x: 0.5, length: 120)]
        let f = Fixture(saved: s); defer { f.cleanUp() }
        #expect(f.model.settings.charms.map(\.charmID) == ["boo"])
        #expect(f.model.settings.sound == false)
    }

    @Test func garbageInDefaultsFallsBackToFirstLaunch() {
        let f = Fixture(); defer { f.cleanUp() }
        f.defaults.set(Data("not json".utf8), forKey: AppModel.key)
        #expect(f.reload().settings.charms.map(\.charmID) == ["boo"])
    }

    @Test func changesAreSavedAndReloaded() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.focusMinutes = 15; $0.breeze = true }
        let again = f.reload()
        #expect(again.settings.focusMinutes == 15 && again.settings.breeze)
    }

    @Test func theRealDefaultsAreNotTouched() {
        let before = UserDefaults.standard.data(forKey: AppModel.key)
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.focusMinutes = 45 }
        #expect(UserDefaults.standard.data(forKey: AppModel.key) == before)
    }
}

@MainActor @Suite struct HangingCharmsTests {
    @Test func toggleHangsAndUnhangs() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.toggle("cat")
        #expect(f.model.isOnScreen("cat"))
        f.model.toggle("cat")
        #expect(!f.model.isOnScreen("cat"))
    }

    @Test func atMostEightHang() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.charms = (0..<8).map { PlacedCharm(charmID: "boo", x: 0.1 * Double($0 + 1), length: 100) } }
        f.model.toggle("cat")
        #expect(f.model.settings.charms.count == 8)
        #expect(!f.model.isOnScreen("cat"))
    }

    @Test func aNewCharmLandsInTheWidestGap() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.charms = [PlacedCharm(charmID: "boo", x: 0.3, length: 100), PlacedCharm(charmID: "bat", x: 0.9, length: 100)] }
        f.model.toggle("cat")
        let x = f.model.settings.charms.last!.x
        #expect(abs(x - 0.6) < 0.001)   // between 0.3 and 0.9, the biggest gap
    }

    @Test func newRopeLengthsStayInRange() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.toggle("cat")
        #expect((100...190).contains(f.model.settings.charms.last!.length))
    }

    @Test func unknownCharmIDsAreNotFound() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.charm("nope") == nil)
        #expect(f.model.charm("boo")?.name == "Boo")
    }
}

@MainActor @Suite struct FocusTests {
    let t0 = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func startUsesTheChosenMinutes() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.focusMinutes = 45 }
        f.model.startFocus()
        #expect(f.model.focus.isRunning && f.model.focus.minutes == 45)
        f.model.startFocus(minutes: 15)
        #expect(f.model.focus.minutes == 15)
    }

    @Test func stopEndsWithNoCheerAndNoWin() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus()
        f.model.stopFocus()
        #expect(!f.model.focus.isRunning)
        #expect(f.model.message == nil)
        #expect(f.model.settings.wins.sessions.isEmpty)
    }

    @Test func finishingCheersCountsAWinAndStartsABreak() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus(minutes: 15)
        let start = f.model.focus.startedAt!
        f.model.tick(at: start.addingTimeInterval(15 * 60 + 1))
        #expect(!f.model.focus.isRunning)
        #expect(f.model.settings.wins.sessions.count == 1)
        #expect(Copy.cheers.contains(f.model.message?.text ?? ""))
        #expect(f.model.breakUntil != nil)
    }

    @Test func nothingHappensBeforeTheTimeIsUp() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus(minutes: 15)
        let start = f.model.focus.startedAt!
        f.model.tick(at: start.addingTimeInterval(15 * 60 - 5))
        #expect(f.model.focus.isRunning)
        #expect(f.model.settings.wins.sessions.isEmpty)
    }

    @Test func aFinishedWinSurvivesARelaunch() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus(minutes: 15)
        f.model.tick(at: f.model.focus.startedAt!.addingTimeInterval(15 * 60 + 1))
        #expect(f.reload().settings.wins.sessions.count == 1)
    }

    @Test func messagesAndBreaksExpireOnTheirOwn() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus(minutes: 15)
        let done = f.model.focus.startedAt!.addingTimeInterval(15 * 60 + 1)
        f.model.tick(at: done)
        f.model.tick(at: done.addingTimeInterval(13))
        #expect(f.model.message == nil)
        #expect(f.model.breakUntil != nil)
        f.model.tick(at: done.addingTimeInterval(5 * 60 + 1))
        #expect(f.model.breakUntil == nil)
    }
}

@MainActor @Suite struct DozingTests {
    @Test func dozesAfterTheIdleTime() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.applyIdle(seconds: 5 * 60 - 1)
        #expect(!f.model.isDozing)
        f.model.applyIdle(seconds: 5 * 60)
        #expect(f.model.isDozing)
    }

    @Test func respectsAChosenIdleTime() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.update { $0.idleMinutes = 10 }
        f.model.applyIdle(seconds: 9 * 60)
        #expect(!f.model.isDozing)
        f.model.applyIdle(seconds: 10 * 60)
        #expect(f.model.isDozing)
    }

    @Test func neverDozesDuringFocus() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startFocus()
        f.model.applyIdle(seconds: 3600)
        #expect(!f.model.isDozing)
    }

    @Test func wakesWithAWarmWelcomeBackNotAScolding() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.applyIdle(seconds: 600)
        #expect(f.model.isDozing)
        f.model.applyIdle(seconds: 2)
        #expect(!f.model.isDozing)
        #expect(Copy.welcomeBack.contains(f.model.message?.text ?? ""))
    }

    @Test func staysAsleepUntilRealInputReturns() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.applyIdle(seconds: 600)
        f.model.applyIdle(seconds: 30)
        #expect(f.model.isDozing)
    }

    @Test func tickAsksTheIdleSourceOnTheFifthSecond() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.idleSeconds = { 600 }
        let t = Date()
        for i in 1...4 { f.model.tick(at: t.addingTimeInterval(Double(i))) }
        #expect(!f.model.isDozing)
        f.model.tick(at: t.addingTimeInterval(5))
        #expect(f.model.isDozing)
    }
}

@MainActor @Suite struct CharmTextTests {
    func charm(_ id: String) -> Charm { Fixture.charms.first { $0.id == id }! }

    @Test func plainCharmsSayNothing() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.text(for: charm("boo")) == nil)
    }

    @Test func timerGhostShowsTheMinutesThenTheCountdown() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.text(for: charm("ghost")) == CharmText(text: "25"))
        f.model.startFocus(minutes: 15)
        let t = f.model.text(for: charm("ghost"))
        #expect(t?.progress != nil)
    }

    @Test func taskLanternShowsTheGoalOrAGentleNudge() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.text(for: charm("lantern"))?.text == Copy.noGoalYet)
        f.model.setGoal("   ")
        #expect(f.model.text(for: charm("lantern"))?.text == Copy.noGoalYet)
        f.model.setGoal("reply to Sam")
        #expect(f.model.text(for: charm("lantern"))?.text == "reply to Sam")
    }

    @Test func chalkboardCatPrefersAMessage() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.say("you showed up", for: 10)
        #expect(f.model.text(for: charm("cat"))?.text == "you showed up")
    }

    @Test func chalkboardCatOtherwiseSaysSomethingKind() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(Copy.kindWords.contains(f.model.text(for: charm("cat"))?.text ?? ""))
    }

    @Test func cocoaBuddyOnlyAppearsOnABreak() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.text(for: charm("cocoa")) == nil)
        f.model.startFocus(minutes: 15)
        f.model.tick(at: f.model.focus.startedAt!.addingTimeInterval(15 * 60 + 1))
        let text = f.model.text(for: charm("cocoa"))?.text ?? ""
        #expect(Copy.breakTime.contains(text))
    }

    @Test func bannerShowsTheDayOnceStarted() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startNinety(goal: "ship it")
        #expect(f.model.text(for: charm("bat"))?.text == f.model.bannerText)
        #expect(f.model.bannerText.contains("1"))
    }

    @Test func setGoalBeforeStartingBeginsTheNinetyDays() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.settings.ninety == nil)
        f.model.setGoal("write")
        #expect(f.model.settings.ninety?.goal == "write")
    }

    @Test func setGoalAfterStartingKeepsTheStartDate() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.startNinety(goal: "a")
        let start = f.model.settings.ninety!.start
        f.model.setGoal("b")
        #expect(f.model.settings.ninety?.start == start)
        #expect(f.model.settings.ninety?.goal == "b")
    }
}

@MainActor @Suite struct LooseTextTests {
    @Test func aLooseMessageShowsOnlyWithoutAChalkboardCat() {
        let f = Fixture(); defer { f.cleanUp() }
        f.model.say("hi", for: 10)
        #expect(f.model.looseMessage == "hi")
        f.model.update { $0.charms.append(PlacedCharm(charmID: "cat", x: 0.8, length: 100)) }
        #expect(f.model.looseMessage == nil)
    }

    @Test func theCalendarIsAlwaysInViewOneWayOrAnother() {
        let f = Fixture(); defer { f.cleanUp() }
        #expect(f.model.looseBanner != nil)
        f.model.update { $0.charms.append(PlacedCharm(charmID: "bat", x: 0.8, length: 100)) }
        #expect(f.model.looseBanner == nil)
    }
}

/// The never-shame rule, checked against the real words the app can show.
@MainActor @Suite struct NeverShameTests {
    @Test func everythingTheAppCanSayIsKind() {
        let f = Fixture(); defer { f.cleanUp() }
        var said = Copy.everything
        said += [f.model.bannerText, Copy.noGoalYet]
        for line in said {
            for word in Copy.banned { #expect(!line.lowercased().contains(word), "“\(line)” contains “\(word)”") }
        }
    }
}
