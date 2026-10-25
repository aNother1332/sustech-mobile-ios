import Foundation
import Testing
@testable import CampusCore

@Test func studentProfileKeepsKnownFieldsWithoutTurningOpaqueIDsIntoStudentNumbers() throws {
    let raw = try JSONDecoder().decode(WireValue.self, from: Data(#"{"xm":"示例姓名","zymc":"示例专业","yxmc":"示例院系","yhdm":"opaque-id"}"#.utf8))
    let value = StudentProfile.parse(raw)
    #expect(value.name == "示例姓名"); #expect(value.major == "示例专业"); #expect(value.studentID.isEmpty)
    #expect(StudentProfile.parse(.object([:])).isEmpty)
}
@Test func highlightedSubmissionExcludesCompletedUnknownExpiredAndUndatedTasks() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func task(_ id: String, _ status: LearningDeadline.Submission, _ seconds: Double?) -> LearningDeadline {
        LearningDeadline(id: id, course: "示例", title: id, due: seconds.map { now.addingTimeInterval($0) }, rawDue: "", submission: status)
    }
    let items = [task("submitted", .submitted, 1), task("unknown", .unknown, 2), task("expired", .pending, -1), task("undated", .pending, nil), task("later", .pending, 400), task("draft", .draft, 200)]
    #expect(LearningHighlights.nextSubmission(items, now: now)?.id == "draft")
    #expect(LearningHighlights.nextSubmission(Array(items.prefix(4)), now: now) == nil)
}
@Test func highlightedExamUsesActualStartTimeAndRejectsUnknownDates() throws {
    let now = try #require(CampusClock.date("2026-10-25 12:00", "yyyy-MM-dd HH:mm"))
    let items = [CampusExam(id: "past", course: "", date: "2026-10-25", time: "09:00–11:00", room: "", seat: ""), CampusExam(id: "future", course: "", date: "2026-10-25", time: "14:00–16:00", room: "", seat: ""), CampusExam(id: "unknown", course: "", date: "待定", time: "", room: "", seat: "")]
    #expect(LearningHighlights.nextExam(items, now: now)?.id == "future")
}
@Test func scheduleTwentyMinuteWindowAndInvalidTimeHandling() throws {
    let raw = try JSONDecoder().decode(WireValue.self, from: Data(#"[{"route_id":"line1","route_direction_id":"line1_cw","departure_times":["10:00","bad","25:61","10:20","10:30"]}]"#.utf8))
    let group = try #require(BusExperience.schedules(raw).first)
    #expect(group.times.count == 3)
    let now = try #require(CampusClock.date("2026-10-25 10:20", "yyyy-MM-dd HH:mm"))
    #expect(group.times[0].phase(at: now) == .recent)
    #expect(group.times[1].phase(at: now) == .recent)
    #expect(group.times[2].phase(at: now) == .future)
    #expect(group.times[0].phase(at: now.addingTimeInterval(1)) == .past)
}
@Test func selectedVehicleNeverBorrowsAnotherVehiclesPrediction() throws {
    let raw = try JSONDecoder().decode(WireValue.self, from: Data(#"[{"id":"v1","latitude":22.6,"longitude":114,"route_direction_id":"line1_cw","trip_id":"trip-one","current_position":{"next_stop_id":"stop-one"}}]"#.utf8))
    let vehicle = try #require(BusMapParser.vehicles(raw).first)
    let predictions = try JSONDecoder().decode(WireValue.self, from: Data(#"{"arrivals":[{"trip_id":"trip-other","route_direction_id":"line1_cw","eta_minutes":1},{"trip_id":"trip-one","route_direction_id":"line1_cw","eta_minutes":7}]}"#.utf8))
    let items = try BusClient.parseArrivals(predictions)
    #expect(vehicle.nextStopID == "stop-one")
    #expect(BusExperience.matchedArrival(vehicle: vehicle, arrivals: items)?.minutes == 7)
    #expect(BusExperience.matchedArrival(vehicle: vehicle, arrivals: [items[0]]) == nil)
}
