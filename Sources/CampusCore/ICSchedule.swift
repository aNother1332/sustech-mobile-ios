import Foundation

public struct ICOccupiedTime: Identifiable, Sendable {
    public let id: String; public let start: Date; public let end: Date
}
public struct ICRoomSchedule: Sendable {
    public let roomID: String; public let day: Date
    public let windows: [(start: Date, end: Date)]
    public let occupied: [ICOccupiedTime]
    public let complete: Bool
    public func canSelect(start: Date, end: Date) -> Bool {
        complete && end > start && windows.contains { $0.start <= start && $0.end >= end } && !occupied.contains { $0.start < end && $0.end > start }
    }
    public static func parse(_ value: WireValue, day: Date) throws -> ICRoomSchedule {
        guard !value["devId"].text.isEmpty else { throw CampusError.invalidResponse("研讨间日程") }
        guard case .array = value["resvInfo"], case .array = value["openTimes"] else {
            return ICRoomSchedule(roomID: value["devId"].text, day: day, windows: [], occupied: [], complete: false)
        }
        var complete = value["onlyView"] != .bool(true)
        let date = CampusClock.format(day)
        let windows = value["openTimes"].rows.compactMap { row -> (start: Date, end: Date)? in
            guard let a = CampusClock.date(date + " " + row["openStartTime"].text, "yyyy-MM-dd HH:mm"), let b = CampusClock.date(date + " " + row["openEndTime"].text, "yyyy-MM-dd HH:mm"), b > a else { return nil }
            return (a, b)
        }
        var occupied: [ICOccupiedTime] = []
        for (index, row) in value["resvInfo"].rows.enumerated() {
            guard let status = row["resvStatus"].int else { complete = false; continue }
            if status & 128 != 0 { continue }
            guard let start = CampusClock.serverDate(row["startTime"]), let end = CampusClock.serverDate(row["endTime"]), end > start else { complete = false; continue }
            occupied.append(ICOccupiedTime(id: String(index), start: start, end: end))
        }
        return ICRoomSchedule(roomID: value["devId"].text, day: day, windows: windows, occupied: occupied, complete: complete && !windows.isEmpty)
    }
}

extension ICClient {
    public func schedules(rooms: [ReservationItem], day: Date) async throws -> [String: ICRoomSchedule] {
        let labs = Set(rooms.map { $0.raw["labId"].text }.filter { !$0.isEmpty })
        let allowed = Set(rooms.map(\.id)); var result: [String: ICRoomSchedule] = [:]
        for lab in labs.sorted() {
            try Task.checkCancellation()
            let response = try await call("/reserve", query: ["sysKind": "1", "resvDates": CampusClock.format(day, "yyyyMMdd"), "labIds": lab, "page": "1", "pageSize": "100"])
            guard case .array = response else { throw CampusError.invalidResponse("研讨间日历") }
            guard response.rows.count < 100 else { throw CampusError.invalidResponse("研讨间日历分页") }
            for row in response.rows where allowed.contains(row["devId"].text) { let value = try ICRoomSchedule.parse(row, day: day); result[value.roomID] = value }
        }
        return result
    }
}
