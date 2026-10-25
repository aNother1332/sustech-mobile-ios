import Foundation

/// Protocol observed in booking.sustech.edu.cn's public Vue client (2026-10-25).
/// Its meeting_manager_token is independent of the reservation / WeCom token.
public struct CollegeBookingClient: Sendable {
    public let http: ServiceHTTP
    public let token: String
    public init(http: ServiceHTTP, token: String) { self.http = http; self.token = token }
    public func call(_ endpoint: String, type: Int, data: WireValue) async throws -> WireValue {
        guard !token.isEmpty else { throw CampusError.signInRequired }
        let result = try await http.json("/api/SystemApi/" + endpoint,
            payload: .object(["MessageType": .integer(Int64(type)), "MessageID": .string(UUID().uuidString), "Data": data]),
            headers: ["Authorization": token, "Language": "zh"])
        if ["5001", "5002", "5003"].contains(result["ErrorCode"].text) { throw CampusError.signInRequired }
        guard result["IsSuccess"] == .bool(true) || result["IsSuccess"].text == "1" else {
            throw ServiceFailure(result["Message"].text.isEmpty ? "书院场地平台未确认查询成功。" : result["Message"].text)
        }
        return result["Data"]
    }
    public static func rows(_ value: WireValue) throws -> [WireValue] {
        if case .array = value { return value.rows }
        if case .array = value["rows"] { return value["rows"].rows }
        throw CampusError.invalidResponse("书院场地目录")
    }
    public func rooms() async throws -> [ReservationItem] {
        try Self.rows(await call("GetMeetingRoomAll", type: 5001, data: .object([:]))).compactMap { row in
            guard !row["MeetingRoomID"].text.isEmpty else { return nil }
            return ReservationItem(id: row["MeetingRoomID"].text, title: row["MeetingRoomName"].text,
                detail: [row["CollegeName"].text, row["MeetingRoomLocal"].text].filter { !$0.isEmpty }.joined(separator: " · "), raw: row)
        }
    }
    public func schedule(room: String, day: Date) async throws -> [ReservationItem] {
        let value = try await call("GetMeetingByMeetingRoomList", type: 5001,
            data: .object(["meetingroomid": .string(room), "currentdate": .string(CampusClock.format(day, "yyyy-MM-dd'T'HH:mm:ss'+08:00'"))]))
        return try Self.rows(value).enumerated().map { index, row in
            ReservationItem(id: row["MeetingID"].text.isEmpty ? String(index) : row["MeetingID"].text,
                title: row["Topical"].text.isEmpty ? "学校返回的安排" : row["Topical"].text,
                detail: row["StartDateTime"].text + " → " + row["EndDateTime"].text, raw: row)
        }
    }
}
