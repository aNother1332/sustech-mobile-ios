import Foundation

public struct CandidateSlot: Codable, Sendable {
    public let weekday: Int; public let first: Int; public let last: Int; public let weeks: [Int]; public let room: String
}
public struct CandidateClass: Identifiable, Codable, Sendable {
    public let id: String; public let code: String; public let name: String; public let teachers: String
    public let credits: Double; public let schedule: String; public let slots: [CandidateSlot]
}
public enum CandidateParser {
    public static func slots(_ html: String) -> [CandidateSlot] {
        let paragraphs = HTMLText.captures("(?is)<p>([^<]*)</p>", in: html).filter { !HTMLText.plain($0[1]).isEmpty }
        let parsed = paragraphs.compactMap { match -> CandidateSlot? in
            let text = HTMLText.decoded(match[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let row = HTMLText.captures("^([0-9,，-]+)(单|双)?周,星期([一二三四五六日])第([0-9]+)(?:-([0-9]+))?节\\s+(.+)$", in: text).first,
                  let index = Array("一二三四五六日").firstIndex(of: Character(row[3])), let first = Int(row[4]), let last = Int(row[5].isEmpty ? row[4] : row[5]), first > 0, last >= first, last <= 30 else { return nil }
            var weeks = Set<Int>()
            for range in row[1].replacingOccurrences(of: "，", with: ",").split(separator: ",") {
                let ends = range.split(separator: "-").compactMap { Int($0) }
                guard let begin = ends.first, let end = ends.last, begin > 0, end >= begin, end <= 60, ends.count <= 2 else { return nil }
                for week in begin...end { if row[2].isEmpty || (row[2] == "单" && week % 2 == 1) || (row[2] == "双" && week % 2 == 0) { weeks.insert(week) } }
            }
            guard !weeks.isEmpty else { return nil }
            return CandidateSlot(weekday: index + 1, first: first, last: last, weeks: weeks.sorted(), room: row[6])
        }
        return parsed.count == paragraphs.count ? parsed : []
    }
}
public struct CandidateClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func search(_ query: String, page: Int) async throws -> [CandidateClass] {
        let term = try await http.json("/Xsxk/queryXkdqXnxq", form: [:])
        let semester = try TISParser.semester(await http.data("/component/querydangqianxnxq", form: [:]))
        var fields: [String: String] = ["p_pylx": "1", "p_sfgldjr": "", "p_sfredis": "", "p_sfsyxkgwc": "1", "p_chaxunxh": "", "p_gjz": query, "p_skjs": "", "p_xn": semester.year, "p_xq": semester.term, "p_xnxq": "", "p_xkfsdm": "bxxk", "p_xiaoqu": "", "p_kkyx": "", "p_kclb": "", "p_sfhlctkc": "0", "p_sfhllrlkc": "0", "p_kxsj_xqj": "", "p_kxsj_ksjc": "", "p_kxsj_jsjc": "", "p_skyy": "", "p_sfmxzj": "0", "cxsfmt": term["cxsfmt"].text.isEmpty ? "0" : term["cxsfmt"].text, "mxpylx": "1", "pageNum": String(page), "pageSize": "20"]
        for key in ["p_dqxn", "p_dqxq", "p_dqxnxq"] { fields[key] = term[key].text }
        let value = try await http.json("/Xsxk/queryKxrw", form: fields)
        guard value["jg"].text == "1", case .array = value["kxrwList"]["list"] else { throw ServiceFailure("当前学校选课范围未开放或不可读取，可先使用手工候选时段。") }
        return try value["kxrwList"]["list"].rows.map { row in
            guard !row["rwh"].text.isEmpty else { throw CampusError.invalidResponse("候选教学班") }
            return CandidateClass(id: row["rwh"].text, code: row["kcdm"].text, name: row["kcmc"].text, teachers: row["dgjsmc"].text, credits: Double(row["xf"].text) ?? 0, schedule: HTMLText.plain(row["kcxx"].text), slots: CandidateParser.slots(row["kcxx"].text))
        }
    }
}
public enum ReservationAgendaPolicy {
    public static func activeIC(_ row: WireValue) -> Bool { guard let status = row["resvStatus"].int else { return false }; return status & 1024 != 0 && status & 2 != 0 }
    public static func activeCourt(_ row: WireValue) -> Bool { ["1", "2"].contains(row["status"].text) }
}
