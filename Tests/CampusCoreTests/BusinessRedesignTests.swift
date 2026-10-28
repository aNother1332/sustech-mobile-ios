import Foundation
import Testing
@testable import CampusCore

@Test func studentDetailsMergeActualMajorWithAccountRecord() {
    let base = StudentProfile.parse(.object(["xm": .string("示例姓名"), "bmmc": .string("示例院系")]))
    let details = StudentProfile.parse(.object(["XH": .string("DEMO100"), "ZYMC": .string("示例专业")]))
    let merged = base.merging(details)
    #expect(merged.name == "示例姓名" && merged.major == "示例专业" && merged.studentID == "DEMO100")
}

@Test func exchangeTextHandlesEntitiesWithoutGuessingCharset() {
    #expect(HTMLText.plain("&amp;#X4E2D;&amp;#22269;") == "中国")
    #expect(HTMLText.plain("&lt;p&gt;交换&amp;nbsp;项目&lt;/p&gt;") == "交换 项目")
    #expect(HTMLText.plain("正常中文与 English") == "正常中文与 English")
}

@Test func icCalendarRejectsOverlappingAndUnknownTimes() throws {
    let day = try #require(CampusClock.date("2026-10-28"))
    let raw: WireValue = .object([
        "devId": .string("room-demo"),
        "openTimes": .array([.object(["openStartTime": .string("08:00"), "openEndTime": .string("22:00")])]),
        "resvInfo": .array([.object(["startTime": .string("2026-10-28 10:00:00"), "endTime": .string("2026-10-28 11:00:00"), "resvStatus": .integer(4)])])
    ])
    let schedule = try ICRoomSchedule.parse(raw, day: day)
    let start = try #require(CampusClock.date("2026-10-28 09:30", "yyyy-MM-dd HH:mm"))
    #expect(schedule.canSelect(start: start, end: start.addingTimeInterval(1800)))
    #expect(!schedule.canSelect(start: start, end: start.addingTimeInterval(3600)))
    let uncertain = try ICRoomSchedule.parse(raw.replacing(["resvInfo": .array([.object(["resvStatus": .integer(4)])])]), day: day)
    #expect(!uncertain.complete && !uncertain.canSelect(start: start, end: start.addingTimeInterval(1800)))
}
