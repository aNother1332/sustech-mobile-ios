import Foundation

/// When the room catalog is unavailable, the school-wide course schedule can
/// still answer course occupancy. It cannot establish absence of room bookings.
public struct ClassroomCourseDirectory: Sendable {
    public let rooms: [Classroom]
    public let entries: [String: [RoomOccupancy]]

    public static func parse(_ rows: [WireValue]) throws -> ClassroomCourseDirectory {
        var names = Set<String>()
        var entries: [String: [RoomOccupancy]] = [:]
        for (rowIndex, row) in rows.enumerated() {
            let lines = HTMLText.plain(row["pkjgmx"].text).components(separatedBy: .newlines)
            for (lineIndex, line) in lines.enumerated() where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                // The original page renders one <p> per recurring class slot.
                guard let match = HTMLText.captures("^\\s*([0-9,，、\\-单双周 ]+)[,，]星期([一二三四五六日天])[第 ]*([0-9]+)(?:-([0-9]+))?节\\s+(.+?)\\s*$", in: line).first else {
                    // Do not treat a schedule we cannot understand as free.
                    if line.contains("星期"), line.contains("节") { throw CampusError.invalidResponse("全校课表时段") }
                    continue
                }
                let room = match[5].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !room.isEmpty, let first = Int(match[3]), let day = "一二三四五六日".firstIndex(of: Character(match[2] == "天" ? "日" : match[2])) else { throw CampusError.invalidResponse("全校课表教室") }
                var weeks = Set<Int>()
                for bound in HTMLText.captures("([0-9]+)(?:-([0-9]+))?", in: match[1]) {
                    guard let a = Int(bound[1]), let b = Int(bound[2].isEmpty ? bound[1] : bound[2]), a > 0, b >= a, b <= 60 else { throw CampusError.invalidResponse("全校课表周次") }
                    weeks.formUnion(a...b)
                }
                if match[1].contains("单") { weeks = weeks.filter { $0 % 2 == 1 } }
                if match[1].contains("双") { weeks = weeks.filter { $0 % 2 == 0 } }
                guard !weeks.isEmpty else { throw CampusError.invalidResponse("全校课表周次") }
                let weekday = "一二三四五六日".distance(from: "一二三四五六日".startIndex, to: day) + 1
                names.insert(room)
                entries[room, default: []].append(RoomOccupancy(id: "\(rowIndex)-\(lineIndex)", weekday: weekday, period: first, lastPeriod: Int(match[4]) ?? first, weeks: weeks, kind: "课程"))
            }
        }
        guard !names.isEmpty else { throw ServiceFailure("全校课表暂无教室数据") }
        return ClassroomCourseDirectory(rooms: names.sorted().map { Classroom(id: $0, name: $0, capacity: "") }, entries: entries)
    }
}

extension ClassroomClient {
    public func courseDirectory(semester: Semester) async throws -> ClassroomCourseDirectory {
        var rows: [WireValue] = []
        var seen = Set<String>()
        for page in 1...30 {
            let root = try await http.json("/Xsxktz/queryRwxxcxList", form: ["p_xn": semester.year, "p_xq": semester.term, "p_chaxunpylx": "3", "pageNum": String(page), "pageSize": "500"], headers: ["RoleCode": "00"])
            guard case .array = root["rwList"]["list"], let total = root["total"].int, total >= 0 else { throw CampusError.invalidResponse("全校课表") }
            let batch = root["rwList"]["list"].rows
            for row in batch {
                guard !row["id"].text.isEmpty, seen.insert(row["id"].text).inserted else { throw CampusError.invalidResponse("全校课表重复分页") }
            }
            rows += batch
            if rows.count >= total { return try ClassroomCourseDirectory.parse(rows) }
            guard !batch.isEmpty else { throw CampusError.invalidResponse("全校课表分页缺失") }
        }
        throw ServiceFailure("全校课表未读取完整")
    }
}
