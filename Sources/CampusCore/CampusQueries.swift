import Foundation

public struct BusStop: Identifiable, Sendable {
    public let id: String; public let name: String; public let directions: String
    public var latitude: Double? = nil; public var longitude: Double? = nil
    public var directionIDs: [String] = []
    public init(id: String, name: String, directions: String, latitude: Double? = nil, longitude: Double? = nil, directionIDs: [String] = []) { self.directionIDs = directionIDs; self.id = id; self.name = name; self.directions = directions; self.latitude = latitude; self.longitude = longitude }
}
public struct BusArrival: Identifiable, Sendable {
    public let id: String; public let route: String; public let direction: String
    public let minutes: Int?; public let planned: String; public let reason: String; public let source: String
    public var metres: Int? = nil; public var stopsAway: Int? = nil
    public var routeID: String = ""; public var directionID: String = ""; public var tripID: String = ""
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
                directions: row["directions"].rows.map { Self.localized($0, "route_name") + " " + Self.localized($0, "direction_name") }.joined(separator: " / "), latitude: Double(row["latitude"].text), longitude: Double(row["longitude"].text), directionIDs: row["directions"].rows.map { $0["route_direction_id"].text })
        }
    }
    public func arrivals(_ stop: String) async throws -> [BusArrival] {
        guard stop.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw CampusError.unsafeURL }
        let value = try await http.json("/arrivals/\(stop)")
        guard case .array = value["arrivals"] else { throw CampusError.invalidResponse("校车到站") }
        // Position enrichment is optional: never infer remaining stops from ETA alone.
        async let routesResult = try? http.json("/routes")
        async let vehiclesResult = try? http.json("/vehicles")
        let routes = await routesResult
        let vehicles = await vehiclesResult
        return value["arrivals"].rows.enumerated().map { index, row in
            let direction = routes?.rows.flatMap { $0["directions"].rows }.first { $0["id"].text == row["route_direction_id"].text }
            let here = direction?["stops"].rows.firstIndex { $0["id"].text == stop }
            let vehicle = vehicles?.rows.first { !$0["trip_id"].text.isEmpty && $0["trip_id"].text == row["trip_id"].text }
            let remaining = here.flatMap { index in vehicle?["current_position"]["next_stop_num"].int.map { index + 1 - $0 } }
            return BusArrival(id: "\(index)", route: Self.localized(row, "route_name"), direction: Self.localized(row, "direction_name"),
                minutes: row["eta_minutes"].int, planned: row["planned_arrival_at"].text,
                reason: row["unavailable_reason"].text, source: row["source"].text, metres: row["distance"].int, stopsAway: remaining, routeID: row["route_id"].text, directionID: row["route_direction_id"].text, tripID: row["trip_id"].text)
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
    public let id: String; public let weekday: Int; public let period: Int; public let lastPeriod: Int; public let weeks: Set<Int>?
    public let kind: String
    public func overlaps(week: Int, weekday: Int, first: Int, last: Int) -> Bool {
        self.weekday == weekday && period <= last && lastPeriod >= first && (weeks == nil || weeks!.contains(week))
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
            let range = HTMLText.captures("(?:第|\\[J?)([0-9]+)(?:-([0-9]+))?(?:节\\]?|\\])", in: text).first
            let first = range.flatMap { Int($0[1]) } ?? period
            let last = range.flatMap { Int($0[2]) } ?? first
            guard first > 0, last >= first, last <= 30 else { throw CampusError.invalidResponse("教室节次范围") }
            return RoomOccupancy(id: "\(index)", weekday: weekday, period: first, lastPeriod: last, weeks: weeks,
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
            var form = ["pylx": "1", "pageNum": String(page), "pageSize": "50", "xn": semester.year, "xq": semester.term,
                "hlct": "0", "hltyxct": "0", "sfjtjs": "2", "zysfkyd": "2", "xiaoqu": "1", "mxid": "[]"]
            for key in ["jslx", "lc", "kkyx", "key", "sybm"] { form[key] = "" }
            for key in ["sfxsyxzws", "yqzws", "yqkszws", "yxzws", "yxkszws", "bjrs", "zws", "kszws"] { form[key] = "0" }
            let data = try await http.data("/component/queryDiDian", form: form, headers: ["RoleCode": "00"])
            guard !data.isEmpty else { throw ServiceFailure("教室目录暂不可用") }
            let root = try JSONDecoder().decode(WireValue.self, from: data)
            guard case .array = root["list"] else { throw CampusError.invalidResponse("教室目录") }
            let rows = root["list"].rows
            if rows.isEmpty { return result.values.sorted { $0.name < $1.name } }
            let before = result.count
            for row in rows {
                let id = row["dm"].text.isEmpty ? row["CDDM"].text : row["dm"].text
                let name = row["mc"].text.isEmpty ? row["CDMC"].text : row["mc"].text
                guard !id.isEmpty, !name.isEmpty else { throw CampusError.invalidResponse("教室目录条目") }
                result[id] = Classroom(id: id, name: name, capacity: ["zws", "ZWS", "jszw", "JSZW"].map { row[$0].text }.first { !$0.isEmpty } ?? "")
            }
            if result.count == before { throw CampusError.invalidResponse("教室目录重复分页") }
            if let total = root["total"].int, result.count >= total { return result.values.sorted { $0.name < $1.name } }
            if rows.count < 50 { return result.values.sorted { $0.name < $1.name } }
        }
        throw ServiceFailure("教室目录超过分页上限，未将不完整目录作为完整结果。")
    }
    public func schedule(_ room: Classroom, semester: Semester) async throws -> [RoomOccupancy] {
        try ClassroomParser.entries(await http.json("/cdkb/querycdkbList", form: ["cddm": room.id, "xn": semester.year, "xq": semester.term], headers: ["RoleCode": "00"]))
    }
}
