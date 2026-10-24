import Foundation

public struct Semester: Equatable, Sendable {
    public let year: String
    public let term: String
    public let name: String

    public init(year: String, term: String, name: String) {
        self.year = year
        self.term = term
        self.name = name
    }
}

public struct CourseMeeting: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let details: String
    public let weekday: Int
    public let firstPeriod: Int
    public let lastPeriod: Int

    public init(id: String, name: String, details: String, weekday: Int,
                firstPeriod: Int, lastPeriod: Int) {
        self.id = id
        self.name = name
        self.details = details
        self.weekday = weekday
        self.firstPeriod = firstPeriod
        self.lastPeriod = lastPeriod
    }
}

public struct CampusExam: Identifiable, Equatable, Sendable {
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

public struct BlackboardCourse: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

public struct LearningDeadline: Identifiable, Equatable, Sendable {
    public enum Submission: String, Sendable {
        // A deadline alone is never evidence that an assignment is pending.
        case unknown
        case submitted
        case pending
    }

    public let id: String
    public let course: String
    public let title: String
    public let due: Date?
    public let rawDue: String
    public let submission: Submission

    public init(id: String, course: String, title: String, due: Date?,
                rawDue: String, submission: Submission = .unknown) {
        self.id = id
        self.course = course
        self.title = title
        self.due = due
        self.rawDue = rawDue
        self.submission = submission
    }
}

public struct TeachingSnapshot: Sendable {
    public let semester: Semester
    public let week: Int?
    public let meetings: [CourseMeeting]
    public let exams: [CampusExam]
    public let warnings: [String]

    public init(semester: Semester, week: Int?, meetings: [CourseMeeting],
                exams: [CampusExam], warnings: [String] = []) {
        self.semester = semester
        self.week = week
        self.meetings = meetings
        self.exams = exams
        self.warnings = warnings
    }
}

public struct BlackboardSnapshot: Sendable {
    public let courses: [BlackboardCourse]
    public let deadlines: [LearningDeadline]
    public let warnings: [String]

    public init(courses: [BlackboardCourse], deadlines: [LearningDeadline], warnings: [String] = []) {
        self.courses = courses
        self.deadlines = deadlines
        self.warnings = warnings
    }
}
