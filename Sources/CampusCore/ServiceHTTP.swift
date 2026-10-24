import Foundation

public enum WireValue: Codable, Sendable, Equatable {
    case object([String: WireValue]), array([WireValue]), string(String), number(Double), bool(Bool), null
    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let value = try? c.decode(Bool.self) { self = .bool(value) }
        else if let value = try? c.decode(Double.self) { self = .number(value) }
        else if let value = try? c.decode(String.self) { self = .string(value) }
        else if let value = try? c.decode([String: WireValue].self) { self = .object(value) }
        else { self = .array(try c.decode([WireValue].self)) }
    }
    public func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .object(let v): try c.encode(v)
        case .array(let v): try c.encode(v)
        case .string(let v): try c.encode(v)
        case .number(let v): try c.encode(v)
        case .bool(let v): try c.encode(v)
        case .null: try c.encodeNil()
        }
    }
    public subscript(_ key: String) -> WireValue { fields[key] ?? .null }
    public var fields: [String: WireValue] { if case .object(let v) = self { v } else { [:] } }
    public var rows: [WireValue] { if case .array(let v) = self { v } else { [] } }
    public var text: String {
        switch self {
        case .string(let v): v
        case .number(let v): v.rounded() == v ? String(format: "%.0f", v) : String(v)
        case .bool(let v): v ? "true" : "false"
        default: ""
        }
    }
    public var int: Int? { Int(text) }
    public func replacing(_ values: [String: WireValue]) -> WireValue { .object(fields.merging(values) { _, new in new }) }
}

public struct ServiceFailure: Error, LocalizedError, Sendable {
    public let message: String
    public init(_ message: String) { self.message = message }
    public var errorDescription: String? { message }
}

public struct ServiceHTTP: Sendable {
    public let origin: URL
    private let session: URLSession
    public init(origin: URL, cookies: [HTTPCookie] = [], configuration: URLSessionConfiguration = .ephemeral) {
        self.origin = origin
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 120
        configuration.urlCache = nil
        for cookie in cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }
    public func cookies() -> [HTTPCookie] { session.configuration.httpCookieStorage?.cookies ?? [] }
    public func data(_ path: String, query: [String: String] = [:], form: [String: String]? = nil,
                     json: WireValue? = nil, method: String = "GET", body: Data? = nil,
                     contentType: String? = nil, headers: [String: String] = [:]) async throws -> Data {
        let target = try CampusHTTPClient.resolve(path: path, origin: origin)
        var parts = URLComponents(url: target, resolvingAgainstBaseURL: false)!
        parts.queryItems = (parts.queryItems ?? []) + query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        guard let url = parts.url else { throw CampusError.unsafeURL }
        var request = URLRequest(url: url)
        request.httpMethod = (form != nil || json != nil || body != nil) ? "POST" : method
        request.setValue(CASPolicy.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(origin.absoluteString, forHTTPHeaderField: "Referer")
        for (key, value) in headers { request.setValue(value, forHTTPHeaderField: key) }
        if let form { request.httpBody = CampusHTTPClient.formBody(form); request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
        if let json { request.httpBody = try JSONEncoder().encode(json); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let body { request.httpBody = body; request.setValue(contentType, forHTTPHeaderField: "Content-Type") }
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw CampusError.invalidResponse("校园服务") }
        if response.statusCode == 401 || (300..<400).contains(response.statusCode) { throw CampusError.signInRequired }
        if response.statusCode == 403 { throw CampusError.accessDenied }
        if response.statusCode == 429 { throw CampusError.rateLimited }
        guard (200..<300).contains(response.statusCode) else { throw CampusError.http(response.statusCode) }
        return data
    }
    public func json(_ path: String, query: [String: String] = [:], form: [String: String]? = nil,
                     payload: WireValue? = nil, method: String = "GET", headers: [String: String] = [:]) async throws -> WireValue {
        let data = try await data(path, query: query, form: form, json: payload, method: method, headers: headers)
        guard let result = try? JSONDecoder().decode(WireValue.self, from: data) else {
            let html = String(decoding: data.prefix(8192), as: UTF8.self)
            if html.contains("execution") || html.contains("cas/login") { throw CampusError.signInRequired }
            throw CampusError.invalidResponse("校园服务")
        }
        return result
    }
}
