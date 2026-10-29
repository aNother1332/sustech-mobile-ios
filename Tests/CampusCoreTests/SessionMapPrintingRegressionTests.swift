import Foundation
import Testing
@testable import CampusCore

@Test func mapAlignmentMatchesKnownGCJBenchmark() throws {
    let beijing = try #require(BusCoordinate(latitude: 39.908823, longitude: 116.397470))
    #expect(abs(beijing.gcj02.latitude - 39.91022650) < 0.000001)
    #expect(abs(beijing.gcj02.longitude - 116.40371358) < 0.000001)
    let campus = try #require(BusCoordinate(latitude: 22.60308, longitude: 113.99373))
    #expect(campus.gcj02.longitude > campus.longitude + 0.004)
    #expect(campus.gcj02.latitude < campus.latitude - 0.002)
    #expect(campus.latitude == 22.60308) // Presentation correction leaves API/distance data intact.
    let london = try #require(BusCoordinate(latitude: 51.5074, longitude: -0.1278))
    #expect(london.gcj02 == london)
}

@Test func automaticLoginRequiresConfirmedExpiryAndStopsWhenPaused() {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    #expect(AutomaticLoginPolicy.shouldAttempt(hasCredentials: true, paused: false, confirmedExpired: true, lastAttempt: nil, now: now))
    #expect(!AutomaticLoginPolicy.shouldAttempt(hasCredentials: true, paused: false, confirmedExpired: false, lastAttempt: nil, now: now))
    #expect(!AutomaticLoginPolicy.shouldAttempt(hasCredentials: true, paused: true, confirmedExpired: true, lastAttempt: nil, now: now))
    #expect(!AutomaticLoginPolicy.shouldAttempt(hasCredentials: false, paused: false, confirmedExpired: true, lastAttempt: nil, now: now))
    #expect(!AutomaticLoginPolicy.shouldAttempt(hasCredentials: true, paused: false, confirmedExpired: true, lastAttempt: now.addingTimeInterval(-299), now: now))
    #expect(AutomaticLoginPolicy.shouldAttempt(hasCredentials: true, paused: false, confirmedExpired: true, lastAttempt: now.addingTimeInterval(-301), now: now))
}

private final class SessionPrintFixture: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let valid: Bool
        let body: String
        if path == "/user/me" {
            valid = request.httpMethod == "GET"
            body = request.url?.host == "signedout.sustech.edu.cn" ? "{}" : #"{"username":"fixture-user","enabled":true}"#
        } else if path == "/component/querydangqianxnxq" {
            valid = request.httpMethod == "POST"
            body = #"{"XN":"2026-2027","XQ":"1","XNXQ":"2026秋"}"#
        } else if path == "/api/client/Station/GetList" {
            valid = request.httpMethod == "GET" && request.value(forHTTPHeaderField: "Cookie") == nil
            body = #"{"code":0,"result":[{"dwDevSN":1012,"szName":"示例站点","dwStatus":1}]}"#
        } else if path == "/api/SystemApi/GetMeetingByMeetingRoomList" {
            valid = request.httpMethod == "POST" && request.value(forHTTPHeaderField: "Authorization") == "fixture-only"
            body = #"{"IsSuccess":true,"Data":{"rows":[{"MeetingID":"m1","Topical":"示例安排","StartDateTime":"2026-10-25T10:00:00","EndDateTime":"2026-10-25T11:00:00"}]}}"#
        } else { valid = false; body = "unsupported endpoint" }
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: valid ? 200 : 400, httpVersion: nil, headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private func regressionHTTP(_ origin: String) -> ServiceHTTP {
    let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [SessionPrintFixture.self]
    return ServiceHTTP(origin: URL(string: origin)!, configuration: configuration)
}
@Test func teachingProbeRequiresAuthenticatedIdentity() async throws {
    try await SchoolSessionProbe.teaching(regressionHTTP("https://tis.sustech.edu.cn"))
}
@Test func publicSemesterResponseCannotProveLogin() async {
    await #expect(throws: CampusError.signInRequired) { try await SchoolSessionProbe.teaching(regressionHTTP("https://signedout.sustech.edu.cn")) }
}
@Test func stationsLoadWithoutSchoolCookieOrCASExchange() async throws {
    let rows = try await PrintingClient(http: regressionHTTP("https://pms.sustech.edu.cn")).stations()
    #expect(rows.count == 1); #expect(rows[0]["szName"].text == "示例站点")
}
@Test func collegeScheduleUsesIndependentAuthorization() async throws {
    let client = CollegeBookingClient(http: regressionHTTP("https://booking.sustech.edu.cn"), token: "fixture-only")
    #expect(try await client.schedule(room: "r1", day: .now).first?.id == "m1")
    let missing = CollegeBookingClient(http: regressionHTTP("https://booking.sustech.edu.cn"), token: "")
    await #expect(throws: CampusError.signInRequired) { try await missing.rooms() }
}
