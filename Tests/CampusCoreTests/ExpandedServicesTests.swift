import Foundation
import Testing
@testable import CampusCore

private func wire(_ text: String) throws -> WireValue { try JSONDecoder().decode(WireValue.self, from: Data(text.utf8)) }
private func uploadForm(course: String = "_1_1", action: String = "/webapps/assignment/uploadAssignment?action=submit", extra: String = "", draft: String = "") -> String {
    """
    <form id="uploadAssignmentFormId" method="post" enctype="multipart/form-data" action="\(action)">
    <input type="hidden" name="course_id" value="\(course)">
    <input type="hidden" name="content_id" value="_3_1">
    <input type="hidden" name="attempt_id" value="">
    <input type="hidden" name="blackboard.platform.security.NonceUtil.nonce" value="fresh-nonce">
    <input type="hidden" name="blackboard.platform.security.NonceUtil.nonce.ajax" value="ajax-nonce">
    <input type="file" id="newFile_chooseLocalFile">
    <textarea name="student_comments">\(draft)</textarea>\(extra)</form>
    """
}
@Test func libraryCatalogRejectsMalformedEnvelopes() throws {
    #expect(throws: CampusError.self) { try LibraryClient.books(wire("{}")) }
    let result = try LibraryClient.books(wire(#"{"docs":[{"context":"L","pnx":{"control":{"recordid":["abc"]},"display":{"title":["Book &amp; text"],"creator":["Author$$QAuthor"],"creationdate":["2026"]}}}]}"#))
    #expect(result.first?.title == "Book & text"); #expect(result.first?.author == "Author")
}
@Test func libraryOccupancyExcludesCommentedBuildingsAndNeverDefaultsMissingToZero() {
    let value = LibraryClient.occupancy(#"<!-- class="name">Hidden</span><span class="num2">99</span> -->class="name">IC</span><span class="num2">12</span>"#)
    #expect(value.total == nil); #expect(value.buildings["Hidden"] == nil); #expect(value.buildings["IC"] == 12)
}
@Test func courseReviewKeepsPublicIdentityAndDoesNotFabricateSearch() throws {
    #expect(throws: CampusError.self) { try ReviewClient.courses(wire("{}")) }
    let result = try ReviewClient.courses(wire(#"{"courses":{"items":[{"id":12,"name":"Math","course_code":"MA101","review_count":3,"rate_average":4.5}]}}"#))
    #expect(result.first?.id == "12"); #expect(result.first?.count == 3)
}
@Test func rechargeIdentityMustMatchAndAmountsAreBounded() throws {
    let auth = try JSONDecoder().decode(RechargeAuth.self, from: Data(#"{"userId":"123","cardId":"123","token":"token"}"#.utf8))
    #expect(throws: ServiceFailure.self) { try RechargeDraft.identity(wire(#"{"stuempno":"999","custname":"Other"}"#), auth: auth) }
    let identity = try RechargeDraft.identity(wire(#"{"stuempno":"123","custname":"Test"}"#), auth: auth)
    #expect(try RechargeDraft.fields(amount: 50, identity: identity)["je"].text == "50.00")
    #expect(throws: ServiceFailure.self) { try RechargeDraft.fields(amount: -1, identity: identity) }
    #expect(throws: ServiceFailure.self) { try RechargeDraft.requireVerifiedOrderContract() }
}
@Test func rechargeHeadersRejectControlCharacters() throws {
    let auth = try JSONDecoder().decode(RechargeAuth.self, from: Data(#"{"userId":"123","cardId":"123","token":"token\r\nInjected: x"}"#.utf8))
    #expect(throws: CampusError.self) { try auth.validate() }
}
@Test func bbFreshFormPreservesNonceAndEncodesExactlyOneFile() throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    let form = try BBSubmitForm.parse(uploadForm(), target: target)
    let data = try form.multipart(file: Data("body".utf8), filename: "report.pdf", boundary: "test-boundary")
    let text = String(decoding: data, as: UTF8.self)
    #expect(text.contains("fresh-nonce")); #expect(text.contains("ajax-nonce")); #expect(text.contains("name=\"dispatch\"\r\n\r\nsubmit"))
    #expect(text.components(separatedBy: "filename=\"report.pdf\"").count == 2)
    #expect(text.hasSuffix("--test-boundary--\r\n"))
}
@Test func bbRejectsForeignDuplicateGroupedDraftAndMismatchedForms() throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    for html in [uploadForm(action: "https://evil.example/webapps/assignment/uploadAssignment?action=submit"), uploadForm(action: "/webapps/assignment/uploadAssignment?action=submit&action=submit"), uploadForm(extra: "<input type='hidden' name='group_id' value='_9_1'>"), uploadForm(draft: "draft text"), uploadForm(course: "_9_1"), uploadForm(extra: "<input type='hidden' name='course_id' value='_1_1'>")] {
        #expect(throws: (any Error).self) { try BBSubmitForm.parse(html, target: target) }
    }
}
@Test func bbRejectsFilenameHeaderInjectionAndEmptyFiles() throws {
    let target = try BBSubmitTarget(course: "_1_1", column: "_2_1", content: "_3_1")
    let form = try BBSubmitForm.parse(uploadForm(), target: target)
    #expect(throws: ServiceFailure.self) { try form.multipart(file: Data([1]), filename: "bad\r\nname", boundary: "valid") }
    #expect(throws: ServiceFailure.self) { try form.multipart(file: Data(), filename: "x.pdf", boundary: "valid") }
}
