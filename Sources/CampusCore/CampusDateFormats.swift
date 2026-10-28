import Foundation

/// Formatters stay behind one lock; none escape to concurrent callers.
final class CampusDateFormats: @unchecked Sendable {
    static let shared = CampusDateFormats()
    private let lock = NSLock()
    private var values: [String: DateFormatter] = [:]
    private func formatter(_ pattern: String) -> DateFormatter {
        if let existing = values[pattern] { return existing }
        let value = DateFormatter()
        value.locale = Locale(identifier: "en_US_POSIX")
        value.timeZone = TimeZone(identifier: "Asia/Shanghai")
        value.dateFormat = pattern
        values[pattern] = value
        return value
    }
    func string(_ date: Date, pattern: String) -> String {
        lock.withLock { formatter(pattern).string(from: date) }
    }
    func date(_ text: String, pattern: String) -> Date? {
        lock.withLock { formatter(pattern).date(from: text) }
    }
}
