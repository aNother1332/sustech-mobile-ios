import Foundation
import Testing
@testable import CampusCore

private func fixture(_ name: String) throws -> Data {
    let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
    return try Data(contentsOf: url)
}

@Test func semesterAcceptsNumericTerm() throws {
    let semester = try TISParser.semester(fixture("semester"))
    #expect(semester.year == "2026-2027")
    #expect(semester.term == "1")
}

@Test func timetableUsesPeriodsRatherThanBlockIndex() throws {
    let meetings = try TISParser.meetings(fixture("timetable"))
    let monday = try #require(meetings.first)
    #expect(monday.weekday == 1)
    #expect(monday.firstPeriod == 1)
    #expect(monday.lastPeriod == 2)
    #expect(meetings[1].firstPeriod == 3)
    #expect(meetings[1].lastPeriod == 4)
}

@Test func examsPreservePublishedTimeAndSeat() throws {
    let exam = try #require(TISParser.exams(fixture("exams")).first)
    #expect(exam.time == "14:00-16:00")
    #expect(exam.seat == "12")
    #expect(exam.room == "第一教学楼 203")
}

@Test(arguments: ["{}", "{\"code\":500,\"message\":\"failed\"}", "null", "<html>login</html>"])
func malformedTimetableNeverBecomesEmptySuccess(_ raw: String) {
    #expect(throws: CampusError.invalidResponse("课表")) {
        try TISParser.meetings(Data(raw.utf8))
    }
}

@Test func emptyTimetableIsValid() throws {
    #expect(try TISParser.meetings(Data("[]".utf8)).isEmpty)
}

@Test(arguments: ["", "null", " \n"])
func noTeachingWeekDoesNotInventWeekOne(_ raw: String) throws {
    #expect(try TISParser.week(Data(raw.utf8)) == nil)
}

@Test(arguments: ["0", "-1", "61", "{\"error\":true}"])
func invalidWeekIsReported(_ raw: String) {
    #expect(throws: CampusError.invalidResponse("教学周")) {
        try TISParser.week(Data(raw.utf8))
    }
}

@Test func blackboardDatesPreserveTimeZoneAndUnknownState() throws {
    let page = try BlackboardParser.decode(BlackboardParser.Page<BlackboardParser.Column>.self,
                                           from: fixture("bb-columns"))
    let course = BlackboardCourse(id: "_course_1", name: "示例课程")
    let deadlines = page.results.compactMap { BlackboardParser.deadline($0, course: course) }
    #expect(deadlines.count == 3)
    #expect(deadlines[0].due == ISO8601DateFormatter().date(from: "2026-10-25T15:59:00Z"))
    #expect(deadlines[1].due == ISO8601DateFormatter().date(from: "2026-10-26T15:59:00Z"))
    #expect(deadlines.allSatisfy { $0.submission == .unknown })
    #expect(deadlines[2].due == nil)
    #expect(deadlines[2].rawDue == "由教师另行通知")
    #expect(page.paging?.nextPage != nil)
}

@Test func missingBlackboardResultsIsAnError() {
    #expect(throws: CampusError.invalidResponse("Blackboard")) {
        try BlackboardParser.decode(BlackboardParser.Page<BlackboardParser.Column>.self,
                                    from: Data("{\"message\":\"not authorized\"}".utf8))
    }
}
