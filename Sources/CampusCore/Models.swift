import Foundation

public struct Semester: Equatable, Codable, Sendable {
    public let year: String
    public let term: String
    public let name: String

    public init(year: String, term: String, name: String) {
        self.year = year
        self.term = term
        self.name = name
    }
}

public struct CourseMeeting: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let details: String
    public let weekday: Int
    public let firstPeriod: Int
    public let lastPeriod: Int
    public let weeks: [Int]?

    public init(id: String, name: String, details: String, weekday: Int,
                firstPeriod: Int, lastPeriod: Int, weeks: [Int]? = nil) {
        self.id = id
        self.name = name
        self.details = details
        self.weekday = weekday
        self.firstPeriod = firstPeriod
        self.lastPeriod = lastPeriod
        self.weeks = weeks
    }
}

public struct CampusExam: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let course: String
    public let date: String
    public let time: String
    public let room: String
    public let seat: String

    public init(id: String, course: String, date: String, time: String,
                room: String, seat: String) {
        self.id = id
        self.course = course
        self.date = date
        self.time = time
        self.room = room
        self.seat = seat
    }
}

public struct BlackboardCourse: Identifiable, Equatable, Codable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct LearningDeadline: Identifiable, Equatable, Codable, Sendable {
    public enum Submission: String, Codable, Sendable {
        // A deadline alone is never evidence that an assignment is pending.
        case unknown
        case submitted
        case pending
        case draft
        case exempt
    }

    public let id: String
    public let course: String
    public let title: String
    public let due: Date?
    public let rawDue: String
    public let submission: Submission
    public let courseID: String
    public let contentID: String?
    public let details: String
    public let statusNote: String

    public init(id: String, course: String, title: String, due: Date?,
                rawDue: String, submission: Submission = .unknown, courseID: String = "", contentID: String? = nil,
                details: String = "", statusNote: String = "") {
        self.id = id
        self.course = course
        self.title = title
        self.due = due
        self.rawDue = rawDue
        self.submission = submission
        self.courseID = courseID
        self.contentID = contentID
        self.details = details
        self.statusNote = statusNote
    }
}

public struct TeachingSnapshot: Codable, Sendable {
    public let fullSemester: Bool
    public let periods: [PeriodTime]

    public let semester: Semester
    public let week: Int?
    public let meetings: [CourseMeeting]
    public let exams: [CampusExam]
    public let warnings: [String]

    public init(semester: Semester, week: Int?, meetings: [CourseMeeting],
                exams: [CampusExam], warnings: [String] = [],
                fullSemester: Bool = false, periods: [PeriodTime] = []) {
        self.fullSemester = fullSemester
        self.periods = periods
        self.semester = semester
        self.week = week
        self.meetings = meetings
        self.exams = exams
        self.warnings = warnings
    }
}

public struct BlackboardSnapshot: Codable, Sendable {
    public let courses: [BlackboardCourse]
    public let deadlines: [LearningDeadline]
    public let warnings: [String]

    public init(courses: [BlackboardCourse], deadlines: [LearningDeadline], warnings: [String] = []) {
        self.courses = courses
        self.deadlines = deadlines
        self.warnings = warnings
    }
}
