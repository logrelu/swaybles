// "Make the most of the next 90 days": one goal and a day counter.
// The counter is a calendar, not a streak. It counts days since the person started,
// nothing resets, and there is no such thing as a missed day.
import Foundation

public struct NinetyDays: Codable, Equatable {
    public static let length = 90

    public var goal: String
    public var start: Date          // the day they pressed Start (any time on that day)

    public init(goal: String, start: Date) {
        self.goal = goal
        self.start = start
    }

    /// Day number on `date`: 1 on the start day, 90 on the last day, keeps counting after.
    public func day(on date: Date, calendar: Calendar = .current) -> Int {
        let from = calendar.startOfDay(for: start)
        let to = calendar.startOfDay(for: date)
        let days = calendar.dateComponents([.day], from: from, to: to).day ?? 0
        return max(1, days + 1)
    }

    public func isFinished(on date: Date, calendar: Calendar = .current) -> Bool {
        day(on: date, calendar: calendar) >= NinetyDays.length
    }

    /// What Banner Bat shows: "Day 12 / 90", or "90 days done" from day 90 on.
    public func bannerText(on date: Date, calendar: Calendar = .current) -> String {
        let d = day(on: date, calendar: calendar)
        return d >= NinetyDays.length ? "90 days done" : "Day \(d) / \(NinetyDays.length)"
    }

    /// Days left in the calendar year, for people who'd rather follow the series count.
    public static func daysLeftInYear(on date: Date, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: date)
        guard let newYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return 0 }
        return calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: newYear).day ?? 0
    }

    /// Whole hours until midnight, rounded up: 24 at breakfast-at-midnight, 1 at 23:59.
    public static func hoursLeftToday(on date: Date, calendar: Calendar = .current) -> Int {
        guard let midnight = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: date)) else { return 0 }
        return max(1, Int(ceil(midnight.timeIntervalSince(date) / 3600)))
    }

    /// Whole hours until New Year, rounded up.
    public static func hoursLeftInYear(on date: Date, calendar: Calendar = .current) -> Int {
        let year = calendar.component(.year, from: date)
        guard let newYear = calendar.date(from: DateComponents(year: year + 1, month: 1, day: 1)) else { return 0 }
        return max(1, Int(ceil(newYear.timeIntervalSince(date) / 3600)))
    }
}

/// Finished focus sessions. It only ever counts up.
public struct WinsJar: Codable, Equatable {
    public var sessions: [Date] = []

    public init(sessions: [Date] = []) { self.sessions = sessions }

    public mutating func add(_ date: Date) { sessions.append(date) }

    public var total: Int { sessions.count }

    /// Sessions finished in the 7 days up to and including `date`.
    public func thisWeek(on date: Date, calendar: Calendar = .current) -> Int {
        let today = calendar.startOfDay(for: date)
        guard let from = calendar.date(byAdding: .day, value: -6, to: today),
              let to = calendar.date(byAdding: .day, value: 1, to: today) else { return 0 }
        return sessions.filter { $0 >= from && $0 < to }.count
    }
}
