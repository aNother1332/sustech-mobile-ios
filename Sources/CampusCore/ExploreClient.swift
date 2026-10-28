import Foundation

public struct ReviewCourse: Identifiable, Codable, Sendable {
    public let id: String
    public let name: String
    public let code: String
    public let teachers: String
    public let count: Int
    public let rating: String
    public var difficulty: Int? = nil
    public var homework: Int? = nil
    public var grading: Int? = nil
    public var gain: Int? = nil
}
public struct ReviewSearchPage: Sendable {
    public let items: [ReviewCourse]; public let page: Int; public let pages: Int; public let total: Int
    public var hasMore: Bool { page < pages }
}
public struct CourseReview: Identifiable, Sendable {
    public let id: String
    public let term: String
    public let rating: String
    public let content: String
}
public struct ReviewClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public static func courses(_ value: WireValue) throws -> [ReviewCourse] {
        guard case .array = value["courses"]["items"] else { throw CampusError.invalidResponse("课程评价搜索") }
        return try value["courses"]["items"].rows.map { row in
            guard !row["id"].text.isEmpty else { throw CampusError.invalidResponse("课程 ID") }
            return ReviewCourse(id: row["id"].text, name: row["name"].text, code: row["course_code"].text, teachers: row["teacher_names"].text, count: row["review_count"].int ?? 0, rating: row["rate_average"].text, difficulty: row["difficulty_score"].int, homework: row["homework_score"].int, grading: row["grading_score"].int, gain: row["gain_score"].int)
        }
    }
    public func searchPage(_ query: String, page: Int = 1) async throws -> ReviewSearchPage {
        let value = try await http.json("/api/v1/search", query: ["q": query, "type": "course", "page": String(page), "per_page": "20"])
        let meta = value["courses"]
        return ReviewSearchPage(items: try Self.courses(value), page: meta["page"].int ?? page, pages: meta["pages"].int ?? page, total: meta["total"].int ?? 0)
    }
    public func search(_ query: String, page: Int = 1) async throws -> [ReviewCourse] {
        try await searchPage(query, page: page).items
    }
    public func reviewPage(_ course: ReviewCourse, page: Int) async throws -> (items: [CourseReview], hasMore: Bool) {
        guard Int64(course.id) != nil else { throw CampusError.unsafeURL }
        let response = try await http.json("/api/v1/course/\(course.id)/reviews", query: ["page": String(page), "per_page": "20", "sort_by": "pubtime_desc"])
        let value = response["items"] == .null ? response["reviews"]["items"] : response["items"]
        guard case .array = value else { throw CampusError.invalidResponse("课程评价") }
        let items: [CourseReview] = value.rows.enumerated().compactMap { i, row in
            guard row["only_visible_to_student"] != .bool(true), row["is_hidden"] != .bool(true), row["is_blocked"] != .bool(true) else { return nil }
            return CourseReview(id: row["id"].text.isEmpty ? "\(page)-\(i)" : row["id"].text, term: row["term_display"].text.isEmpty ? row["term"].text : row["term_display"].text, rating: row["rate"].text, content: HTMLText.plain(row["content"].text))
        }
        let meta = response["reviews"] == .null ? response : response["reviews"]
        return (items, page < (meta["pages"].int ?? page))
    }
    public func reviews(_ course: ReviewCourse, page: Int) async throws -> [CourseReview] { try await reviewPage(course, page: page).items }

}

public struct DegreeSection: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let values: [(String, String)]
}
public struct DegreeResult: Sendable {
    public let sections: [DegreeSection]
    public let warnings: [String]
}
public struct DegreeClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public static func rows(_ value: WireValue) throws -> [WireValue] {
        if value["code"] != .null, value["content"] != .null {
            let code = value["code"].text
            if ["401", "302"].contains(code) { throw CampusError.signInRequired }
            guard ["", "0", "200"].contains(code) else { throw ServiceFailure("学校修读进度接口拒绝请求。") }
            return try rows(value["content"])
        }
        if case .array = value { return value.rows }
        for key in ["data", "rows", "list", "content", "aaData"] { if value[key] != .null { return try rows(value[key]) } }
        if case .object = value, !value.fields.isEmpty { return [value] }
        throw CampusError.invalidResponse("修读进度")
    }
    public func progress() async throws -> DegreeResult {
        let base = "/cjgl/cjzhtjcx/cjcx/"
        _ = try await http.data("/cjgl/grcjcx/cjxqList")
        var type = "1"
        if let me = try? await http.json("/user/me") {
            type = ["pylx", "PYLX", "pylxdm", "PYLXDM"].map { me[$0].text }.first { !$0.isEmpty } ?? (me["pyccm"].text == "2" ? "2" : "1")
        }
        let contexts = try Self.rows(await http.json(base + "getXss", payload: .object(["pylx": .string(type)])))
        guard let selected = contexts.first(where: { !$0["fah"].text.isEmpty || !$0["FAH"].text.isEmpty }) ?? contexts.first else { throw ServiceFailure("学校未返回本人的培养方案。") }
        var fields: [String: WireValue] = [:]
        for (key, value) in selected.fields { fields[key.lowercased()] = value }
        fields["pylx"] = fields["pylx"] ?? .string(type)
        let labels: [String: String] = ["YQXDXF": "要求学分", "XF": "完成学分", "MS": "要求门数", "ZYFXMC": "专业方向", "XFLBMC": "类别", "YQWCXF": "要求学分", "YQXF": "要求学分", "YWCXF": "完成学分", "WWCXF": "未完成学分", "BZ": "备注", "KZMC": "模块", "MKMC": "模块", "SFTG": "学校通过标记", "WC_XF": "尚差学分", "WC_MS": "尚差门数", "YWCMS": "已完成门数", "WWCMS": "未完成门数"]
        var sections: [DegreeSection] = []; var warnings: [String] = []
        for (path, title) in [("querybyyq", "学校总要求"), ("queryBxkqk", "完成情况"), ("queryXflbyq", "学分类别"), ("queryMkyq", "模块要求")] {
            do {
                var records: [WireValue] = []; var previous: [WireValue]?
                for page in 1...20 {
                    let reply = try await http.json(base + path, payload: .object(fields.merging(["pageSize": .integer(200), "pageNum": .integer(Int64(page))]) { _, b in b }))
                    let batch = try Self.rows(reply)
                    if let previous, batch == previous, !batch.isEmpty { throw CampusError.invalidResponse("修读进度重复分页") }
                    records += batch; previous = batch
                    if path != "queryXflbyq" || batch.count < 200 { break }
                    if page == 20 { warnings.append(title + "：达到读取上限，请到学校页面核对。") }
                }
                let rows = records
                for (index, row) in rows.enumerated() {
                    let values = row.fields.sorted { $0.key < $1.key }.compactMap { key, value -> (String, String)? in
                        guard let label = labels[key.uppercased()], !value.text.isEmpty else { return nil }; return (label, value.text)
                    }
                    if !values.isEmpty { sections.append(DegreeSection(id: "\(path)-\(index)", title: title, values: values)) }
                }
                
            } catch { warnings.append(title + "：" + error.localizedDescription) }
        }
        guard !sections.isEmpty else { throw ServiceFailure(warnings.first ?? "未取得可解释的学校修读进度。") }
        return DegreeResult(sections: sections, warnings: warnings)
    }
}
