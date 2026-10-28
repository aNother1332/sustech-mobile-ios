import Foundation
import Testing
import Security
@testable import CampusCore

@Test func ncesAcceptsActualDecimalStringMetrics() throws {
    let raw = Data(#"{"courses":{"items":[{"id":7,"name":"示例课程","rate_average":9.16129,"difficulty_score":"30.65","homework_score":"41.94","grading_score":"69.35","gain_score":"87.10"}]}}"#.utf8)
    let course = try #require(ReviewClient.courses(JSONDecoder().decode(WireValue.self, from: raw)).first)
    #expect(course.difficulty == 30.65)
    #expect(course.homework == 41.94)
    #expect(course.grading == 69.35)
    #expect(course.gain == 87.10)
    #expect(course.displayRating == "9.16")
}

@Test func cleIdentityComesFromAuthenticatedPageMetadata() throws {
    let page = #"<script>var pageMeta = {"datas":{},"params":{"USERID":"DEMO100","USERNAME":"示例同学"}};var userId = pageMeta.params.USERID;</script>"#
    let identity = try CLEIdentity.parse(page)
    #expect(identity.id == "DEMO100" && identity.name == "示例同学")
    #expect(throws: CampusError.self) { try CLEIdentity.parse("<html>Sign in</html>") }
}

@Test func sessionReplayPolicyIncludesQueriesAndExcludesEveryWrite() {
    #expect(SessionReadPolicy.canReplay(method: "POST", path: "/component/querydangqianxnxq"))
    #expect(SessionReadPolicy.canReplay(method: "POST", path: "/api/SystemApi/GetMeetingRoomAll"))
    for path in ["/ic-web/reserve", "/api/client/PrintJob/Del", "/learn/api/public/v1/submit", "/epay/payMoney", "/booking/cancel"] {
        #expect(!SessionReadPolicy.canReplay(method: "POST", path: path))
    }
    #expect(!SessionReadPolicy.canReplay(method: "GET", path: "/booking/cancel"))
    #expect(!SessionReadPolicy.canReplay(method: "GET", path: "/webapps/assignment/uploadAssignment?action=newAttempt"))
}

@Test func unrelatedOldCookiesDoNotOverwriteRenewedSharedSessions() throws {
    func cookie(_ name: String, _ value: String, _ domain: String) throws -> HTTPCookie {
        try #require(HTTPCookie(properties: [.name: name, .value: value, .domain: domain, .path: "/"]))
    }
    let oldCard = try cookie("SESSION", "old-card", "campuscard.sustech.edu.cn")
    let oldBB = try cookie("SESSION", "old-bb", "bb.sustech.edu.cn")
    let newBB = try cookie("SESSION", "new-bb", "bb.sustech.edu.cn")
    let changes = CookieChanges.changed(from: [oldCard, oldBB], to: [oldCard, newBB])
    #expect(changes.count == 1 && changes[0].domain == "bb.sustech.edu.cn" && changes[0].value == "new-bb")
}

@Test func curriculumUsesTrueCohortAndFullBookForUndeclaredStudents() {
    let profile = StudentProfile.parse(.object(["NJMC": .string("2025级"), "ZYMC": .string("通识通修"), "YXMC": .string("通识与学科基础部")]))
    #expect(profile.admissionYear == 2025)
    #expect(CurriculumPolicy.showCompleteBook(profile))
    #expect(CurriculumPolicy.matches(title: "金融数学专业本科人才培养方案（2025级）", major: "金融数学"))
    #expect(!CurriculumPolicy.matches(title: "金融数学专业本科人才培养方案", major: "金融学"))
}

@Test func collegeTicketsStayBoundToTheirVerifiedCallback() throws {
    #expect(try CollegeAuthentication.ticket(from: URL(string: "https://booking.sustech.edu.cn/redirect?ticket=ST-fixture")!) == "ST-fixture")
    #expect(throws: CampusError.self) { try CollegeAuthentication.ticket(from: URL(string: "https://other.example/redirect?ticket=ST-fixture")!) }
    #expect(throws: CampusError.self) { try CollegeAuthentication.ticket(from: URL(string: "https://booking.sustech.edu.cn/login?ticket=ST-fixture")!) }
}

@Test func topWeatherTemperatureUsesCurrentValueInsteadOfRangeOrFeelsLike() {
    let weather = CampusWeather(summary: "南科大天气：24℃-30℃。气温24.7℃，体感26.2℃，近两个小时内无降雨。", aqi: nil)
    #expect(weather.temperature == "24.7°")
}

@Test func printingSPKIKeyEncryptsNoncePasswordWithServerCompatiblePadding() throws {
    let key = try #require(SecKeyCreateRandomKey([kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeySizeInBits: 2048] as CFDictionary, nil))
    let publicKey = try #require(SecKeyCopyPublicKey(key))
    let raw = try #require(SecKeyCopyExternalRepresentation(publicKey, nil)) as Data
    func der(_ tag: UInt8, _ bytes: Data) -> Data {
        let size = bytes.count
        let length: [UInt8] = size < 128 ? [UInt8(size)] : size < 256 ? [0x81, UInt8(size)] : [0x82, UInt8(size >> 8), UInt8(size & 255)]
        return Data([tag] + length) + bytes
    }
    let algorithm = Data([0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00])
    let spki = der(0x30, algorithm + der(0x03, Data([0]) + raw))
    for encoded in [raw.base64EncodedString(), spki.base64EncodedString()] {
        let encrypted = try PrintingAuthentication.encrypt("fixture-password;fixture-nonce", publicKey: encoded)
        let bytes = try #require(Data(base64Encoded: encrypted))
        let decrypted = try #require(SecKeyCreateDecryptedData(key, .rsaEncryptionPKCS1, bytes as CFData, nil)) as Data
        #expect(String(decoding: decrypted, as: UTF8.self) == "fixture-password;fixture-nonce")
    }
}

@Test func escapedPrintingSessionErrorStillTriggersRenewal() {
    let body = Data(#"{"code":4,"message":"\u65e0\u6548\u4f1a\u8bdd\uff0c\u672a\u767b\u5f55"}"#.utf8)
    #expect(SessionReadPolicy.expired(status: 200, data: body))
}

private final class RenewalFixtureState: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [String: Int] = [:]
    func next(_ key: String) -> Int { lock.withLock { requests[key, default: 0] += 1; return requests[key]! } }
    func count(_ key: String) -> Int { lock.withLock { requests[key, default: 0] } }
}
private final class RenewalFixture: URLProtocol, @unchecked Sendable {
    static let state = RenewalFixtureState()
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let key = request.url!.absoluteString
        let attempt = Self.state.next(key)
        let status = request.url!.path == "/ic-web/reserve" ? 401 : 200
        let body = attempt == 1 ? #"{"code":300,"data":null}"# : #"{"code":0,"data":[]}"#
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type":"application/json"])!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private actor RenewalCounter {
    var count = 0
    func recover() -> RecoveredSession { count += 1; return RecoveredSession(cookies: []) }
}
@Test func expiredReadRenewsExactlyOnceAndReturnsRealSecondResponse() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RenewalFixture.self]
    let counter = RenewalCounter()
    let http = ServiceHTTP(origin: URL(string: "https://booking.lib.sustech.edu.cn")!, configuration: config, recovery: { await counter.recover() })
    let result = try await http.json("/ic-web/roomDevice/roomInfos", query: ["test": UUID().uuidString])
    #expect(result["code"].int == 0)
    #expect(await counter.count == 1)
}
@Test func expiredReservationPostIsNeverReplayed() async throws {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [RenewalFixture.self]
    let counter = RenewalCounter()
    let http = ServiceHTTP(origin: URL(string: "https://booking.lib.sustech.edu.cn")!, configuration: config, recovery: { await counter.recover() })
    let id = UUID().uuidString
    await #expect(throws: CampusError.signInRequired) { try await http.json("/ic-web/reserve", query: ["test": id], payload: .object([:])) }
    #expect(await counter.count == 0)
    #expect(RenewalFixture.state.count("https://booking.lib.sustech.edu.cn/ic-web/reserve?test=" + id) == 1)
}
