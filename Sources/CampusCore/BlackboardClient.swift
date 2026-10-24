import Foundation

public enum BlackboardParser {
    public struct User: Decodable, Sendable { public let id: String }
    public struct Enrollment: Decodable, Sendable {
        public let courseId: String
        public let course: Course?
        public struct Course: Decodable, Sendable { public let name: String }
    }
    public struct Column: Decodable, Sendable {
        public let id: String
        public let name: String
        public let grading: Grading?
        public struct Grading: Decodable, Sendable { public let due: String? }
    }
    public struct Page<Row: Decodable & Sendable>: Decodable, Sendable {
        public let results: [Row]
        public let paging: Paging?
        public struct Paging: Decodable, Sendable { public let nextPage: String? }
    }

    public static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do { return try JSONDecoder().decode(type, from: data) }
        catch { throw CampusError.invalidResponse("Blackboard") }
    }

    public static func deadline(_ column: Column, course: BlackboardCourse) -> LearningDeadline? {
        guard let raw = column.grading?.due, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractional.date(from: raw) ?? ISO8601DateFormatter().date(from: raw)
        return LearningDeadline(id: "\(course.id)-\(column.id)", course: course.name,
                                title: column.name, due: date, rawDue: raw, submission: .unknown)
    }
}

public struct BlackboardClient: Sendable {
    private let http: CampusHTTPClient

    public init(http: CampusHTTPClient) { self.http = http }

    public func snapshot() async throws -> BlackboardSnapshot {
        let userData = try await http.data(path: "/learn/api/public/v1/users/me")
        let user = try BlackboardParser.decode(BlackboardParser.User.self, from: userData)
        let uid = try identifier(user.id)
        let enrollments: [BlackboardParser.Enrollment] = try await pages(
            path: "/learn/api/public/v1/users/\(uid)/courses?expand=course&limit=100"
        )
        var seen = Set<String>()
        let courses = enrollments.compactMap { row -> BlackboardCourse? in
            guard seen.insert(row.courseId).inserted else { return nil }
            return BlackboardCourse(id: row.courseId, name: row.course?.name ?? row.courseId)
        }
        var deadlines: [LearningDeadline] = []
        var warnings: [String] = []
        // Serial requests deliberately avoid a login/request burst against school services.
        for course in courses {
            try Task.checkCancellation()
            do {
                let id = try identifier(course.id)
                let columns: [BlackboardParser.Column] = try await pages(
                    path: "/learn/api/public/v1/courses/\(id)/gradebook/columns?limit=100"
                )
                deadlines.append(contentsOf: columns.compactMap { BlackboardParser.deadline($0, course: course) })
            } catch is CancellationError { throw CancellationError() }
            catch { warnings.append("\(course.name)：\(error.localizedDescription)") }
        }
        if deadlines.contains(where: { $0.due == nil }) {
            warnings.append("部分截止时间无法解析，已保留学校返回的原文。")
        }
        return BlackboardSnapshot(courses: courses, deadlines: deadlines.sorted {
            ($0.due ?? .distantFuture) < ($1.due ?? .distantFuture)
        }, warnings: warnings)
    }

    private func pages<Row: Decodable & Sendable>(path: String) async throws -> [Row] {
        var path: String? = path
        var visited = Set<String>()
        var rows: [Row] = []
        while let next = path {
            guard visited.count < 100, visited.insert(next).inserted else {
                throw CampusError.invalidResponse("Blackboard 分页")
            }
            let data = try await http.data(path: next)
            let page = try BlackboardParser.decode(BlackboardParser.Page<Row>.self, from: data)
            rows.append(contentsOf: page.results)
            path = try page.paging?.nextPage.map { try pagePath($0) }
        }
        return rows
    }

    private func pagePath(_ value: String) throws -> String {
        if value.hasPrefix("/") {
            _ = try CampusHTTPClient.resolve(path: value, origin: http.origin)
            return value
        }
        guard let components = URLComponents(string: value),
              components.scheme == "https", components.host == http.origin.host,
              components.port == http.origin.port, components.user == nil, components.password == nil else {
            throw CampusError.unsafeURL
        }
        return components.percentEncodedPath + (components.percentEncodedQuery.map { "?" + $0 } ?? "")
    }

    private func identifier(_ value: String) throws -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard !value.isEmpty, value.unicodeScalars.allSatisfy({ allowed.contains($0) }) else {
            throw CampusError.invalidResponse("Blackboard 标识符")
        }
        return value
    }
}
