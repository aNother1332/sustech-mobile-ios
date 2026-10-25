import Foundation
import Testing
@testable import CampusCore

@Test func cardHTMLAndSpendingCurveDoNotCountRefundsOrUnknownDirections() throws {
    let account = try CardParser.account("""
    <div class="weui-cell__bd"><p>账户余额</p></div><div class="weui-cell__ft">36.50 元</div>
    """)
    #expect(account.balance == "36.50 元")
    let html = """
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>食堂消费</div><div>-12.30元</div></h4><div style="color:#999;flex:1">2026-10-25 12:00</div><span class="label label-success">成功</span></div>
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>退款</div><div>+2.30元</div></h4><div style="color:#999;flex:1">2026-10-25 13:00</div></div>
    <div class="weui-media-box weui-media-box_text"><h4 class="weui-media-box__title"><div>未知交易</div><div>5.00元</div></h4><div style="color:#999;flex:1">2026-10-25 14:00</div></div>
    """
    let bills = try CardParser.bills(html)
    #expect(bills.count == 3)
    #expect(bills[1].expense == nil)
    #expect(bills[2].expense == nil)
    #expect(CardParser.curve(bills).first?.amount == Decimal(string: "12.30"))
}

@Test func malformedCardPagesAreNotAnEmptyBalance() {
    #expect(throws: CampusError.self) { try CardParser.account("<html>登录</html>") }
    #expect(throws: CampusError.self) { try CardParser.bills("<input name='execution'>") }
}

@Test func roomBorrowingsCountAsOccupiedAndDiscardPersonalDetails() throws {
    let data = Data(#"[{"KEY":"xq2_jc3","SKSJ":"【借用】[1-3,5周]\n使用人:虚构人员\n联系电话:00000000000"}]"#.utf8)
    let value = try JSONDecoder().decode(WireValue.self, from: data)
    let entries = try ClassroomParser.entries(value)
    #expect(entries[0].overlaps(week: 2, weekday: 2, first: 2, last: 4))
    #expect(!entries[0].overlaps(week: 4, weekday: 2, first: 2, last: 4))
    #expect(entries[0].kind == "教室借用")
}

@Test func unknownClassroomWeeksAreConservativelyOccupied() throws {
    let value = try JSONDecoder().decode(WireValue.self, from: Data(#"[{"KEY":"xq1_jc1","SKSJ":"未明确周次"}]"#.utf8))
    #expect(try ClassroomParser.entries(value)[0].overlaps(week: 8, weekday: 1, first: 1, last: 2))
}

@Test func printOptionsMatchWireCodesAndRejectBadRanges() throws {
    var options = PrintOptions()
    options.duplex = 3; options.copies = 2
    let fields = try options.fields()
    #expect(fields["dwDuplex"] == "3")
    #expect(fields["dwPaperId"] == "9")
    #expect(fields["dwFrom"] == "0")
    options.first = 8; options.last = 3
    #expect(throws: ServiceFailure.self) { try options.fields() }
}

@Test func sessionRedirectsStayOnSchoolHTTPS() {
    #expect(SessionConnector.allowed(URL(string: "https://cas.sustech.edu.cn/cas/login")!))
    #expect(!SessionConnector.allowed(URL(string: "https://cas.sustech.edu.cn.evil.example")!))
    #expect(!SessionConnector.allowed(URL(string: "http://tis.sustech.edu.cn")!))
    #expect(!SessionConnector.allowed(URL(string: "https://user:password@tis.sustech.edu.cn")!))
}

@Test func cardFailedTransactionsAreExcluded() throws {
    let html = """
    <div class="weui-media-box weui-media-box_text"><h4><div>消费</div><div>-12.00</div></h4><div style="color:#999;flex:1">2026-10-25</div><span class="label label-danger">失败</span></div>
    """
    #expect(try CardParser.curve(CardParser.bills(html)).isEmpty)
}

@Test func courtBookingCannotProceedWithoutHumanChallenge() async {
    let api = CourtClient()
    let ground = ReservationItem(id: "fixture", title: "示例场地", detail: "", raw: .object([:]))
    let slot = CourtSlot(day: "2026-10-26", start: "8:00", end: "9:00", status: "1")
    await #expect(throws: ServiceFailure.self) {
        try await api.book(ground: ground, slot: slot, captchaToken: "", phone: "00000000000", people: 1)
    }
}

@Test func wireValuePreservesLargeStringIdentifiers() throws {
    let value = try JSONDecoder().decode(WireValue.self, from: Data(#"{"id":"1333325020650307585","status":1}"#.utf8))
    #expect(value["id"].text == "1333325020650307585")
    #expect(value["status"].int == 1)
    #expect(try JSONDecoder().decode(WireValue.self, from: JSONEncoder().encode(value)) == value)
}

@Test func wireValuePreservesNumericSnowflakeIdentifiers() throws {
    let value = try JSONDecoder().decode(WireValue.self, from: Data(#"{"id":1333325020650307585}"#.utf8))
    #expect(value["id"].text == "1333325020650307585")
    #expect(try JSONDecoder().decode(WireValue.self, from: JSONEncoder().encode(value)) == value)
}

@Test(arguments: ["[1-2节]", "第1-2节", "[J1-2]"]) func classroomMultiPeriodEntryBlocksItsLastPeriod(_ range: String) throws {
    let value: WireValue = .array([.object(["KEY": .string("xq1_jc1"), "SKSJ": .string("【本】示例课程[1-16周]" + range)])])
    #expect(try ClassroomParser.entries(value)[0].overlaps(week: 8, weekday: 1, first: 2, last: 2))
}

private actor SessionRequestLog {
    private var methods: [String: [String]] = [:]
    func record(_ method: String, scenario: String) { methods[scenario, default: []].append(method) }
    func all(_ scenario: String) -> [String] { methods[scenario] ?? [] }
}
private final class SessionProtocol: URLProtocol, @unchecked Sendable {
    static let log = SessionRequestLog()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @Sendable [self] in
            let scenario = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "scenario" }?.value ?? "reuse"
            await Self.log.record(request.httpMethod ?? "GET", scenario: scenario)
            var code = 200; var headers: [String: String] = [:]; var body = "service"
            if request.url?.host == "cas.sustech.edu.cn" {
                if scenario == "expired" { body = "<input name='execution' value='fixture'>" }
                else { code = 302; headers["Location"] = scenario == "escape" ? "https://evil.example/?ticket=fixture" : "https://tis.sustech.edu.cn/cas?scenario=reuse&ticket=fixture" }
            }
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@Test func sharedCASSessionIsExchangedWithoutResubmittingPassword() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SessionProtocol.self]
    _ = try await SessionConnector().connect(URL(string: "https://cas.sustech.edu.cn/cas/login?scenario=reuse")!, cookies: [], finalHost: "tis.sustech.edu.cn", configuration: config)
    #expect(await SessionProtocol.log.all("reuse") == ["GET", "GET"])
}

@Test func expiredCASStopsWithoutPasswordRetry() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SessionProtocol.self]
    await #expect(throws: CampusError.signInRequired) {
        _ = try await SessionConnector().connect(URL(string: "https://cas.sustech.edu.cn/cas/login?scenario=expired")!, cookies: [], finalHost: "tis.sustech.edu.cn", configuration: config)
    }
    #expect(await SessionProtocol.log.all("expired") == ["GET"])
}

@Test func serviceSessionExchangeRejectsExternalTicketRedirect() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [SessionProtocol.self]
    await #expect(throws: CASFailure.redirect) {
        _ = try await SessionConnector().connect(URL(string: "https://cas.sustech.edu.cn/cas/login?scenario=escape")!, cookies: [], finalHost: "tis.sustech.edu.cn", configuration: config)
    }
    #expect(await SessionProtocol.log.all("escape") == ["GET"])
}

private actor BusinessRequestLog {
    struct Entry: Sendable { let path: String; let queryKeys: Set<String> }
    private var entries: [Entry] = []
    func record(_ request: URLRequest) {
        entries.append(Entry(path: request.url!.path, queryKeys: Set(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems?.map(\.name) ?? [])))
    }
    func all() -> [Entry] { entries }
}
private final class BusinessProtocol: URLProtocol, @unchecked Sendable {
    static let log = BusinessRequestLog()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task { @Sendable [self] in
            await Self.log.record(request)
            let path = request.url!.lastPathComponent
            var code = 200
            let data: WireValue
            switch path {
            case "getAppGroundPageByGymId": data = .object(["records": .array([.object(["id": .string("court"), "name": .string("示例运动场地")])]), "total": .number(1)])
            case "getOrderTimeConfigList": data = .object(["configList": .array([.object(["date": .string("2099-01-01"), "timeBlockList": .array([.object(["time": .string("8:00"), "endTime": .string("9:00"), "status": .string("1")])])])])])
            case "getUserInfoByUserid": data = .object(["id": .string("fictional-user"), "name": .string("示例用户")])
            case "getGroundDetailByParam": data = .object(["gymId": .string("gym"), "gymName": .string("示例场馆"), "name": .string("示例场地"), "groundType": .string("0")])
            case "isGymBlackByCustomerId": data = .bool(false)
            case "getOrderPageListByParam": data = .object(["records": .array([]), "total": .number(0)])
            case "saveOrder": code = 500; data = .null
            default: data = .null
            }
            let value: WireValue = .object(["code": .number(200), "data": data])
            let response = HTTPURLResponse(url: request.url!, statusCode: code, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: try! JSONEncoder().encode(value)); client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() {}
}

@Test func sportsInventoryDoesNotFilterOutCourtsWithTypeParameter() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [BusinessProtocol.self]
    let api = CourtClient(credentials: CourtCredentials(userID: "fixture", token: "fictional-token"),
        http: ServiceHTTP(origin: URL(string: "https://reservation.sustech.edu.cn")!, configuration: config))
    #expect(try await api.grounds(gym: "gym").count == 1)
    let entries = await BusinessProtocol.log.all()
    #expect(entries.filter { $0.path.hasSuffix("getAppGroundPageByGymId") }.allSatisfy { !$0.queryKeys.contains("type") })
}

@Test func failedManualCourtWriteIsNotAutomaticallyRetried() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [BusinessProtocol.self]
    let api = CourtClient(credentials: CourtCredentials(userID: "fixture", token: "fictional-token"),
        http: ServiceHTTP(origin: URL(string: "https://reservation.sustech.edu.cn")!, configuration: config))
    let ground = ReservationItem(id: "court", title: "示例场地", detail: "", raw: .object([:]))
    let slot = CourtSlot(day: "2099-01-01", start: "8:00", end: "9:00", status: "1")
    await #expect(throws: CampusError.http(500)) {
        try await api.book(ground: ground, slot: slot, captchaToken: "fictional-human-verified-token", phone: "00000000000", people: 1)
    }
    let entries = await BusinessProtocol.log.all()
    #expect(entries.filter { $0.path.hasSuffix("saveOrder") }.count == 1)
}

@Test func icReadbackMatchesExactRoomAndWindowAcrossTimestampFormats() throws {
    let begin = try #require(CampusClock.date("2026-10-25 08:00:00", "yyyy-MM-dd HH:mm:ss"))
    let end = begin.addingTimeInterval(3600)
    let raw: WireValue = .object(["resvBeginTime": .number(begin.timeIntervalSince1970 * 1000),
        "resvEndTime": .string("2026-10-25T01:00:00Z"), "resvDevInfoList": .array([.object(["devId": .string("room")])])])
    let item = ReservationItem(id: "reservation", title: "示例房间", detail: "", raw: raw)
    #expect(ICClient.matches(item, room: "room", begin: begin, end: end))
    #expect(!ICClient.matches(item, room: "room", begin: begin.addingTimeInterval(86400), end: end.addingTimeInterval(86400)))
    #expect(!ICClient.matches(item, room: "other-room", begin: begin, end: end))
}
