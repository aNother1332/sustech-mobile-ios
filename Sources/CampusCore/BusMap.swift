import Foundation

public struct BusCoordinate: Sendable, Equatable {
    public let latitude: Double
    public let longitude: Double
    public init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite, (-90...90).contains(latitude), (-180...180).contains(longitude), latitude != 0 || longitude != 0 else { return nil }
        self.latitude = latitude; self.longitude = longitude
    }
}
public struct BusMapRoute: Identifiable, Sendable {
    public let id: String; public let name: String; public let color: String; public let service: String
    public let directions: [Direction]
    public struct Direction: Identifiable, Sendable {
        public let id: String; public let name: String; public let points: [BusCoordinate]; public let stopIDs: [String]
    }
}
public struct BusVehicle: Identifiable, Sendable {
    public let id: String; public let name: String; public let type: String; public let coordinate: BusCoordinate
    public let routeID: String; public let directionID: String; public let nextStop: String
    public let speed: Double?; public let heading: Double?; public let updatedAt: Date?; public let receivedAt: Date?
    public let operating: Bool; public let status: String; public let dataStatus: String
    public var tripID: String = ""; public var nextStopID: String = ""
    public func isFresh(at now: Date) -> Bool {
        guard let updatedAt else { return false }
        return (-60...120).contains(now.timeIntervalSince(updatedAt)) && (dataStatus.isEmpty || dataStatus.lowercased() == "normal")
    }
}
public enum BusMapParser {
    public static func date(_ text: String) -> Date? {
        let format = ISO8601DateFormatter(); format.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = format.date(from: text) { return date }
        format.formatOptions = [.withInternetDateTime]; return format.date(from: text)
    }
    public static func routes(_ value: WireValue) throws -> [BusMapRoute] {
        guard case .array = value else { throw CampusError.invalidResponse("校车地图线路") }
        return value.rows.compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            let directions: [BusMapRoute.Direction] = row["directions"].rows.compactMap { direction in
                guard !direction["id"].text.isEmpty else { return nil }
                let geometry: WireValue
                if case .string(let text) = direction["geometry_json"] { geometry = (try? JSONDecoder().decode(WireValue.self, from: Data(text.utf8))) ?? .null }
                else { geometry = direction["geometry_json"] }
                let points = geometry.rows.compactMap { item -> BusCoordinate? in
                    guard item.rows.count == 2, let lon = Double(item.rows[0].text), let lat = Double(item.rows[1].text) else { return nil }
                    return BusCoordinate(latitude: lat, longitude: lon)
                }
                return BusMapRoute.Direction(id: direction["id"].text, name: name(direction), points: points, stopIDs: direction["stops"].rows.map { $0["id"].text }.filter { !$0.isEmpty })
            }
            return BusMapRoute(id: row["id"].text, name: name(row), color: row["color"].text, service: row["service_time"].text, directions: directions)
        }
    }
    public static func vehicles(_ value: WireValue) throws -> [BusVehicle] {
        guard case .array = value else { throw CampusError.invalidResponse("校车车辆位置") }
        var seen = Set<String>()
        return value.rows.compactMap { row in
            let id = row["id"].text
            guard !id.isEmpty, seen.insert(id).inserted, let lat = Double(row["latitude"].text), let lon = Double(row["longitude"].text), let point = BusCoordinate(latitude: lat, longitude: lon) else { return nil }
            let sourceDate = date(row["source_updated_at"].text) ?? Double(row["source_time"].text).flatMap { $0 > 0 && $0.isFinite ? Date(timeIntervalSince1970: $0) : nil }
            let heading = Double(row["heading"].text).flatMap { $0.isFinite && (0...360).contains($0) ? $0 : nil }
            let speed = Double(row["speed"].text).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
            let display = [row["display_name_zh"].text, row["display_name_en"].text, id].first { !$0.isEmpty }!
            return BusVehicle(id: id, name: display, type: row["vehicle_type"].text, coordinate: point,
                routeID: row["route_id"].text, directionID: row["route_direction_id"].text, nextStop: row["next_stop_name"].text,
                speed: speed, heading: heading, updatedAt: sourceDate, receivedAt: date(row["received_at"].text),
                operating: ["true", "1"].contains(row["operating"].text.lowercased()), status: row["operation_status"].text, dataStatus: row["data_status"].text, tripID: row["trip_id"].text, nextStopID: row["current_position"]["next_stop_id"].text)
        }
    }
    private static func name(_ row: WireValue) -> String { [row["name_zh"].text, row["name_en"].text, row["id"].text].first { !$0.isEmpty } ?? "" }
}
extension BusClient {
    public func mapRoutes() async throws -> [BusMapRoute] { try BusMapParser.routes(await http.json("/routes")) }
    public func vehicles(includeInactive: Bool = false) async throws -> [BusVehicle] {
        try BusMapParser.vehicles(await http.json(includeInactive ? "/vehicles/all" : "/vehicles", query: ["_": String(Int(Date.now.timeIntervalSince1970 * 1000))], headers: ["Cache-Control": "no-cache"]))
    }
}
