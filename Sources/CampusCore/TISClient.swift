import Foundation

public enum TISParser {
    public static func semester(_ data: Data) throws -> Semester {
        let row = try object(data, source: "当前学期")
        guard let year = scalar(row["XN"]), !year.isEmpty,
              let term = scalar(row["XQ"]), !term.isEmpty else {
            throw CampusError.invalidResponse("当前学期")
        }
        return Semester(year: year, term: term, name: scalar(row["XNXQ"]) ?? "\(year) · \(term)")
    }

    public static func week(_ data: Data) throws -> Int? {
        let raw = String(decoding: data, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty || raw == "null" { return nil }
        guard let week = Int(raw), (1...60).contains(week) else {
            throw CampusError.invalidResponse("教学周")
        }
        return week
    }

    public static func meetings(_ data: Data) throws -> [CourseMeeting] {
        let rows = try array(data, source: "课表")
        return try rows.enumerated().map { index, row in
            guard let schedule = scalar(row["SKSJ"]), !schedule.isEmpty,
                  let key = scalar(row["KEY"]),
                  let weekdayText = key.split(separator: "_").first,
                  weekdayText.hasPrefix("xq"),
                  let weekday = Int(weekdayText.dropFirst(2)), (1...7).contains(weekday),
                  let first = scalar(row["KSJC"]).flatMap(Int.init),
                  let last = scalar(row["JSJC"]).flatMap(Int.init), first > 0, last >= first else {
                throw CampusError.invalidResponse("课表")
            }
            let lines = schedule.components(separatedBy: .newlines).filter { !$0.isEmpty }
            let task = scalar(row["RWH"]) ?? "course"
            return CourseMeeting(id: "\(task)-\(key)-\(first)-\(index)", name: lines[0],
                                 details: lines.dropFirst().joined(separator: " "), weekday: weekday,
                                 firstPeriod: first, lastPeriod: last)
        }.sorted { ($0.weekday, $0.firstPeriod) < ($1.weekday, $1.firstPeriod) }
    }

    public static func exams(_ data: Data) throws -> [CampusExam] {
        try array(data, source: "考试安排").enumerated().map { index, row in
            guard let course = scalar(row["KCMC"]), !course.isEmpty else {
                throw CampusError.invalidResponse("考试安排")
            }
            let date = scalar(row["KSRQ"]) ?? "待公布"
            let time = scalar(row["KSJTSJ"]) ?? scalar(row["KSSJDMC"]) ?? "时间待公布"
            return CampusExam(id: "\(scalar(row["KCDM"]) ?? course)-\(date)-\(index)", course: course,
                              date: date, time: time,
                              room: [scalar(row["JXLMC"]), scalar(row["JXCDMC"])].compactMap { $0 }.joined(separator: " "),
                              seat: scalar(row["ZWH"]) ?? "")
        }.sorted { $0.date < $1.date }
    }

    private static func object(_ data: Data, source: String) throws -> [String: Any] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let row = object as? [String: Any] else { throw CampusError.invalidResponse(source) }
        return row
    }

    private static func array(_ data: Data, source: String) throws -> [[String: Any]] {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let rows = object as? [[String: Any]] else { throw CampusError.invalidResponse(source) }
        return rows
    }

    private static func scalar(_ value: Any?) -> String? {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return nil
    }
}

public struct TISClient: Sendable {
    private let http: CampusHTTPClient

    public init(http: CampusHTTPClient) { self.http = http }

    public func snapshot() async throws -> TeachingSnapshot {
        let semesterData = try await http.data(path: "/component/querydangqianxnxq", form: [:])
        let semester = try TISParser.semester(semesterData)
        var warnings: [String] = []
        var week: Int?
        var meetings: [CourseMeeting] = []
        var exams: [CampusExam] = []
        do {
            week = try TISParser.week(await http.data(path: "/component/querydangqianzc", form: [:]))
            if let week {
                let data = try await http.data(path: "/xszykb/queryxszykbzhou", form: [
                    "xn": semester.year, "xq": semester.term, "zc": String(week)
                ])
                meetings = try TISParser.meetings(data)
            } else {
                warnings.append("学校未返回当前教学周，暂不推算本周课表。")
            }
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("课表：\(error.localizedDescription)") }
        do {
            exams = try TISParser.exams(await http.data(path: "/component/queryKsxxByXs", json: Data("{}".utf8)))
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("考试：\(error.localizedDescription)") }
        return TeachingSnapshot(semester: semester, week: week, meetings: meetings, exams: exams, warnings: warnings)
    }
}

