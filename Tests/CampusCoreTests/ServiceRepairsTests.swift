import Foundation
import Testing
@testable import CampusCore

@Test func printingListsAcceptOnlyDocumentedShapes() throws {
    func envelope(_ result: WireValue) -> WireValue { .object(["code": .integer(0), "result": result]) }
    for kind in [PrintingListKind.stations, .jobs, .scans, .usage] {
        #expect(try PrintingClient.list(envelope(.array([])), kind: kind).isEmpty)
        for malformed in [WireValue.object(["rows": .array([])]), .string(""), .integer(0), .bool(false)] {
            #expect(throws: CampusError.self) { try PrintingClient.list(envelope(malformed), kind: kind) }
        }
        #expect(throws: CampusError.self) { try PrintingClient.list(.object(["code": .integer(0)]), kind: kind) }
        #expect(throws: CampusError.self) { try PrintingClient.list(envelope(.array([.object([:])])), kind: kind) }
    }
    // Explicit success/null is documented by original printDoc.js/scanDoc.js.
    #expect(try PrintingClient.list(envelope(.null), kind: .jobs).isEmpty)
    #expect(try PrintingClient.list(envelope(.null), kind: .scans).isEmpty)
    for kind in [PrintingListKind.stations, .usage] { #expect(throws: CampusError.self) { try PrintingClient.list(envelope(.null), kind: kind) } }
    #expect(throws: CampusError.signInRequired) { try PrintingClient.list(.object(["code": .integer(4), "message": .string("无效会话，未登录"), "result": .null]), kind: .jobs) }
}

@Test func printingDiagnosticsNeverEquateAWebPageWithWorkingPrinting() {
    let html = Data("<html>Access page</html>".utf8)
    #expect(PrintingClient.probeMessage(status: 200, data: html) == "未收到有效打印数据")
    #expect(PrintingClient.probeMessage(status: 403, data: html).contains("拒绝访问"))
    #expect(PrintingClient.probeMessage(status: 401, data: html).contains("尚未登录"))
    let valid = Data(#"{"code":0,"result":{"publicKey":"fixture"}}"#.utf8)
    #expect(PrintingClient.probeMessage(status: 200, data: valid).contains("校内打印未验证"))
}

@Test func icCompletedTimesStayVisibleAndMidnightWindowIsBookable() throws {
    let day = try #require(CampusClock.date("2026-11-02"))
    let raw: WireValue = .object(["devId": .string("sample-room"), "openTimes": .array([.object(["openStartTime": .string("08:00"), "openEndTime": .string("24:00")])]), "resvInfo": .array([.object(["resvStatus": .integer(128), "startTime": .string("2026-11-02 09:00:00"), "endTime": .string("2026-11-02 10:00:00")])])])
    let schedule = try ICRoomSchedule.parse(raw, day: day)
    #expect(schedule.complete && schedule.occupied.count == 1)
    let evening = try #require(CampusClock.date("2026-11-02 23:30", "yyyy-MM-dd HH:mm"))
    #expect(schedule.canSelect(start: evening, end: evening.addingTimeInterval(1800)))
    let empty = try ICRoomSchedule.parse(raw.replacing(["resvInfo": .array([])]), day: day)
    let now = try #require(CampusClock.date("2026-11-02 12:00", "yyyy-MM-dd HH:mm"))
    #expect(empty.retainingPast(from: schedule, now: now).occupied.count == 1)
    #expect(empty.retainingPast(from: schedule, now: day).occupied.isEmpty)
    #expect(schedule.pastSnapshot(now: now).occupied.count == 1)
    #expect(!schedule.pastSnapshot(now: now).complete)
}

@Test func icExplicitUnlimitedWindowsDoNotBecomeUnselectable() throws {
    let day = try #require(CampusClock.date("2026-11-02"))
    let value: WireValue = .object(["devId": .string("sample-room"), "openTimes": .array([.object(["openStartTime": .string("07:00"), "openEndTime": .string("07:00"), "openLimit": .integer(0)])]), "resvInfo": .array([])])
    #expect(try ICRoomSchedule.parse(value, day: day).complete)
    let unknown = value.replacing(["openTimes": .array([.object(["openStartTime": .string("07:00"), "openEndTime": .string("07:00")])])])
    #expect(try !ICRoomSchedule.parse(unknown, day: day).complete)
}

@Test func studentServicesPreservePagingAndRejectMalformedData() throws {
    let row: WireValue = .object(["WID": .string("sample"), "HDMC": .string("&lt;b&gt;校园活动&lt;/b&gt;"), "HDKSSJ": .string("2026-11-02")])
    let reply: WireValue = .object(["code": .string("0"), "datas": .object(["hdllbgdz": .object(["totalSize": .integer(66), "pageSize": .integer(12), "pageNumber": .integer(1), "rows": .array([row])])])])
    let result = try StudentServicePage.parse(reply, app: .activities, page: 1)
    #expect(result.records.first?.title == "校园活动" && result.hasMore)
    #expect(throws: ServiceFailure.self) { try StudentServicePage.parse(.object(["code": .string("0")]), app: .activities, page: 1) }
    #expect(StudentServiceApp.activities.queryFields == ["TJ1":"99", "TJ2":"99"])
    #expect(!StudentServiceApp.leave.entry.absoluteString.contains("gid_"))
}

@Test func studentReadRecoveryNeverReplaysLeaveSubmission() {
    #expect(SessionReadPolicy.canReplay(method: "POST", path: StudentServiceApp.leave.queryPath))
    #expect(SessionReadPolicy.canReplay(method: "POST", path: StudentServiceApp.activities.queryPath))
    #expect(!SessionReadPolicy.canReplay(method: "POST", path: "/xgxsfw/sys/qjgl/modules/wdqj/bcxsqjxx.do"))
    #expect(!SessionReadPolicy.canReplay(method: "POST", path: "/xsfwdt/sys/xshdapp/hdllController/apply.do"))
}
