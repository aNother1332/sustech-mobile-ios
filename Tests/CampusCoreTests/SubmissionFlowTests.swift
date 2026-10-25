import Foundation
import Testing
@testable import CampusCore

private final class PostCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Int] = [:]
    func reset(_ key: String) { lock.lock(); defer { lock.unlock() }; values[key] = 0 }
    func count(_ key: String) -> Int { lock.lock(); defer { lock.unlock() }; return values[key] ?? 0 }
    func increment(_ key: String) { lock.lock(); defer { lock.unlock() }; values[key, default: 0] += 1 }
}
private class SubmissionProtocol: URLProtocol, @unchecked Sendable {
    static let counts = PostCounter()
    class var mode: String { "lost" }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let mode = type(of: self).mode; let path = request.url!.path
        var status = 200; var text = "{}"
        if path == "/learn/api/public/v1/users/me" { text = #"{"id":"_4_1"}"# }
        else if path.hasSuffix("/columns/_2_1") { text = #"{"contentId":"_3_1","grading":{"type":"Attempts"},"availability":{"available":"Yes"}}"# }
        else if path.hasSuffix("/contents/_3_1") { text = #"{"contentHandler":{"id":"resource/x-bb-assignment"}}"# }
        else if path == "/webapps/assignment/uploadAssignment" {
            if request.httpMethod == "POST" {
                Self.counts.increment(mode)
                client?.urlProtocol(self, didFailWithError: URLError(.timedOut)); return
            }
            text = """
            <title>Upload Assignment: Sample</title><form id="uploadAssignmentFormId" method="post" enctype="multipart/form-data" action="/webapps/assignment/uploadAssignment?action=submit">
            <input type="hidden" name="course_id" value="_1_1"><input type="hidden" name="content_id" value="_3_1"><input type="hidden" name="attempt_id" value=""><input type="hidden" name="blackboard.platform.security.NonceUtil.nonce" value="fresh"><input type="file" id="newFile_chooseLocalFile"></form>
            """
        } else if path.hasSuffix("/attempts") {
            let count = Self.counts.count(mode)
            if mode == "later" {
                if request.url!.query!.contains("offset=2") { status = 404 }
                else { text = #"{"results":[{"id":"_8_1","userId":"_4_1","status":"Completed"}],"paging":{"nextPage":"/learn/api/public/v2/courses/_1_1/gradebook/columns/_2_1/attempts?userId=_4_1&offset=2"}}"# }
            } else if mode == "missing-owner" { text = #"{"results":[{"id":"_9_1","status":"Completed"}]}"# }
            else if mode == "duplicates" { text = #"{"results":[{"id":"_9_1","userId":"_4_1","status":"Completed"},{"id":"_10_1","userId":"_4_1","status":"Completed"}]}"# }
            else { text = count == 0 ? #"{"results":[]}"# : #"{"results":[{"id":"_9_1","userId":"_4_1","status":"NeedsGrading"}]}"# }
        } else if path.hasSuffix("/attempts/_9_1") { text = #"{"id":"_9_1","userId":"_4_1","status":"NeedsGrading"}"# }
        else if path.hasSuffix("/files") { text = #"{"results":[{"id":"f1","name":"report.pdf"}]}"# }
        else { status = 404 }
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed); client?.urlProtocol(self, didLoad: Data(text.utf8)); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
private final class LaterMissingProtocol: SubmissionProtocol, @unchecked Sendable { override class var mode: String { "later" } }
private final class MissingOwnerProtocol: SubmissionProtocol, @unchecked Sendable { override class var mode: String { "missing-owner" } }
private final class DuplicateAttemptProtocol: SubmissionProtocol, @unchecked Sendable { override class var mode: String { "duplicates" } }
private func submissionClient(_ type: AnyClass) -> BBSubmissionClient {
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [type]
    return BBSubmissionClient(http: ServiceHTTP(origin: URL(string: "https://bb.sustech.edu.cn")!, configuration: config))
}
@Test func lostPostResponseIsReconciledWithoutASecondPost() async throws {
    SubmissionProtocol.counts.reset("lost")
    let client = submissionClient(SubmissionProtocol.self)
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    let preview = try await client.preview(target)
    let receipt = try await client.submit(preview, file: Data("file".utf8), filename: "report.pdf")
    #expect(receipt == "_9_1"); #expect(SubmissionProtocol.counts.count("lost") == 1)
}
@Test func laterAttemptPage404DoesNotBecomeAnEmptyHistory() async throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    await #expect(throws: CampusError.http(404)) { try await submissionClient(LaterMissingProtocol.self).preview(target) }
}
@Test func missingOwnershipCannotConfirmSubmission() async throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    let preview = BBSubmitPreview(user: "_4_1", attempts: [], target: target)
    await #expect(throws: (any Error).self) { try await submissionClient(MissingOwnerProtocol.self).reconcile(preview, filename: "report.pdf") }
}
@Test func multipleNewAttemptsNeverConfirmOneFile() async throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    let preview = BBSubmitPreview(user: "_4_1", attempts: [], target: target)
    await #expect(throws: ServiceFailure.self) { try await submissionClient(DuplicateAttemptProtocol.self).reconcile(preview, filename: "report.pdf") }
}
