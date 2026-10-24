import Foundation

public struct BusStop: Identifiable, Sendable {
    public let id: String; public let name: String; public let directions: String
}
public struct BusArrival: Identifiable, Sendable {
    public let id: String; public let route: String; public let direction: String
    public let minutes: Int?; public let planned: String; public let reason: String; public let source: String
}
public struct BusClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func stops() async throws -> [BusStop] {
        let value = try await http.json("/stops")
        guard case .array = value else { throw CampusError.invalidResponse("校车站点") }
        return value.rows.compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            let name = [Self.localized(row, "group_name"), Self.localized(row, "name")].filter { !$0.isEmpty }.joined(separator: " · ")
            return BusStop(id: row["id"].text, name: name,
                directions: row["directions"].rows.map { Self.localized($0, "route_name") + " " + Self.localized($0, "direction_name") }.joined(separator: " / "))
        }
    }
    public func arrivals(_ stop: String) async throws -> [BusArrival] {
        guard stop.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw CampusError.unsafeURL }
        let value = try await http.json("/arrivals/\(stop)")
        guard case .array = value["arrivals"] else { throw CampusError.invalidResponse("校车到站") }
        return value["arrivals"].rows.enumerated().map { index, row in
            BusArrival(id: "\(index)", route: Self.localized(row, "route_name"), direction: Self.localized(row, "direction_name"),
                minutes: row["eta_minutes"].int, planned: row["planned_arrival_at"].text,
                reason: row["unavailable_reason"].text, source: row["source"].text)
        }
    }
    private static func localized(_ row: WireValue, _ key: String) -> String {
        [row[key + "_zh"].text, row[key + "_en"].text, row[key].text].first { !$0.isEmpty } ?? ""
    }
}

public struct Classroom: Identifiable, Sendable {
    public let id: String; public let name: String; public let capacity: String
}
public struct RoomOccupancy: Identifiable, Sendable {
    public let id: String; public let weekday: Int; public let period: Int; public let weeks: Set<Int>?
    public let kind: String
    public func overlaps(week: Int, weekday: Int, first: Int, last: Int) -> Bool {
        self.weekday == weekday && (first...last).contains(period) && (weeks == nil || weeks!.contains(week))
    }
}
public enum ClassroomParser {
    public static func entries(_ value: WireValue) throws -> [RoomOccupancy] {
        guard case .array = value else { throw CampusError.invalidResponse("教室占用") }
        return try value.rows.enumerated().map { index, row in
            let key = HTMLText.captures("^xq([1-7])_jc([0-9]+)$", in: row["KEY"].text).first
            guard let key, let weekday = Int(key[1]), let period = Int(key[2]), period > 0 else { throw CampusError.invalidResponse("教室节次") }
            let text = row["SKSJ"].text
            let bitmap = row["ZC"].text
            var weeks: Set<Int>?
            if !bitmap.isEmpty { weeks = try TISParser.weeks(bitmap).map(Set.init) }
            else if let pattern = HTMLText.captures("\\[([0-9,，-]+)周\\]", in: text).first {
                var found = Set<Int>()
                for part in pattern[1].replacingOccurrences(of: "，", with: ",").split(separator: ",") {
                    let bounds = part.split(separator: "-").compactMap { Int($0) }
                    if bounds.count == 1 { found.insert(bounds[0]) }
                    else if bounds.count == 2, bounds[0] > 0, bounds[1] >= bounds[0], bounds[1] <= 60 { found.formUnion(bounds[0]...bounds[1]) }
                }
                if !found.isEmpty { weeks = found }
            }
            // Missing week information is treated conservatively as possibly occupied.
            // Borrower names and phone numbers are intentionally discarded.
            return RoomOccupancy(id: "\(index)", weekday: weekday, period: period, weeks: weeks,
                kind: text.contains("借用") ? "教室借用" : "课程或其他安排")
        }
    }
}
public struct ClassroomClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func catalog(semester: Semester) async throws -> [Classroom] {
        var result: [String: Classroom] = [:]
        for page in 1...20 {
            var form = ["pylx": "1", "pageNum": String(page), "pageSize": "100", "xn": semester.year, "xq": semester.term,
                "hlct": "0", "hltyxct": "0", "sfjtjs": "2", "zysfkyd": "2", "xiaoqu": "1", "mxid": "[]"]
            for key in ["jslx", "lc", "kkyx", "key", "sybm"] { form[key] = "" }
            for key in ["sfxsyxzws", "yqzws", "yqkszws", "yxzws", "yxkszws", "bjrs", "zws", "kszws"] { form[key] = "0" }
            let root = try await http.json("/component/queryDiDian", form: form, headers: ["RoleCode": "00"])
            guard case .array = root["list"] else { throw CampusError.invalidResponse("教室目录") }
            let rows = root["list"].rows
            if rows.isEmpty { return result.values.sorted { $0.name < $1.name } }
            let before = result.count
            for row in rows {
                let id = row["dm"].text.isEmpty ? row["CDDM"].text : row["dm"].text
                let name = row["mc"].text.isEmpty ? row["CDMC"].text : row["mc"].text
                guard !id.isEmpty, !name.isEmpty else { throw CampusError.invalidResponse("教室目录条目") }
                result[id] = Classroom(id: id, name: name, capacity: row["zws"].text)
            }
            if result.count == before { throw CampusError.invalidResponse("教室目录重复分页") }
            if let total = root["total"].int, result.count >= total { return result.values.sorted { $0.name < $1.name } }
            if rows.count < 100 { return result.values.sorted { $0.name < $1.name } }
        }
        throw ServiceFailure("教室目录超过分页上限，未将不完整目录作为完整结果。")
    }
    public func schedule(_ room: Classroom, semester: Semester) async throws -> [RoomOccupancy] {
        try ClassroomParser.entries(await http.json("/cdkb/querycdkbList", form: ["cddm": room.id, "xn": semester.year, "xq": semester.term], headers: ["RoleCode": "00"]))
    }
}
