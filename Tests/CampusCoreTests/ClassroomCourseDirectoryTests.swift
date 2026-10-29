import Foundation
import Testing
@testable import CampusCore

@Test func classroomFallbackUsesAllWeekAndEvenWeekSlots() throws {
    let value = try ClassroomCourseDirectory.parse([
        .object(["pkjgmx": .string("<div><p>1-16周,星期五第3-4节 智华楼114</p><p>2-16双周,星期二第7-8节 智华楼114</p></div>")]),
        .object(["pkjgmx": .string("<p>1-15单周,星期日第1节 一教101</p>")])
    ])
    #expect(value.rooms.count == 2)
    let entries = try #require(value.entries["智华楼114"])
    #expect(entries.contains { $0.overlaps(week: 2, weekday: 2, first: 8, last: 8) })
    #expect(!entries.contains { $0.overlaps(week: 3, weekday: 2, first: 7, last: 8) })
    #expect(entries.contains { $0.overlaps(week: 16, weekday: 5, first: 4, last: 4) })
    #expect(!entries.contains { $0.overlaps(week: 17, weekday: 5, first: 3, last: 4) })
    #expect(value.entries["一教101"]?.first?.weekday == 7)
}

@Test func classroomFallbackRejectsUnknownScheduleRatherThanReportingFree() {
    #expect(throws: CampusError.self) { try ClassroomCourseDirectory.parse([.object(["pkjgmx": .string("<p>特殊周次,星期二第7-8节 一教101</p>")])]) }
}

@Test func campusCourseQueryIsReplayableButSelectionIsNot() {
    #expect(SessionReadPolicy.canReplay(method: "POST", path: "/Xsxktz/queryRwxxcxList"))
    #expect(!SessionReadPolicy.canReplay(method: "POST", path: "/Xsxktz/submit"))
}
