import Foundation
import Testing
@testable import CampusCore

private class CardQRFixture: URLProtocol, @unchecked Sendable {
    class var missingToken: Bool { false }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path
        let body: String
        var status = 200
        if path == "/epay/vcard/index" {
            body = type(of: self).missingToken ? "<html>No token</html>" : "<meta content='fixture-token' name='_csrf'><meta name='_csrf_header' content='X-CSRF-TOKEN'>"
        } else if path == "/epay/vcard/getqrcode" {
            if request.httpMethod != "POST" || request.value(forHTTPHeaderField: "X-CSRF-TOKEN") != "fixture-token" { status = 400 }
            body = #"{"qrcode":"SWH5_fixture_never_valid"}"#
        } else { body = "<input value='identity&amp;fixture' id='myText'>" }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data(body.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private final class MissingQRTokenFixture: CardQRFixture, @unchecked Sendable { override class var missingToken: Bool { true } }

private func cardCodeClient(_ type: URLProtocol.Type) -> CardCodeClient {
    let configuration = URLSessionConfiguration.ephemeral; configuration.protocolClasses = [type]
    return CardCodeClient(http: ServiceHTTP(origin: URL(string: "https://campuscard.sustech.edu.cn")!, configuration: configuration))
}
@Test func campusQRFetchesFreshCSRFBeforePOST() async throws {
    #expect(try await cardCodeClient(CardQRFixture.self).code(.campus) == "SWH5_fixture_never_valid")
}
@Test func campusQRRejectsMissingCSRFInsteadOfPosting() async {
    await #expect(throws: CampusError.invalidResponse("校园码 CSRF")) { try await cardCodeClient(MissingQRTokenFixture.self).code(.campus) }
}
@Test func identityCodeHandlesAttributeOrderAndEntities() async throws {
    #expect(try await cardCodeClient(CardQRFixture.self).code(.identity) == "identity&fixture")
}
