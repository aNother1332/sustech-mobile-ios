import Foundation

public struct FacultyContact: Codable, Sendable {
    public var email: String?
    public var office: String?
    public var profile: URL?
    public var fetched: Date
    public init(email: String? = nil, office: String? = nil, profile: URL? = nil, fetched: Date = .now) { self.email = email; self.office = office; self.profile = profile; self.fetched = fetched }
}
public enum FacultyContactParser {
    public static func official(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443) && (host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn"))
    }
    public static func parse(_ html: String, base: URL) -> FacultyContact {
        let sidebar = HTMLText.captures("(?is)<div[^>]*class=[\"'][^\"']*message-left[^\"']*[\"'][^>]*>(.*?)<div[^>]*class=[\"'][^\"']*message-right", in: html).first?[1]
        let body: String
        if let start = html.range(of: "(?i)<div[^>]*class=[\"']introduce[\"']", options: .regularExpression) { body = String(html[start.lowerBound...]) } else { body = html }
        let scoped = sidebar ?? body
        let iconMail = HTMLText.captures("(?is)fa-envelope[^>]*>.*?<span[^>]*>(.*?)</span>", in: scoped).first?[1]
        let mailto = HTMLText.captures("(?i)href=[\"']mailto:([^?\"']+)", in: scoped).first?[1]
        let email = [iconMail, mailto].compactMap { $0 }.compactMap { validEmail(HTMLText.plain($0)) }.first
        let iconOffice = (HTMLText.captures("(?is)fa-(?:map-marker|location-dot|building)[^>]*>.*?<span[^>]*>(.*?)</span>", in: scoped).first?[1]).map(HTMLText.plain)
        let plain = HTMLText.plain(body)
        let labeled = HTMLText.captures("(?i)(?:办公室(?:地址|地点)?|办公(?:地址|地点|位置)|Office(?:\\s+(?:Address|Location))?)\\s*[:：]\\s*([^\\n\\r]{2,160})", in: plain).first?[1]
        let office = [iconOffice, labeled].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        let profile = HTMLText.captures("(?is)<a\\b[^>]*href=[\"']([^\"']+)[\"'][^>]*>\\s*(?:个人主页|Personal\\s+(?:Homepage|Website))\\s*</a>", in: scoped).compactMap { URL(string: HTMLText.decoded($0[1]).trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: base)?.absoluteURL }.first(where: official)
        return FacultyContact(email: email, office: office, profile: profile)
    }
    private static func validEmail(_ text: String) -> String? {
        guard text.range(of: "^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$", options: .regularExpression) != nil else { return nil }; return text
    }
}

public struct FacultyContactClient: Sendable {
    public init() {}
    public func contact(at url: URL) async throws -> FacultyContact {
        guard FacultyContactParser.official(url), url.host == "www.sustech.edu.cn", url.path.hasPrefix("/zh/faculties/") else { throw CampusError.unsafeURL }
        let configuration = URLSessionConfiguration.ephemeral; configuration.timeoutIntervalForRequest = 15; configuration.urlCache = nil
        let session = URLSession(configuration: configuration, delegate: FacultyRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        let first = try await read(url, session: session)
        var result = FacultyContactParser.parse(first, base: url)
        if result.office == nil, let profile = result.profile {
            // Follow one official personal page, not an unbounded crawl of biographies or external sites.
            if let page = try? await read(profile, session: session) {
                let extra = FacultyContactParser.parse(page, base: profile)
                result.office = extra.office; result.email = result.email ?? extra.email
            }
        }
        return result
    }
    private func read(_ url: URL, session: URLSession) async throws -> String {
        var request = URLRequest(url: url); request.setValue("SUSTechMobile/0.6 (public faculty details)", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse, (200..<300).contains(response.statusCode), let final = response.url, FacultyContactParser.official(final), data.count < 5_000_000 else { throw CampusError.invalidResponse("教师官方资料") }
        guard let text = String(data: data, encoding: .utf8) else { throw CampusError.invalidResponse("教师页面编码") }; return text
    }
}
private final class FacultyRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        guard let url = request.url, FacultyContactParser.official(url) else { return nil }; return request
    }
}
