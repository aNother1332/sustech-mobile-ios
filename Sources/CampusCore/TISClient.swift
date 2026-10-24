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
                                 firstPeriod: first, lastPeriod: last, weeks: try weeks(row["ZC"]))
        }.sorted { ($0.weekday, $0.firstPeriod) < ($1.weekday, $1.firstPeriod) }
    }

    public static func weeks(_ raw: Any?) throws -> [Int]? {
        guard let bitmap = raw as? String, !bitmap.isEmpty else { return nil }
        guard bitmap.count <= 61, bitmap.allSatisfy({ $0 == "0" || $0 == "1" }), bitmap.first == "0" else {
            throw CampusError.invalidResponse("课表周次位图")
        }
        // Fixed upstream: index i is week i; index zero is padding.
        return bitmap.enumerated().compactMap { $0.offset > 0 && $0.element == "1" ? $0.offset : nil }
    }

    public static func periods(_ data: Data) throws -> [PeriodTime] {
        let root = try object(data, source: "上课时刻")
        guard let rows = root["content"] as? [[String: Any]] else { throw CampusError.invalidResponse("上课时刻") }
        return try rows.map { row in
            guard let period = scalar(row["xj"]).flatMap(Int.init), period > 0,
                  let start = scalar(row["kssj"]), let end = scalar(row["jssj"]),
                  start.range(of: "^\\d{1,2}:\\d{2}(:\\d{2})?$", options: .regularExpression) != nil,
                  end.range(of: "^\\d{1,2}:\\d{2}(:\\d{2})?$", options: .regularExpression) != nil else {
                throw CampusError.invalidResponse("上课时刻")
            }
            return PeriodTime(period: period, start: start, end: end)
        }.sorted { $0.period < $1.period }
    }

    public static func grades(_ data: Data, offset: Int = 0) throws -> (records: [GradeRecord], total: Int?) {
        let root = try object(data, source: "成绩")
        guard let content = root["content"] as? [String: Any], let rows = content["list"] as? [[String: Any]] else {
            throw CampusError.invalidResponse("成绩")
        }
        let records = try rows.enumerated().map { index, row -> GradeRecord in
            guard let name = scalar(row["kcmc"]), !name.isEmpty,
                  let creditText = scalar(row["xf"]), let credits = Double(creditText), credits.isFinite, credits >= 0 else {
                throw CampusError.invalidResponse("成绩")
            }
            let code = scalar(row["kcdm"]) ?? ""
            let term = scalar(row["xnxqmc"]) ?? "学期待核对"
            let points = scalar(row["jd"]).flatMap(Double.init).flatMap { $0.isFinite && (0...4).contains($0) ? $0 : nil }
            return GradeRecord(id: "\(code)-\(term)-\(offset + index)", code: code, name: name, term: term,
                credits: credits, display: scalar(row["xscj"]) ?? "", score: scalar(row["zzcj"]) ?? "",
                reportedPoints: points, category: scalar(row["kcxz"]) ?? "")
        }
        return (records, scalar(content["total"] ?? root["total"]).flatMap(Int.init))
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
        var periods: [PeriodTime] = []
        var fullSemester = false
        do {
            week = try TISParser.week(await http.data(path: "/component/querydangqianzc", form: [:]))
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("教学周：\(error.localizedDescription)") }
        do {
            meetings = try TISParser.meetings(await http.data(path: "/xszykb/queryxszykbzong", form: ["xn": semester.year, "xq": semester.term]))
            fullSemester = true
            if meetings.contains(where: { $0.weeks == nil }) { warnings.append("部分全学期课程缺少周次，已单列为周次待核对，不自动安排到每周。") }
        } catch is CancellationError { throw CancellationError() }
        catch {
            warnings.append("全学期课表：\(error.localizedDescription)")
            if let week {
                do {
                let data = try await http.data(path: "/xszykb/queryxszykbzhou", form: [
                    "xn": semester.year, "xq": semester.term, "zc": String(week)
                ])
                meetings = try TISParser.meetings(data)
                } catch is CancellationError { throw CancellationError() }
                catch { warnings.append("本周课表：\(error.localizedDescription)") }
            } else {
                warnings.append("学校未返回当前教学周，暂不推算本周课表。")
            }
        }
        if let week {
            do {
                periods = try TISParser.periods(await http.data(path: "/component/queryKbjg", form: ["xn": semester.year, "xq": semester.term, "zc": String(week)]))
            } catch is CancellationError { throw CancellationError() }
            catch { warnings.append("上课时刻：\(error.localizedDescription)") }
        }
        do {
            exams = try TISParser.exams(await http.data(path: "/component/queryKsxxByXs", json: Data("{}".utf8)))
        } catch is CancellationError { throw CancellationError() }
        catch { warnings.append("考试：\(error.localizedDescription)") }
        return TeachingSnapshot(semester: semester, week: week, meetings: meetings, exams: exams, warnings: warnings,
                                fullSemester: fullSemester, periods: periods)
    }

    public func grades() async throws -> AcademicSnapshot {
        var records: [GradeRecord] = []
        var seen = Set<Data>()
        for page in 1...100 {
            let payload: [String: Any] = ["xn": NSNull(), "xq": NSNull(), "kcmc": NSNull(), "cxbj": "-1", "pylx": "1", "current": page, "pageSize": 100]
            let data = try await http.data(path: "/cjgl/grcjcx/grcjcx", json: JSONSerialization.data(withJSONObject: payload))
            let result = try TISParser.grades(data, offset: records.count)
            if !result.records.isEmpty, !seen.insert(data).inserted { throw CampusError.invalidResponse("成绩分页重复") }
            records.append(contentsOf: result.records)
            if result.records.count < 100 || result.total.map({ records.count >= $0 }) == true {
                if let total = result.total, total > records.count { throw CampusError.invalidResponse("成绩分页不完整") }
                return AcademicSnapshot(records: records)
            }
        }
        throw CampusError.invalidResponse("成绩分页超出限制")
    }
}
