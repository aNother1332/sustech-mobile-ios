import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import CampusCore

private actor RequestLog {
    struct Entry: Sendable { let host: String; let path: String; let method: String }
    private var entries: [String: [Entry]] = [:]
    func append(_ request: URLRequest, scenario: String) {
        entries[scenario, default: []].append(Entry(host: request.url?.host ?? "", path: request.url?.path ?? "", method: request.httpMethod ?? "GET"))
    }
    func all(_ scenario: String) -> [Entry] { entries[scenario] ?? [] }
}

private class FixtureProtocol: URLProtocol, @unchecked Sendable {
    static let log = RequestLog()
    class var scenario: String { "valid" }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Task {
            let scenario = type(of: self).scenario
            await Self.log.append(request, scenario: scenario)
            let url = request.url!
            var status = 200
            var headers = ["Content-Type": "text/html"]
            var body = "<html>service</html>"
            if url.host == "cas.sustech.edu.cn" {
                if request.httpMethod == "POST" {
                    status = 302
                    headers["Location"] = scenario == "escaping" ? "https://evil.example/?ticket=ST-fixture" : "https://tis.sustech.edu.cn/cas?ticket=ST-fixture"
                } else {
                    body = "<input value='fixture' name='execution'>" + (scenario == "challenge" ? "<input name='captcha' type='text'>" : "")
                }
            } else if url.path == "/cjgl/grcjcx/grcjcx" {
                headers["Content-Type"] = "application/json"
                var bodyData = request.httpBody ?? Data()
                if bodyData.isEmpty, let stream = request.httpBodyStream {
                    stream.open()
                    var buffer = [UInt8](repeating: 0, count: 1024)
                    while stream.hasBytesAvailable {
                        let count = stream.read(&buffer, maxLength: buffer.count)
                        if count <= 0 { break }
                        bodyData.append(contentsOf: buffer.prefix(count))
                    }
                    stream.close()
                }
                let payload = (try? JSONSerialization.jsonObject(with: bodyData)) as? [String: Any]
                let page = payload?["current"] as? Int ?? 1
                let count = page == 1 ? 100 : 2
                let rows = (0..<count).map { ["kcdm": "C\(page)-\($0)", "kcmc": "示例", "xf": "1", "xscj": "A+"] }
                let data = try! JSONSerialization.data(withJSONObject: ["content": ["total": 102, "list": rows]])
                body = String(decoding: data, as: UTF8.self)
            }
            let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: "HTTP/1.1", headerFields: headers)!
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)
        }
    }
    override func stopLoading() { }
}
private final class ChallengeProtocol: FixtureProtocol, @unchecked Sendable { override class var scenario: String { "challenge" } }
private final class EscapingProtocol: FixtureProtocol, @unchecked Sendable { override class var scenario: String { "escaping" } }
private final class GradesProtocol: FixtureProtocol, @unchecked Sendable { override class var scenario: String { "grades" } }

@Test func nativeCASPostsOnlyToCASAndWalksServiceAsGET() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [FixtureProtocol.self]
    _ = try await CASClient(configuration: configuration).signIn(service: .teaching, username: "fixture", password: "fictional-password")
    let entries = await FixtureProtocol.log.all("valid")
    #expect(entries.filter { $0.method == "POST" }.allSatisfy { $0.host == "cas.sustech.edu.cn" })
    #expect(entries.contains { $0.host == "tis.sustech.edu.cn" && $0.method == "GET" })
    #expect(entries.count == 3)
}

@Test func challengePreventsAnyPasswordPOST() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [ChallengeProtocol.self]
    await #expect(throws: CASFailure.challenge) {
        try await CASClient(configuration: configuration).signIn(service: .teaching, username: "fixture", password: "fictional-password")
    }
    let entries = await FixtureProtocol.log.all("challenge")
    #expect(entries.allSatisfy { $0.method == "GET" })
}

@Test func escapingRedirectIsRejectedBeforeDestinationRequest() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [EscapingProtocol.self]
    await #expect(throws: CASFailure.redirect) {
        try await CASClient(configuration: configuration).signIn(service: .teaching, username: "fixture", password: "fictional-password")
    }
    let entries = await FixtureProtocol.log.all("escaping")
    #expect(entries.allSatisfy { $0.host == "cas.sustech.edu.cn" })
}

@Test func gradeReaderFetchesBeyondFirstPage() async throws {
    let configuration = URLSessionConfiguration.ephemeral
    configuration.protocolClasses = [GradesProtocol.self]
    let client = CampusHTTPClient(origin: URL(string: "https://tis.sustech.edu.cn")!, configuration: configuration)
    let snapshot = try await TISClient(http: client).grades()
    #expect(snapshot.records.count == 102)
    #expect(snapshot.records.last?.code == "C2-1")
    #expect(Set(snapshot.records.map(\.id)).count == 102)
}
