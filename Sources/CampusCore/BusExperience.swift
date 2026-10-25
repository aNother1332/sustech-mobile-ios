import Foundation

public struct BusDeparture: Identifiable, Sendable {
    public enum Phase: Equatable, Sendable { case past, recent, future }
    public let id: String
    public let time: String
    public let minute: Int
    public func phase(at date: Date) -> Phase {
        let now = AcademicTerm.calendar.component(.hour, from: date) * 60 + AcademicTerm.calendar.component(.minute, from: date)
        let elapsed = now - minute
        return elapsed < 0 ? .future : elapsed <= 20 ? .recent : .past
    }
}
public struct BusScheduleGroup: Identifiable, Sendable {
    public let id: String; public let routeID: String; public let directionID: String
    public let route: String; public let direction: String; public let dayType: String
    public let times: [BusDeparture]
}
public enum BusExperience {
    public static func schedules(_ value: WireValue) throws -> [BusScheduleGroup] {
        guard case .array = value else { throw CampusError.invalidResponse("校车时刻表") }
        return value.rows.enumerated().compactMap { index, row in
            guard !row["route_id"].text.isEmpty else { return nil }
            let id = "\(row["route_direction_id"].text)|\(row["day_type"].text)|\(row["service_type"].text)|\(index)"
            let times = row["departure_times"].rows.enumerated().compactMap { offset, item -> BusDeparture? in
                let parts = item.text.split(separator: ":").compactMap { Int($0) }
                guard parts.count == 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { return nil }
                return BusDeparture(id: id + "|\(offset)", time: item.text, minute: parts[0] * 60 + parts[1])
            }.sorted { $0.minute < $1.minute }
            return BusScheduleGroup(id: id, routeID: row["route_id"].text, directionID: row["route_direction_id"].text,
                route: row["route_name_zh"].text, direction: row["direction_name_zh"].text, dayType: row["day_type"].text, times: times)
        }
    }
    /// Preserve every measured geometry point. Round joins instead of fitting a spline
    /// that could cut corners, cross buildings or invent roads.
    public static func matchedArrival(vehicle: BusVehicle, arrivals: [BusArrival]) -> BusArrival? {
        guard !vehicle.tripID.isEmpty else { return nil }
        return arrivals.first { $0.tripID == vehicle.tripID && $0.directionID == vehicle.directionID }
    }
}
extension BusClient {
    public func schedules() async throws -> [BusScheduleGroup] { try BusExperience.schedules(await http.json("/schedules")) }
    public func directArrivals(_ stop: String) async throws -> [BusArrival] {
        guard stop.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw CampusError.unsafeURL }
        return try Self.parseArrivals(await http.json("/arrivals/" + stop))
    }
    public static func parseArrivals(_ value: WireValue) throws -> [BusArrival] {
        guard case .array = value["arrivals"] else { throw CampusError.invalidResponse("校车到站") }
        return value["arrivals"].rows.enumerated().map { index, row in
            BusArrival(id: String(index), route: row["route_name_zh"].text, direction: row["direction_name_zh"].text,
                minutes: row["eta_minutes"].int, planned: row["planned_arrival_at"].text,
                reason: row["unavailable_reason"].text, source: row["source"].text,
                routeID: row["route_id"].text, directionID: row["route_direction_id"].text, tripID: row["trip_id"].text)
        }
    }
}
