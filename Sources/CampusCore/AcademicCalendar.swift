import Foundation

/// Calendar data is pinned to sustech-calendar e5e102c7; no inferred public holidays.
public struct AcademicTerm: Sendable {
    public let monday: Date
    public let start: Date
    public let end: Date
    public let holidays: [Holiday]
    public let makeup: [Makeup]
    public let breaks: Set<String>
    public let finalWeeks: Set<Int>
    private let teachingStart: Date
    private let finalStart: Date?
    public struct Holiday: Sendable { public let name: String; public let start: Date; public let end: Date }
    public struct Makeup: Sendable { public let date: Date; public let weekday: Int; public let parity: Int }
    public static var calendar: Calendar {
        var value = Calendar(identifier: .gregorian); value.timeZone = TimeZone(identifier: "Asia/Shanghai")!; value.firstWeekday = 2; return value
    }
    public init?(level: WireValue, general: WireValue, season: String) {
        let term = level[season + "_semester"]
        guard let teaching = CampusClock.date(term["teaching_start"].text),
              let start = CampusClock.date(term["sign_in"].text),
              let end = CampusClock.date(term["final"]["end"].text) else { return nil }
        self.start = start; self.end = end
        teachingStart = teaching; finalStart = CampusClock.date(term["final"]["start"].text)
        let day = (Self.calendar.component(.weekday, from: teaching) + 5) % 7
        monday = Self.calendar.date(byAdding: .day, value: -day, to: teaching)!
        holidays = general["holidays"].rows.compactMap { row in
            guard let a = CampusClock.date(row["start"].text), let b = CampusClock.date(row["end"].text) else { return nil }
            return Holiday(name: row["name"].text, start: a, end: b)
        }
        let days = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
        makeup = term["compensatories"].rows.compactMap { row in
            guard let date = CampusClock.date(row["date"].text), let day = days.firstIndex(of: row["workday_type"].text.lowercased()), ["odd", "even"].contains(row["week_type"].text) else { return nil }
            return Makeup(date: date, weekday: day + 1, parity: row["week_type"].text == "odd" ? 1 : 0)
        }
        breaks = Set(term["extra_breaks"].rows.map(\.text)); finalWeeks = Set(term["final"]["equivalent_weeks"].rows.compactMap(\.int))
    }
    public func contains(_ date: Date) -> Bool { let day = Self.calendar.startOfDay(for: date); return day >= start && day <= end }
    public func week(_ date: Date) -> Int { (Self.calendar.dateComponents([.day], from: monday, to: Self.calendar.startOfDay(for: date)).day ?? 0) / 7 + 1 }
    public func date(week: Int, weekday: Int) -> Date? {
        guard (1...40).contains(week), (1...7).contains(weekday) else { return nil }
        return Self.calendar.date(byAdding: .day, value: (week - 1) * 7 + weekday - 1, to: monday)
    }
    public func holiday(_ date: Date) -> String? { let day = Self.calendar.startOfDay(for: date); return holidays.first { day >= $0.start && day <= $0.end }?.name }
    private func source(for item: Makeup) -> Date? {
        var candidates: [Date] = []
        for holiday in holidays {
            var day = holiday.start
            while day <= holiday.end {
                if day >= monday, day <= end, (Self.calendar.component(.weekday, from: day) + 5) % 7 + 1 == item.weekday, week(day) % 2 == item.parity { candidates.append(day) }
                day = Self.calendar.date(byAdding: .day, value: 1, to: day)!
            }
        }
        return candidates.filter { $0 <= item.date }.max() ?? candidates.min()
    }
    public func dates(weeks: [Int], weekday: Int) -> [Date] {
        var output = Set<Date>()
        for week in weeks {
            guard let day = date(week: week, weekday: weekday), day >= monday, day <= end else { continue }
            // Preserve explicitly scheduled weekend classes, unless this is a makeup destination.
            if makeup.contains(where: { $0.date == day }) { continue }
            if holiday(day) != nil || breaks.contains(CampusClock.format(day)) || finalWeeks.contains(week) || finalStart.map({ day >= $0 }) == true {
                if let replacement = makeup.first(where: { $0.weekday == weekday && $0.parity == week % 2 && source(for: $0) == day }) { output.insert(replacement.date) }
            } else if day >= teachingStart { output.insert(day) }
        }
        return output.sorted()
    }
}
