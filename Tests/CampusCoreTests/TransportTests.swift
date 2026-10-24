import Foundation
import Testing
@testable import CampusCore

@Test(arguments: ["//evil.example/path", "https://evil.example/path", "/\\evil.example", "relative"])
func requestsCannotEscapeServiceOrigin(_ path: String) throws {
    let origin = try #require(URL(string: "https://tis.sustech.edu.cn"))
    #expect(throws: CampusError.unsafeURL) { try CampusHTTPClient.resolve(path: path, origin: origin) }
}

@Test func normalServicePathPreservesQuery() throws {
    let origin = try #require(URL(string: "https://bb.sustech.edu.cn"))
    let url = try CampusHTTPClient.resolve(path: "/learn/api/public/v1/users/me?_fields=id", origin: origin)
    #expect(url.host == origin.host)
    #expect(url.query == "_fields=id")
}

@Test(arguments: [301, 302, 307, 401])
func redirectsAndUnauthorizedRequireSignIn(_ status: Int) {
    #expect(throws: CampusError.signInRequired) { try CampusHTTPClient.validate(status: status, data: Data()) }
}

@Test func htmlWithHTTP200IsNotSuccessfulAPIData() {
    #expect(throws: CampusError.unexpectedHTML) {
        try CampusHTTPClient.validate(status: 200, data: Data(" \n<!DOCTYPE html><html>Access denied</html>".utf8))
    }
}

@Test func forbiddenDoesNotClaimPasswordIsWrong() {
    #expect(throws: CampusError.accessDenied) { try CampusHTTPClient.validate(status: 403, data: Data()) }
}

@Test func rateLimitDoesNotTriggerAutomaticLogin() {
    #expect(throws: CampusError.rateLimited) { try CampusHTTPClient.validate(status: 429, data: Data()) }
}

@Test func successfulStatusStillChecksExpiredSessionMessage() {
    #expect(throws: CampusError.signInRequired) {
        try CampusHTTPClient.validate(status: 200, data: Data("{\"message\":\"无效会话，用户未登录\"}".utf8))
    }
}

@Test func formEncodingDoesNotTurnPlusIntoSpace() {
    let body = CampusHTTPClient.formBody(["xn": "2026+2027", "xq": "1 & 2"])
    #expect(String(decoding: body, as: UTF8.self) == "xn=2026%2B2027&xq=1%20%26%202")
}

@Test func serviceEntriesUseDistinctHTTPSOrigins() {
    #expect(SchoolService.allCases.allSatisfy { $0.portalURL.scheme == "https" })
    #expect(Set(SchoolService.allCases.map(\.id)).count == SchoolService.allCases.count)
}
