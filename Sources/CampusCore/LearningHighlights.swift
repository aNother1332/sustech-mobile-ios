import Foundation

public enum LearningHighlights {
    public static func nextSubmission(_ items: [LearningDeadline], now: Date = .now) -> LearningDeadline? {
        items.filter { item in
            guard let due = item.due, due > now else { return false }
            return item.submission == .pending || item.submission == .draft
        }.min { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) }
    }
    public static func nextExam(_ items: [CampusExam], now: Date = .now) -> CampusExam? {
        items.compactMap { item -> (CampusExam, Date)? in
            guard let time = HTMLText.captures("[0-9]{1,2}:[0-9]{2}", in: item.time).first?[0],
                  let start = CampusClock.date(item.date + " " + time, "yyyy-MM-dd HH:mm"), start >= now else { return nil }
            return (item, start)
        }.min { $0.1 < $1.1 }?.0
    }
}
