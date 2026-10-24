import Foundation

public enum BBStudyParser {
    public static func date(_ raw: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
    }

    public static func submission(attempts: [[String: Any]], userID: String) -> LearningDeadline.Submission {
        // Every returned row must have known ownership. Another student's row is never ours.
        guard attempts.allSatisfy({ !text($0, "userId").isEmpty }) else { return .unknown }
        let belonging = attempts.filter { text($0, "userId") == userID }
        if !belonging.isEmpty, belonging.allSatisfy({ $0["exempt"] as? Bool == true }) { return .exempt }
        let own = belonging.filter { $0["exempt"] as? Bool != true }
        let states = Set(own.map { text($0, "status") })
        if !states.isDisjoint(with: ["NeedsGrading", "NeedsGradingAgain", "Completed"]) { return .submitted }
        if states.isEmpty { return .pending }
        if states.isSubset(of: ["InProgress", "InProgressAgain", "Suspended", "NotAttempted"]) {
            return states == ["NotAttempted"] ? .pending : .draft
        }
        return .unknown
    }

    static func text(_ row: [String: Any], _ key: String) -> String { row[key] as? String ?? "" }
    static func object(_ row: [String: Any], _ key: String) -> [String: Any] { row[key] as? [String: Any] ?? [:] }
    static func content(_ row: [String: Any]) throws -> BBContent {
        let id = text(row, "id")
        guard !id.isEmpty else { throw CampusError.invalidResponse("BB 课程内容") }
        let handler = object(row, "contentHandler")
        let file = object(handler, "file")
        return BBContent(id: id, title: HTMLText.plain(text(row, "title")), body: HTMLText.plain(text(row, "body")),
            hasChildren: row["hasChildren"] as? Bool ?? false, handler: text(handler, "id"),
            file: (file["downloadUrl"] ?? file["url"]) as? String)
    }
}

extension BlackboardClient {
    public func userID() async throws -> String {
        let data = try await http.data(path: "/learn/api/public/v1/users/me")
        return try identifier(BlackboardParser.decode(BlackboardParser.User.self, from: data).id)
    }

    public func courseDetail(_ course: BlackboardCourse) async throws -> BBCourseDetail {
        let user = try await userID()
        let root = "/learn/api/public/v1/courses/\(try identifier(course.id))"
        var tasks: [LearningDeadline] = []
        var announcements: [BBAnnouncement] = []
        var warnings: [String] = []
        var cells: [[String: Any]]?
        do {
            let rows = try await records(path: root + "/gradebook/users/\(user)?limit=100")
            guard rows.allSatisfy({ BBStudyParser.text($0, "userId") == user && !BBStudyParser.text($0, "columnId").isEmpty }) else {
                throw CampusError.invalidResponse("BB 成绩单所属账号")
            }
            cells = rows
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("成绩单状态：\(error.localizedDescription)") }
        do {
            let columns = try await records(path: root + "/gradebook/columns?limit=100")
            var visited = Set<String>()
            for column in columns {
                try Task.checkCancellation()
                let id = try identifier(BBStudyParser.text(column, "id"))
                guard visited.insert(id).inserted else { continue }
                let grading = BBStudyParser.object(column, "grading")
                let due = BBStudyParser.text(grading, "due")
                let isAttempts = BBStudyParser.text(grading, "type") == "Attempts"
                if !isAttempts && due.isEmpty { continue }
                let title = HTMLText.plain(BBStudyParser.text(column, "name"))
                let contentID = BBStudyParser.text(column, "contentId")
                var state = LearningDeadline.Submission.unknown
                var note = "未读取到足够的提交状态信息"
                var body = ""
                let cell = cells?.first { BBStudyParser.text($0, "columnId") == id }
                if cell?["exempt"] as? Bool == true {
                    state = .exempt; note = "学校标记为免交/豁免"
                } else if isAttempts {
                    do {
                        let attempts = try await records(path: root + "/gradebook/columns/\(id)/attempts?limit=100")
                        state = BBStudyParser.submission(attempts: attempts, userID: user)
                        if !contentID.isEmpty {
                            let data = try await http.data(path: root + "/contents/\(try identifier(contentID))")
                            let item = try BBStudyParser.content(jsonObject(data))
                            body = item.body
                            let available = BBStudyParser.object(column, "availability")
                            let safeKind = ["resource/x-bb-assignment", "resource/x-bb-asmt-test-link"].contains(item.handler)
                            let external = (title + " " + body).range(of: "请勿在此处提交|仅做通知提醒|do not submit|notification only", options: [.regularExpression, .caseInsensitive]) != nil
                            if [.pending, .draft].contains(state), (!safeKind || external || cells == nil || BBStudyParser.text(available, "available") != "Yes") {
                                state = .unknown
                            }
                        } else if [.pending, .draft].contains(state) { state = .unknown }
                        note = state == .unknown ? "任务类型、权限或提交状态尚不能确认，请在课程页面核对" : "已读取本人作业尝试记录"
                    } catch is CancellationError { throw CancellationError() }
                    catch {
                        if state != .submitted && state != .exempt { state = .unknown }
                        // 404/403 are never interpreted as 'no attempts'.
                        note = "提交状态读取失败：\(error.localizedDescription)"
                        warnings.append("\(title)：\(note)")
                    }
                }
                tasks.append(LearningDeadline(id: "\(course.id)-\(id)", course: course.name, title: title,
                    due: BBStudyParser.date(due), rawDue: due, submission: state, courseID: course.id,
                    contentID: contentID.isEmpty ? nil : contentID, details: body, statusNote: note))
            }
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("任务列表：\(error.localizedDescription)") }
        do {
            let rows = try await records(path: root + "/announcements?limit=100")
            announcements = try rows.filter { $0["draft"] as? Bool != true }.map { row in
                let id = try identifier(BBStudyParser.text(row, "id"))
                return BBAnnouncement(id: id, title: HTMLText.plain(BBStudyParser.text(row, "title")),
                    body: HTMLText.plain(BBStudyParser.text(row, "body")), created: BBStudyParser.text(row, "created"))
            }.sorted { $0.created > $1.created }
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("公告：\(error.localizedDescription)") }
        return BBCourseDetail(tasks: tasks.sorted { ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture) },
            announcements: announcements, warnings: warnings)
    }

    public func contents(courseID: String, parentID: String? = nil) async throws -> [BBContent] {
        let root = "/learn/api/public/v1/courses/\(try identifier(courseID))/contents"
        let path = try parentID.map { root + "/\(try identifier($0))/children" } ?? root
        return try await records(path: path + "?limit=100").map(BBStudyParser.content)
    }

    public func attachments(courseID: String, contentID: String) async throws -> [BBAttachment] {
        let root = "/learn/api/public/v1/courses/\(try identifier(courseID))/contents/\(try identifier(contentID))"
        let content = try jsonObject(await http.data(path: root))
        var files: [BBAttachment] = []
        do {
            let rows = try await records(path: root + "/attachments?limit=100")
            files = try rows.map { row in
                let id = try identifier(BBStudyParser.text(row, "id"))
                let raw = BBStudyParser.text(row, "downloadUrl")
                return BBAttachment(id: id, name: BBStudyParser.text(row, "fileName").isEmpty ? "附件-\(id)" : BBStudyParser.text(row, "fileName"),
                    path: try pagePath(raw.isEmpty ? root + "/attachments/\(id)/download" : raw))
            }
        } catch CampusError.http(404) { /* Some Classic content has only embedded files. */ }
        let handler = BBStudyParser.object(content, "contentHandler")
        let file = BBStudyParser.object(handler, "file")
        if BBStudyParser.text(handler, "id") == "resource/x-bb-file",
           let raw = (file["downloadUrl"] ?? file["url"]) as? String {
            files.append(BBAttachment(id: "direct", name: BBStudyParser.text(file, "fileName").isEmpty ? BBStudyParser.text(content, "title") : BBStudyParser.text(file, "fileName"), path: try pagePath(raw)))
        }
        for (index, anchor) in HTMLText.captures("(?is)<a\\b([^>]*)>(.*?)</a>", in: BBStudyParser.text(content, "body")).enumerated() {
            let attrs = HTMLText.attributes(anchor[1])
            if let href = attrs["href"], let path = try? pagePath(href), path.lowercased().contains("/bbcswebdav/") {
                files.append(BBAttachment(id: "embedded-\(index)", name: HTMLText.plain(anchor[2]).isEmpty ? "课程附件" : HTMLText.plain(anchor[2]), path: path))
            }
        }
        var seen = Set<String>()
        return files.filter { seen.insert($0.path).inserted }
    }

    private func records(path: String) async throws -> [[String: Any]] {
        var next: String? = path
        var visited = Set<String>()
        var rows: [[String: Any]] = []
        while let path = next {
            guard visited.count < 100, visited.insert(path).inserted else { throw CampusError.invalidResponse("BB 分页") }
            let page = try jsonObject(await http.data(path: path))
            guard let batch = page["results"] as? [[String: Any]] else { throw CampusError.invalidResponse("BB 列表") }
            rows.append(contentsOf: batch)
            let paging = BBStudyParser.object(page, "paging")
            next = try (paging["nextPage"] as? String).flatMap { $0.isEmpty ? nil : try pagePath($0) }
        }
        return rows
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let row = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw CampusError.invalidResponse("BB 数据") }
        return row
    }
}
