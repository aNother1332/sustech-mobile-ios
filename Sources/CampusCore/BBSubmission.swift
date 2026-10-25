import Foundation

public struct BBSubmitTarget: Codable, Sendable, Equatable {
    public let course: String; public let column: String; public let content: String
    public init(course: String, column: String, content: String) throws {
        for id in [course, column, content] { guard id.range(of: "^_[0-9]+_1$", options: .regularExpression) != nil else { throw CampusError.invalidResponse("BB 作业标识") } }
        self.course = course; self.column = column; self.content = content
    }
    public var page: String { "/webapps/assignment/uploadAssignment?course_id=\(course)&content_id=\(content)" }
}
public struct BBSubmitForm: Sendable {
    public let action: String
    public let fields: [String: String]
    public static func parse(_ html: String, target: BBSubmitTarget) throws -> BBSubmitForm {
        let forms = HTMLText.captures("(?is)<form\\b([^>]*)>(.*?)</form>", in: html).filter { HTMLText.attributes($0[1])["id"] == "uploadAssignmentFormId" }
        guard forms.count == 1 else { throw ServiceFailure("不是可支持的个人文件作业表单。") }
        let attrs = HTMLText.attributes(forms[0][1]); let body = forms[0][2]
        guard attrs["method"]?.lowercased() == "post", attrs["enctype"]?.lowercased() == "multipart/form-data",
              let raw = attrs["action"], let url = URL(string: raw, relativeTo: URL(string: "https://bb.sustech.edu.cn")!)?.absoluteURL,
              url.scheme == "https", url.host == "bb.sustech.edu.cn", url.port == nil || url.port == 443,
              url.user == nil, url.password == nil, url.fragment == nil, url.path == "/webapps/assignment/uploadAssignment" else { throw CampusError.unsafeURL }
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard query.filter({ $0.name == "action" }).count == 1, query.first(where: { $0.name == "action" })?.value == "submit",
              query.allSatisfy({ ["action", "course_id", "content_id", "group_id"].contains($0.name) }),
              Set(query.map(\.name)).count == query.count else { throw CampusError.unsafeURL }
        for item in query {
            if item.name == "course_id", item.value != target.course { throw CampusError.unsafeURL }
            if item.name == "content_id", item.value != target.content { throw CampusError.unsafeURL }
            if item.name == "group_id", !(item.value ?? "").isEmpty { throw ServiceFailure("暂不支持小组作业。") }
        }
        var fields: [String: String] = [:]; var files = 0
        for tag in HTMLText.captures("(?is)<input\\b[^>]*>", in: body) {
            guard tag[0].range(of: "(?i)\\sdisabled(?:\\s|=|/?>)", options: .regularExpression) == nil else { continue }
            let attrs = HTMLText.attributes(tag[0]); let type = attrs["type"]?.lowercased() ?? "text"
            if type == "file", attrs["id"] == "newFile_chooseLocalFile" { files += 1 }
            if type == "hidden", let name = attrs["name"] {
                guard fields[name] == nil else { throw ServiceFailure("作业表单有重复字段。") }
                fields[name] = attrs["value"] ?? ""
            }
        }
        for area in HTMLText.captures("(?is)<textarea\\b([^>]*)>(.*?)</textarea>", in: body) {
            guard HTMLText.plain(area[2]).isEmpty else { throw ServiceFailure("发现已有草稿，请先到学校页面处理。") }
            if area[1].range(of: "(?i)\\sdisabled(?:\\s|=|$)", options: .regularExpression) != nil { continue }
            if let name = HTMLText.attributes(area[1])["name"] { guard fields[name] == nil else { throw ServiceFailure("编辑器字段冲突。") }; fields[name] = "" }
        }
        guard files == 1, fields["course_id"] == target.course, fields["content_id"] == target.content,
              fields["attempt_id"] == "", fields["attemptId", default: ""].isEmpty,
              fields["group_id", default: ""].isEmpty,
              !(fields["blackboard.platform.security.NonceUtil.nonce"] ?? "").isEmpty else { throw ServiceFailure("作业身份、验证字段或空白草稿状态不符合要求。") }
        return BBSubmitForm(action: url.path + "?" + (URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery ?? ""), fields: fields)
    }
    public func multipart(file: Data, filename: String, boundary: String) throws -> Data {
        guard !file.isEmpty, file.count <= 50 * 1024 * 1024,
              !filename.isEmpty, filename.range(of: "[\\r\\n\"\\\\/]", options: .regularExpression) == nil,
              boundary.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) != nil else { throw ServiceFailure("文件名或大小不符合提交要求。") }
        let fields = fields.merging(["isAjaxSubmit": "true", "dispatch": "submit", "newFile_attachmentType": "L", "newFile_fileId": "new", "newFile_artifactFileId": "undefined", "newFile_artifactType": "undefined", "newFile_artifactTypeResourceKey": "undefined", "newFile_linkTitle": filename]) { _, b in b }
        var data = Data()
        for (key, value) in fields.sorted(by: { $0.key < $1.key }) {
            guard key.range(of: "[\\r\\n\"]", options: .regularExpression) == nil else { throw CampusError.invalidResponse("表单字段") }
            data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
        }
        data.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"newFile_LocalFile0\"; filename=\"\(filename)\"\r\nContent-Type: application/octet-stream\r\n\r\n".utf8)); data.append(file); data.append(Data("\r\n--\(boundary)--\r\n".utf8)); return data
    }
}
public struct BBSubmitPreview: Codable, Sendable {
    public let user: String; public let attempts: Set<String>; public let target: BBSubmitTarget
}
private enum BBHistoryFailure: Error { case initialPageMissing }

public struct BBSubmissionClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    private func all(_ path: String, initialMissing: Bool = false) async throws -> [WireValue] {
        var result: [WireValue] = []; var next: String? = path; var seen = Set<String>()
        for _ in 0..<100 {
            guard let page = next else { return result }
            guard page.hasPrefix("/learn/api/public/"), !page.contains(".."), seen.insert(page).inserted else { throw CampusError.unsafeURL }
            let response: WireValue
            do { response = try await http.json(page) }
            catch CampusError.http(404) { if initialMissing, seen.count == 1 { throw BBHistoryFailure.initialPageMissing }; throw CampusError.http(404) }
            guard case .array = response["results"] else { throw CampusError.invalidResponse("BB 提交记录分页") }
            result += response["results"].rows
            let raw = response["paging"]["nextPage"].text
            if raw.isEmpty { return result }
            guard let url = URL(string: raw, relativeTo: http.origin)?.absoluteURL, url.host == http.origin.host, url.scheme == "https", url.port == http.origin.port, url.path == URL(string: path, relativeTo: http.origin)?.path, url.user == nil, url.password == nil else { throw CampusError.unsafeURL }
            next = url.path + (url.query.map { "?" + $0 } ?? "")
        }
        throw CampusError.invalidResponse("BB 分页上限")
    }
    private func attempts(_ target: BBSubmitTarget, user: String) async throws -> [WireValue] {
        guard user.range(of: "^_[0-9]+_1$", options: .regularExpression) != nil else { throw CampusError.invalidResponse("BB 本人身份") }
        let path = "/learn/api/public/v2/courses/\(target.course)/gradebook/columns/\(target.column)/attempts?userId=\(user)&limit=100"
        let rows = try await all(path, initialMissing: true)
        guard rows.allSatisfy({ !$0["id"].text.isEmpty && $0["userId"].text == user }), Set(rows.map { $0["id"].text }).count == rows.count else { throw CampusError.invalidResponse("本人提交历史") }
        return rows
    }
    public func preview(_ target: BBSubmitTarget) async throws -> BBSubmitPreview {
        let user = try await http.json("/learn/api/public/v1/users/me")["id"].text
        let root = "/learn/api/public/v1/courses/\(target.course)"
        let column = try await http.json(root + "/gradebook/columns/" + target.column)
        let content = try await http.json(root + "/contents/" + target.content)
        guard column["contentId"].text == target.content,
              column["grading"]["type"].text == "Attempts", column["availability"]["available"].text == "Yes",
              content["contentHandler"]["id"].text == "resource/x-bb-assignment" else { throw ServiceFailure("仅支持开放的 Original 个人文件作业。") }
        let view = String(decoding: try await http.data(target.page + "&mode=view"), as: UTF8.self)
        _ = try BBSubmitForm.parse(view, target: target)
        let rows: [WireValue]
        do { rows = try await attempts(target, user: user) }
        catch BBHistoryFailure.initialPageMissing {
            // Only a proven blank first-upload view permits the initial missing history.
            guard view.range(of: "(?i)<title>\\s*(Upload Assignment:|上传作业[:：])", options: .regularExpression) != nil,
                  !view.contains("aggregateGradeForm"), !view.contains("attempt_id="), !view.contains("attemptId=") else { throw CampusError.invalidResponse("首次提交历史") }
            rows = []
        }
        guard !rows.contains(where: { ["InProgress", "Draft"].contains($0["status"].text) }) else { throw ServiceFailure("存在未完成草稿，请先在学校页面处理。") }
        return BBSubmitPreview(user: user, attempts: Set(rows.map { $0["id"].text }), target: target)
    }
    /// Called only after explicit final confirmation; never retries the POST.
    public func submit(_ preview: BBSubmitPreview, file: Data, filename: String) async throws -> String {
        let fresh = try await self.preview(preview.target)
        guard fresh.user == preview.user, fresh.attempts == preview.attempts else { throw ServiceFailure("提交历史已变化，请重新预检。") }
        let data = try await http.data(preview.target.page + "&action=newAttempt&group_id=")
        let form = try BBSubmitForm.parse(String(decoding: data, as: UTF8.self), target: preview.target)
        let boundary = "Campus-" + UUID().uuidString
        let body = try form.multipart(file: file, filename: filename, boundary: boundary)
        do { _ = try await http.data(form.action, body: body, contentType: "multipart/form-data; boundary=" + boundary, headers: ["Origin": "https://bb.sustech.edu.cn", "Referer": "https://bb.sustech.edu.cn" + preview.target.page + "&action=newAttempt&group_id="]) }
        catch { /* A lost response is reconciled below; never resend. */ }
        return try await reconcile(preview, filename: filename)
    }
    public func reconcile(_ preview: BBSubmitPreview, filename: String) async throws -> String {
        let rows = try await attempts(preview.target, user: preview.user)
        let candidates = rows.filter { !preview.attempts.contains($0["id"].text) }
        guard candidates.count == 1, let row = candidates.first, ["NeedsGrading", "Completed"].contains(row["status"].text) else { throw ServiceFailure("提交结果尚不能确认，请查学校记录，不要重复提交。") }
        let id = row["id"].text
        guard id.range(of: "^_[0-9]+_1$", options: .regularExpression) != nil else { throw CampusError.invalidResponse("提交回执 ID") }
        let detail = try await http.json("/learn/api/public/v2/courses/\(preview.target.course)/gradebook/columns/\(preview.target.column)/attempts/\(id)")
        guard detail["id"].text == id, detail["userId"].text == preview.user, ["NeedsGrading", "Completed"].contains(detail["status"].text) else { throw ServiceFailure("提交状态未确认。") }
        let files = try await all("/learn/api/public/v1/courses/\(preview.target.course)/gradebook/attempts/\(id)/files?limit=100")
        guard files.contains(where: { $0["name"].text == filename }) else { throw ServiceFailure("新提交记录中未找到选定文件。") }
        return id
    }
}
