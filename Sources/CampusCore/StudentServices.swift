import Foundation

public enum StudentServiceApp: String, Sendable, CaseIterable {
    case leave, activities
    public var root: String { self == .leave ? "/xgxsfw/sys/qjgl" : "/xsfwdt/sys/xshdapp" }
    public var title: String { self == .leave ? "请假" : "学生活动" }
    public var entry: URL { URL(string: "https://ehall.sustech.edu.cn" + root + "/*default/index.do" + (self == .leave ? "?EMAP_LANG=zh&THEME=teal#/wdqj" : "#/hdll_new"))! }
    public var model: String { self == .leave ? "xsqjjl" : "hdllbgdz" }
    public var queryPath: String { root + (self == .leave ? "/modules/wdqj/xsqjjl.do" : "/modules/hdll_new/hdllbgdz.do") }
    public var queryFields: [String: String] { self == .leave ? [:] : ["TJ1": "99", "TJ2": "99"] }
    public static func matching(_ url: URL) -> StudentServiceApp? { guard url.host == "ehall.sustech.edu.cn" else { return nil }; return allCases.first { url.path.hasPrefix($0.root + "/") } }
}

public struct StudentServiceRecord: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let subtitle: String
    public let start: String
    public let end: String
    public let status: String
    public let text: String
    public let location: String
    public let raw: WireValue
    public static func parse(_ row: WireValue, app: StudentServiceApp) throws -> StudentServiceRecord {
        guard !row["WID"].text.isEmpty else { throw CampusError.invalidResponse(app.title) }
        func clean(_ key: String) -> String { HTMLText.plain(row[key].text) }
        if app == .leave {
            return StudentServiceRecord(id: row["WID"].text, title: clean("QJLX_DISPLAY").isEmpty ? "请假申请" : clean("QJLX_DISPLAY"), subtitle: clean("QJTS"), start: clean("QJKSSJ"), end: clean("QJJSSJ"), status: clean("PJZT"), text: clean("QJSY"), location: "", raw: .object([:]))
        }
        guard !clean("HDMC").isEmpty else { throw CampusError.invalidResponse("活动标题") }
        return StudentServiceRecord(id: row["WID"].text, title: clean("HDMC"), subtitle: [clean("HDLXDM_DISPLAY"), clean("HDGSXY_DISPLAY")].filter { !$0.isEmpty }.joined(separator: " · "), start: clean("HDKSSJ"), end: "", status: clean("SHZT_DISPLAY"), text: clean("HDJS"), location: clean("HDDD_DISPLAY").isEmpty ? clean("HDDD") : clean("HDDD_DISPLAY"), raw: row)
    }
}
public struct StudentServicePage: Sendable {
    public let records: [StudentServiceRecord]
    public let hasMore: Bool
    public static func parse(_ reply: WireValue, app: StudentServiceApp, page: Int) throws -> StudentServicePage {
        guard reply["code"].text == "0", case .array = reply["datas"][app.model]["rows"], let total = reply["datas"][app.model]["totalSize"].int else { throw ServiceFailure(app.title + "数据暂不可用") }
        let model = reply["datas"][app.model]
        let size = model["pageSize"].int ?? 20
        guard (1...100).contains(size), (model["pageNumber"].int ?? page) == page else { throw CampusError.invalidResponse(app.title + "分页") }
        let records = try model["rows"].rows.map { try StudentServiceRecord.parse($0, app: app) }
        guard !records.isEmpty || total == 0 || (page - 1) * size >= total else { throw CampusError.invalidResponse(app.title + "分页") }
        return StudentServicePage(records: records, hasMore: page * size < total)
    }
}
public struct StudentServicesClient: Sendable {
    public let app: StudentServiceApp
    public let http: ServiceHTTP
    public init(app: StudentServiceApp, http: ServiceHTTP) { self.app = app; self.http = http }
    public func records(page: Int) async throws -> StudentServicePage {
        guard page > 0 else { throw CampusError.invalidResponse("页码") }
        let form = app.queryFields.merging(["pageSize": "20", "pageNumber": String(page)]) { _, new in new }
        return try StudentServicePage.parse(await http.json(app.queryPath, form: form), app: app, page: page)
    }
    public func leaveDetail(_ id: String) async throws -> StudentServiceRecord {
        guard app == .leave, id.range(of: "^[A-Za-z0-9_-]{1,128}$", options: .regularExpression) != nil else { throw CampusError.unsafeURL }
        let response = try await http.json(app.root + "/modules/wdqj/xsqjjlxq.do", form: ["WID": id])
        guard response["code"].text == "0", case .array = response["datas"]["xsqjjlxq"]["rows"], let row = response["datas"]["xsqjjlxq"]["rows"].rows.first, row["WID"].text == id else { throw CampusError.invalidResponse("请假详情") }
        return try StudentServiceRecord.parse(row, app: .leave)
    }
}
