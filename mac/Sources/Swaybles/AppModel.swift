import AppKit
import CoreGraphics
import Observation
import SwiftUI
import SwayblesCore

/// SwiftUI also has a `Settings` (a Scene); in this app, `Settings` means ours.
typealias Settings = SwayblesCore.Settings

/// What a charm shows on (or under) itself right now.
struct CharmText: Equatable {
    var text: String
    var progress: Double? = nil   // Timer Ghost's ring, 0...1
}

@Observable
final class AppModel {
    private(set) var settings: Settings
    let catalog: Catalog
    /// The person's own pictures, hung like charms (see PhotoCharms).
    private(set) var photos: Catalog
    private(set) var focus = FocusClock()
    private(set) var now = Date()
    private(set) var isDozing = false
    /// A short line (a cheer, "welcome back") shown for a little while.
    private(set) var message: (text: String, until: Date)?
    /// Cocoa Buddy's break, after a focus session.
    private(set) var breakUntil: Date?

    @ObservationIgnored weak var overlay: OverlayController?
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private let defaults: UserDefaults
    static let key = "settings.v1"

    /// Tests pass their own defaults and catalogs, so they never touch the person's real ones.
    init(defaults: UserDefaults = .standard, catalog: Catalog? = nil, photos: Catalog? = nil) {
        let catalog = catalog ?? (try? Catalog(folder: AppModel.charmsFolder())) ?? Catalog(charms: [], folder: AppModel.charmsFolder())
        let photos = photos ?? PhotoCharms.load()
        self.defaults = defaults
        self.catalog = catalog
        self.photos = photos
        if let data = defaults.data(forKey: AppModel.key),
           let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            var s = saved
            s.charms.removeAll { catalog.charm($0.charmID) == nil && photos.charm($0.charmID) == nil }   // a pack was removed
            settings = s
        } else {
            settings = Settings.firstLaunch(catalog: catalog)
        }
    }

    /// A charm by id, from the packs or from "My photos".
    func charm(_ id: String) -> Charm? { catalog.charm(id) ?? photos.charm(id) }

    func imageURL(for charm: Charm) -> URL {
        (charm.pack == "my-photos" ? photos : catalog).imageURL(for: charm)
    }

    // MARK: My photos

    /// Copies the picture in as a polaroid charm and hangs it. false if it couldn't be read.
    func addPhoto(from url: URL) -> Bool {
        guard let (cat, charm) = PhotoCharms.add(from: url) else { return false }
        photos = cat
        if !isOnScreen(charm.id) { toggle(charm.id) }
        return true
    }

    func removePhoto(_ id: String) {
        update { $0.charms.removeAll { $0.charmID == id } }
        photos = PhotoCharms.remove(id)
    }

    /// Packaged app: Swaybles.app/Contents/Resources/Charms. Running from Xcode or `swift run`:
    /// the repo's mac/Resources/Charms, found relative to this source file.
    static func charmsFolder() -> URL {
        if let r = Bundle.main.resourceURL?.appendingPathComponent("Charms"),
           FileManager.default.fileExists(atPath: r.appendingPathComponent("charms.json").path) {
            return r
        }
        return URL(fileURLWithPath: #filePath)            // mac/Sources/Swaybles/AppModel.swift
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Charms")
    }

    // MARK: Settings

    func update(_ change: (inout Settings) -> Void) {
        let before = settings
        change(&settings)
        guard settings != before else { return }
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: AppModel.key)
        }
        overlay?.settingsChanged(from: before)
    }

    func binding<T>(_ path: WritableKeyPath<Settings, T>) -> Binding<T> {
        Binding(get: { self.settings[keyPath: path] },
                set: { value in self.update { $0[keyPath: path] = value } })
    }

    var reduceMotion: Bool {
        settings.calmer || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    // MARK: Charms on screen

    func isOnScreen(_ id: String) -> Bool { settings.charms.contains { $0.charmID == id } }

    func toggle(_ id: String) {
        update { s in
            if s.charms.contains(where: { $0.charmID == id }) {
                s.charms.removeAll { $0.charmID == id }
            } else if s.charms.count < 8 {
                // Drop it in the widest gap between the charms already hanging.
                let xs = ([0.22] + s.charms.map(\.x) + [0.96]).sorted()
                var best = (gap: 0.0, x: 0.6)
                for (a, b) in zip(xs, xs.dropFirst()) where b - a > best.gap { best = (b - a, (a + b) / 2) }
                s.charms.append(PlacedCharm(charmID: id, x: best.x, length: Double.random(in: 100...190)))
            }
        }
    }

    // MARK: Focus

    func startFocus(minutes: Int? = nil) {
        focus.start(minutes: minutes ?? settings.focusMinutes, at: Date())
        breakUntil = nil
        now = Date()
        overlay?.nudgeAll(strength: 6)
        overlay?.labelsChanged()
    }

    func stopFocus() {
        focus.stop()
        overlay?.labelsChanged()
    }

    private func finishFocus(at t: Date) {
        focus.stop()
        update { $0.wins.add(t) }
        say(Copy.cheers.randomElement()!, for: 12, at: t)
        breakUntil = t.addingTimeInterval(5 * 60)
        overlay?.celebrate()
        if settings.sound { NSSound(named: "Glass")?.play() }
    }

    // MARK: 90 days

    func startNinety(goal: String) {
        update { $0.ninety = NinetyDays(goal: goal, start: Date()) }
        overlay?.celebrate()
    }

    func setGoal(_ goal: String) {
        update { s in
            if s.ninety == nil { s.ninety = NinetyDays(goal: goal, start: Date()) }
            else { s.ninety?.goal = goal }
        }
    }

    var bannerText: String {
        Copy.bannerLine(ninety: settings.ninety, preferYearCountdown: settings.showYearCountdown, on: now)
    }

    // MARK: What each charm says

    func say(_ text: String, for seconds: TimeInterval, at t: Date = Date()) {
        message = (text, t.addingTimeInterval(seconds))
        overlay?.labelsChanged()
    }

    /// Text for a charm, by its role. nil = nothing to show.
    func text(for charm: Charm) -> CharmText? {
        switch charm.role {
        case .timer?:
            guard focus.isRunning else { return CharmText(text: "\(settings.focusMinutes)") }   // tap me to start
            return CharmText(text: focus.remainingText(at: now), progress: focus.progress(at: now))
        case .banner?:
            return CharmText(text: bannerText)
        case .task?:
            let goal = settings.ninety?.goal.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return CharmText(text: goal.isEmpty ? Copy.noGoalYet : goal)
        case .quote?:
            if let m = message { return CharmText(text: m.text) }
            let week = settings.wins.thisWeek(on: now)
            if week > 0, Calendar.current.component(.hour, from: now) % 2 == 0 {
                return CharmText(text: Copy.weeklyWins(week))
            }
            return CharmText(text: Copy.pick(Copy.kindWords, on: now))
        case .break?:
            guard let b = breakUntil, b > now else { return nil }
            return CharmText(text: Copy.pick(Copy.breakTime, on: now))
        case nil:
            return nil
        }
    }

    /// A message with no Chalkboard Cat on screen shows under the first charm instead.
    var looseMessage: String? {
        guard let m = message, !settings.charms.contains(where: { charm($0.charmID)?.role == .quote }) else { return nil }
        return m.text
    }

    /// The day counter with no Banner Bat on screen hangs as a tag under the first charm instead,
    /// so the calendar is always in view.
    var looseBanner: String? {
        guard !settings.charms.contains(where: { charm($0.charmID)?.role == .banner }) else { return nil }
        return bannerText
    }

    // MARK: Clock: focus, idle, messages

    func startTicking() {
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        timer?.tolerance = 0.2
    }

    @ObservationIgnored private var ticks = 0

    func tick(at t: Date = Date()) {
        let minuteChanged = Calendar.current.component(.minute, from: t) != Calendar.current.component(.minute, from: now)
        now = t
        if focus.isDone(at: t) { finishFocus(at: t) }
        if let m = message, m.until <= t { message = nil; overlay?.labelsChanged() }
        if let b = breakUntil, b <= t { breakUntil = nil; overlay?.labelsChanged() }
        ticks += 1
        if ticks % 5 == 0 || isDozing { checkIdle() }
        if focus.isRunning || minuteChanged { overlay?.labelsChanged() }
    }

    /// System idle time: seconds since the last mouse/keyboard input. Needs no permission
    /// and tells us nothing about what the person is doing, only that they stepped away.
    private func checkIdle() { applyIdle(seconds: idleSeconds()) }

    /// Seconds since the last input. A property so tests can stand in for the real keyboard and mouse.
    @ObservationIgnored var idleSeconds: () -> Double = {
        CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)
    }

    /// Doze after the chosen idle time (never mid-focus); wake, with a "welcome back", once input returns.
    func applyIdle(seconds idle: Double) {
        if !isDozing, idle >= Double(settings.idleMinutes * 60), !focus.isRunning {
            isDozing = true
            overlay?.dozeChanged()
        } else if isDozing, idle < 5 {
            isDozing = false
            say(Copy.welcomeBack.randomElement()!, for: 10)
            overlay?.dozeChanged()
        }
    }
}
