import Foundation

public struct ICOccupiedTime: Identifiable, Sendable {
    public let id: String; public let start: Date; public let end: Date
    public var blocksBooking = true
}
public struct ICRoomSchedule: Sendable {
    public let roomID: String; public let day: Date
    public let windows: [(start: Date, end: Date)]
    public let occupied: [ICOccupiedTime]
    public let complete: Bool
    public var minLeadMinutes: Int? = nil
    public var maxAdvanceMinutes: Int? = nil
    public func retainingPast(from previous: ICRoomSchedule?, now: Date = .now) -> ICRoomSchedule {
        guard let previous, previous.roomID == roomID, CampusClock.format(previous.day) == CampusClock.format(day) else { return self }
        let retained = previous.occupied.filter { old in old.end <= now && !occupied.contains { $0.start == old.start && $0.end == old.end } }
        return ICRoomSchedule(roomID: roomID, day: day, windows: windows, occupied: (occupied + retained).sorted { $0.start < $1.start }, complete: complete, minLeadMinutes: minLeadMinutes, maxAdvanceMinutes: maxAdvanceMinutes)
    }
    public func canSelect(start: Date, end: Date, now: Date? = nil) -> Bool {
        if let now {
            guard start > now else { return false }
            if let minutes = minLeadMinutes, minutes > 0, start < now.addingTimeInterval(Double(minutes) * 60) { return false }
            if let minutes = maxAdvanceMinutes, minutes > 0, start > now.addingTimeInterval(Double(minutes) * 60) { return false }
        }
        return complete && end > start && windows.contains { $0.start <= start && $0.end >= end } && !occupied.contains { $0.blocksBooking && $0.start < end && $0.end > start }
    }
    public static func parse(_ value: WireValue, day: Date) throws -> ICRoomSchedule {
        guard !value["devId"].text.isEmpty else { throw CampusError.invalidResponse("研讨间日程") }
        guard case .array = value["resvInfo"], case .array = value["openTimes"] else {
            return ICRoomSchedule(roomID: value["devId"].text, day: day, windows: [], occupied: [], complete: false)
        }
        var complete = value["onlyView"] != .bool(true)
        let date = CampusClock.format(day)
        let windows = value["openTimes"].rows.compactMap { row -> (start: Date, end: Date)? in
            let base = AcademicTerm.calendar.startOfDay(for: day)
            if row["openLimit"].int == 0 { return (base, AcademicTerm.calendar.date(byAdding: .day, value: 1, to: base)!) }
            func time(_ text: String) -> Date? {
                if text == "24:00" || text == "24:00:00" { return AcademicTerm.calendar.date(byAdding: .day, value: 1, to: base) }
                return CampusClock.date(date + " " + text, text.count > 5 ? "yyyy-MM-dd HH:mm:ss" : "yyyy-MM-dd HH:mm")
            }
            guard let a = time(row["openStartTime"].text), let b = time(row["openEndTime"].text), b > a else { return nil }
            return (a, b)
        }
        var occupied: [ICOccupiedTime] = []
        for row in value["resvInfo"].rows {
            guard let status = row["resvStatus"].int else { complete = false; continue }
            guard let start = CampusClock.serverDate(row["startTime"]), let end = CampusClock.serverDate(row["endTime"]), end > start else { complete = false; continue }
            occupied.append(ICOccupiedTime(id: row["uuid"].text.isEmpty ? "\(start.timeIntervalSince1970)-\(end.timeIntervalSince1970)" : row["uuid"].text, start: start, end: end, blocksBooking: status & 128 == 0))
        }
        return ICRoomSchedule(roomID: value["devId"].text, day: day, windows: windows, occupied: occupied, complete: complete && !windows.isEmpty, minLeadMinutes: value["resvRule"]["latestResvTime"].int, maxAdvanceMinutes: value["resvRule"]["earliestResvTime"].int)
    }
}

extension ICClient {
    public func schedules(rooms: [ReservationItem], day: Date) async throws -> [String: ICRoomSchedule] {
        let labs = Set(rooms.map { $0.raw["labId"].text }.filter { !$0.isEmpty })
        let allowed = Set(rooms.map(\.id)); var result: [String: ICRoomSchedule] = [:]
        for (index, lab) in labs.sorted().enumerated() {
            try Task.checkCancellation()
            if index > 0 { try await Task.sleep(for: .milliseconds(1100)) }
            let response = try await call("/reserve", query: ["sysKind": "1", "resvDates": CampusClock.format(day, "yyyyMMdd"), "labIds": lab, "page": "1", "pageSize": "100"])
            guard case .array = response else { throw CampusError.invalidResponse("研讨间日历") }
            guard response.rows.count < 100 else { throw CampusError.invalidResponse("研讨间日历分页") }
            for row in response.rows where allowed.contains(row["devId"].text) { let value = try ICRoomSchedule.parse(row, day: day); result[value.roomID] = value }
        }
        return result
    }
}
