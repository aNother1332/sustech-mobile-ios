import Foundation
import Testing
@testable import CampusCore

@Test func casExecutionDoesNotDependOnAttributeOrderOrQuoteStyle() throws {
    let html = "<input value='e1&amp;x&#61;2' type=hidden name='execution'>"
    #expect(try CASPolicy.execution(in: html) == "e1&x=2")
}

@Test func activeCaptchaStopsPasswordOnlyFlow() {
    #expect(throws: CASFailure.challenge) {
        try CASPolicy.execution(in: "<input name='execution' value='safe'><input name='captcha' type='text'>")
    }
}

@Test func sliderChallengeIsDetectedEvenWhenResponseFieldIsHidden() {
    #expect(throws: CASFailure.challenge) {
        try CASPolicy.execution(in: "<input name='execution' value='safe'><input type='hidden' name='g-recaptcha-response'><div id='slideVerify'></div>")
    }
}

@Test(arguments: ["https://cas.sustech.edu.cn.evil.example/login", "http://tis.sustech.edu.cn/cas", "https://bb.sustech.edu.cn/cas", "https://tis.sustech.edu.cn:444/cas", "https://user:secret@tis.sustech.edu.cn/cas"])
func casRedirectsCannotLeakCredentialsOrTickets(_ raw: String) throws {
    #expect(throws: CASFailure.redirect) { try CASPolicy.redirect(raw, from: CASPolicy.login, service: .teaching) }
}

@Test func timetableBitmapUsesPaddedWeekIndices() throws {
    #expect(try TISParser.weeks("0101010") == [1, 3, 5])
    #expect(try TISParser.weeks(nil) == nil)
    #expect(throws: CampusError.invalidResponse("课表周次位图")) { try TISParser.weeks("10101") }
}

@Test func gradeRecordsPreserveZeroPointsAndExcludePassFailFromEstimate() throws {
    let data = Data(#"{"content":{"total":"3","list":[{"kcdm":"A","kcmc":"数学","xnxqmc":"秋季","xf":"3","xscj":"A+"},{"kcdm":"B","kcmc":"物理","xf":2,"xscj":"F","jd":0},{"kcdm":"C","kcmc":"体育","xf":1,"xscj":"通过"}]}}"#.utf8)
    let page = try TISParser.grades(data)
    let summary = GradeSummary(records: page.records)
    #expect(page.total == 3)
    #expect(summary.includedCredits == 5)
    #expect(summary.points == 2.4)
    #expect(summary.excludedCount == 1)
}

@Test func attemptsMustBelongToCurrentUserAndHaveKnownStatus() {
    #expect(BBStudyParser.submission(attempts: [["userId": "other", "status": "Completed"]], userID: "me") == .pending)
    #expect(BBStudyParser.submission(attempts: [["status": "Completed"]], userID: "me") == .unknown)
    #expect(BBStudyParser.submission(attempts: [["userId": "me", "status": "NeedsGrading"]], userID: "me") == .submitted)
    #expect(BBStudyParser.submission(attempts: [["userId": "me", "status": "InProgress"]], userID: "me") == .draft)
    #expect(BBStudyParser.submission(attempts: [["userId": "me", "status": "FutureState"]], userID: "me") == .unknown)
    #expect(BBStudyParser.submission(attempts: [["userId": "me", "exempt": true]], userID: "me") == .exempt)
}

@Test func snapshotRoundTripPreservesFullSemesterWeeksAndTimes() throws {
    let snapshot = TeachingSnapshot(semester: Semester(year: "2026", term: "1", name: "示例"), week: 3,
        meetings: [CourseMeeting(id: "one", name: "示例", details: "", weekday: 1, firstPeriod: 1, lastPeriod: 2, weeks: [1,3])],
        exams: [], fullSemester: true, periods: [PeriodTime(period: 1, start: "08:00", end: "08:50")])
    let restored = try JSONDecoder().decode(TeachingSnapshot.self, from: JSONEncoder().encode(snapshot))
    #expect(restored.fullSemester)
    #expect(restored.meetings[0].weeks == [1,3])
    #expect(restored.periods[0].start == "08:00")
}

@Test func plainTextPreviewNeverExecutesOrDisplaysScriptContent() {
    #expect(HTMLText.plain("<p>Hello &amp; world</p><script>steal()</script>").contains("Hello & world"))
    #expect(!HTMLText.plain("<script>steal()</script>").contains("steal"))
}

@Test func failedSectionKeepsItsOriginalDataTimestamp() {
    let oldDate = Date(timeIntervalSince1970: 1_000)
    let oldTask = LearningDeadline(id: "old", course: "示例", title: "旧任务", due: nil, rawDue: "")
    let old = BBCourseDetail(tasks: [oldTask], announcements: [], warnings: [], updated: oldDate)
    let failed = BBCourseDetail(tasks: [], announcements: [BBAnnouncement(id: "new", title: "新公告", body: "", created: "")],
        warnings: ["任务读取失败"], updated: Date(timeIntervalSince1970: 2_000), tasksRead: false)
    let merged = failed.retainingUnreadSections(from: old)
    #expect(merged.tasks.map(\.id) == ["old"])
    #expect(merged.announcements.map(\.id) == ["new"])
    #expect(merged.tasksUpdated == oldDate)
    let again = failed.retainingUnreadSections(from: merged)
    #expect(again.tasksUpdated == oldDate)
}
