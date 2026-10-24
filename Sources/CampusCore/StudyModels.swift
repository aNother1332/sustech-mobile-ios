import Foundation

public struct PeriodTime: Identifiable, Equatable, Codable, Sendable {
    public var id: Int { period }
    public let period: Int
    public let start: String
    public let end: String
    public init(period: Int, start: String, end: String) { self.period = period; self.start = start; self.end = end }
}

public struct GradeRecord: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let code: String
    public let name: String
    public let term: String
    public let credits: Double
    public let display: String
    public let score: String
    public let reportedPoints: Double?
    public let category: String
    public init(id: String, code: String, name: String, term: String, credits: Double,
                display: String, score: String, reportedPoints: Double?, category: String) {
        self.id = id; self.code = code; self.name = name; self.term = term; self.credits = credits
        self.display = display; self.score = score; self.reportedPoints = reportedPoints; self.category = category
    }
    /// A reproducible, explicitly local estimate. No guessing numerical-score rules.
    public var estimatedPoints: Double? {
        let table: [String: Double] = ["A+": 4, "A": 3.94, "A-": 3.85, "B+": 3.73, "B": 3.55,
            "B-": 3.32, "C+": 3.09, "C": 2.78, "C-": 2.42, "D+": 2.08, "D": 1.63, "D-": 1.15, "F": 0]
        return reportedPoints ?? table[display.uppercased().trimmingCharacters(in: .whitespaces)]
    }
}

public struct GradeSummary: Equatable, Sendable {
    public let points: Double?
    public let includedCredits: Double
    public let excludedCount: Int
    public init(records: [GradeRecord]) {
        let included = records.filter { $0.credits > 0 && $0.estimatedPoints != nil }
        includedCredits = included.reduce(0) { $0 + $1.credits }
        points = includedCredits > 0 ? included.reduce(0) { $0 + $1.credits * ($1.estimatedPoints ?? 0) } / includedCredits : nil
        excludedCount = records.count - included.count
    }
}

public struct AcademicSnapshot: Codable, Sendable {
    public let records: [GradeRecord]
    public init(records: [GradeRecord]) { self.records = records }
}

public struct BBAnnouncement: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let created: String
    public init(id: String, title: String, body: String, created: String) {
        self.id = id; self.title = title; self.body = body; self.created = created
    }
}

public struct BBContent: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let title: String
    public let body: String
    public let hasChildren: Bool
    public let handler: String
    public let file: String?
    public init(id: String, title: String, body: String, hasChildren: Bool, handler: String, file: String? = nil) {
        self.id = id; self.title = title; self.body = body; self.hasChildren = hasChildren; self.handler = handler; self.file = file
    }
}

public struct BBAttachment: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let path: String
    public init(id: String, name: String, path: String) { self.id = id; self.name = name; self.path = path }
}

public struct BBCourseDetail: Codable, Sendable {
    public let tasks: [LearningDeadline]
    public let announcements: [BBAnnouncement]
    public let warnings: [String]
    public let updated: Date
    public let tasksRead: Bool
    public let announcementsRead: Bool
    public let tasksUpdated: Date?
    public let announcementsUpdated: Date?
    public init(tasks: [LearningDeadline], announcements: [BBAnnouncement], warnings: [String], updated: Date = .now,
                tasksRead: Bool = true, announcementsRead: Bool = true, tasksUpdated: Date? = nil, announcementsUpdated: Date? = nil) {
        self.tasks = tasks; self.announcements = announcements; self.warnings = warnings; self.updated = updated
        self.tasksRead = tasksRead; self.announcementsRead = announcementsRead
        self.tasksUpdated = tasksUpdated ?? (tasksRead ? updated : nil)
        self.announcementsUpdated = announcementsUpdated ?? (announcementsRead ? updated : nil)
    }

    public func retainingUnreadSections(from previous: BBCourseDetail?) -> BBCourseDetail {
        guard let previous else { return self }
        let retained = !tasksRead || !announcementsRead
        return BBCourseDetail(tasks: tasksRead ? tasks : previous.tasks,
            announcements: announcementsRead ? announcements : previous.announcements,
            warnings: warnings + (retained ? ["读取失败的部分保留旧缓存，请核对该部分的数据时间。"] : []), updated: updated,
            tasksRead: tasksRead, announcementsRead: announcementsRead,
            tasksUpdated: tasksRead ? tasksUpdated : previous.tasksUpdated,
            announcementsUpdated: announcementsRead ? announcementsUpdated : previous.announcementsUpdated)
    }
}
