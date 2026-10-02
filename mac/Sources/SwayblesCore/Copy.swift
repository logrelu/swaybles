// Every word the charms say. Rule: never shame. No guilt, no "missed", no failure counts.
// tests/CopyTests checks these lists against banned words; add new lines here, not in views.
import Foundation

public enum Copy {
    /// Chalkboard Cat, now and then.
    public static let kindWords = [
        "you showed up",
        "one step counts",
        "tiny steps are steps",
        "start messy, that's fine",
        "you're doing the thing",
        "proud of you",
        "small wins stack up",
        "rest is part of it",
    ]

    /// When a focus session finishes.
    public static let cheers = [
        "you did it!",
        "high five!",
        "look at you go",
        "that's a win",
        "done and done",
    ]

    /// After stepping away (system idle), when they come back.
    public static let welcomeBack = [
        "welcome back",
        "hey, you're back",
        "good to see you",
    ]

    /// Cocoa Buddy, on breaks.
    public static let breakTime = [
        "sip, stretch, back in 5",
        "water break?",
        "shoulders down, breathe",
    ]

    /// Task Lantern when no goal is set yet.
    public static let noGoalYet = "pick one thing"

    /// Chalkboard Cat's weekly line. Only ever counts up.
    public static func weeklyWins(_ n: Int) -> String {
        switch n {
        case 0: return "fresh week, fresh start"
        case 1: return "1 focus win this week"
        default: return "\(n) focus wins this week"
        }
    }

    // MARK: Banner Bat's little time facts (a calendar, not a deadline)

    public static func hoursLeftToday(_ n: Int) -> String {
        n == 1 ? "1 hour left of today" : "\(n) hours left of today"
    }

    public static func daysLeftInYear(_ n: Int, year: Int) -> String {
        n == 1 ? "last day of \(year)!" : "\(number(n)) days left in \(year)"
    }

    public static func hoursLeftInYear(_ n: Int, year: Int) -> String {
        "\(number(n)) hours left in \(year)"
    }

    /// The tag under the charms: the day counter on even ten-minute slots, a time fact between.
    public static func bannerLine(ninety: NinetyDays?, preferYearCountdown: Bool,
                                  on date: Date, calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: date)
        let countdown = daysLeftInYear(NinetyDays.daysLeftInYear(on: date, calendar: calendar), year: year)
        let base = preferYearCountdown || ninety == nil
            ? countdown : ninety!.bannerText(on: date, calendar: calendar)
        var facts = [hoursLeftToday(NinetyDays.hoursLeftToday(on: date, calendar: calendar)),
                     hoursLeftInYear(NinetyDays.hoursLeftInYear(on: date, calendar: calendar), year: year)]
        if base != countdown { facts.insert(countdown, at: 1) }
        let slot = (calendar.component(.hour, from: date) * 60 + calendar.component(.minute, from: date)) / 10
        return slot.isMultiple(of: 2) ? base : facts[(slot / 2) % facts.count]
    }

    private static func number(_ n: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_US")   // the copy is English; keep "2,184" stable everywhere
        return f.string(from: NSNumber(value: n)) ?? "\(n)"
    }

    /// Words that must never appear in anything the charms say.
    public static let banned = ["fail", "missed", "lazy", "unproductive", "should have", "behind", "streak lost", "wasted", "again?"]

    public static var everything: [String] {
        kindWords + cheers + welcomeBack + breakTime + [noGoalYet] + (0...10).map(weeklyWins)
            + [hoursLeftToday(1), hoursLeftToday(7), daysLeftInYear(1, year: 2026),
               daysLeftInYear(91, year: 2026), hoursLeftInYear(2184, year: 2026)]
    }

    /// A line that changes once a day, not every frame.
    public static func pick(_ list: [String], on date: Date, calendar: Calendar = .current) -> String {
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return list[day % list.count]
    }
}
