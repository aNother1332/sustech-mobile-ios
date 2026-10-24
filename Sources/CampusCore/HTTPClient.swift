import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Stateless delegate: no redirect can carry school credentials to a new origin.
final class RedirectBlocker: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask,
                    willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest,
                    completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

public struct CampusHTTPClient: Sendable {
    private let session: URLSession
    public let origin: URL

    public init(origin: URL, cookies: [HTTPCookie] = [], configuration: URLSessionConfiguration = .ephemeral) {
        self.origin = origin
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        for cookie in cookies {
            configuration.httpCookieStorage?.setCookie(cookie)
        }
        session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    public func cookies() -> [HTTPCookie] {
        session.configuration.httpCookieStorage?.cookies ?? []
    }

    /// Download to a temporary file, checking redirects one at a time. The caller
    /// owns deletion/moving. HTML login responses never become offline documents.
    public func download(path: String) async throws -> URL {
        var next = try Self.resolve(path: path, origin: origin)
        var visited = Set<URL>()
        for _ in 0..<6 {
            guard visited.insert(next).inserted else { throw CampusError.invalidResponse("文件下载跳转") }
            var request = URLRequest(url: next)
            request.setValue(CASPolicy.userAgent, forHTTPHeaderField: "User-Agent")
            request.setValue(origin.absoluteString, forHTTPHeaderField: "Referer")
            let (temporary, response) = try await session.download(for: request)
            guard let response = response as? HTTPURLResponse else {
                try? FileManager.default.removeItem(at: temporary)
                throw CampusError.invalidResponse("文件下载")
            }
            do {
                if (300..<400).contains(response.statusCode) {
                    guard let location = response.value(forHTTPHeaderField: "Location"),
                          let target = URL(string: location, relativeTo: next)?.absoluteURL,
                          target.scheme == origin.scheme, target.host == origin.host,
                          target.port == origin.port, target.user == nil, target.password == nil else { throw CampusError.unsafeURL }
                    try? FileManager.default.removeItem(at: temporary)
                    next = target
                    continue
                }
                let file = try FileHandle(forReadingFrom: temporary)
                let prefix = try file.read(upToCount: 512) ?? Data()
                try file.close()
                try Self.validate(status: response.statusCode, data: prefix)
                let size = (try FileManager.default.attributesOfItem(atPath: temporary.path)[.size] as? NSNumber)?.int64Value ?? 0
                guard size > 0, size <= 200 * 1024 * 1024 else { throw CampusError.invalidResponse("文件大小（单文件上限 200 MB）") }
                let type = response.mimeType?.lowercased() ?? ""
                guard !type.contains("html"), !type.contains("json") else { throw CampusError.unexpectedHTML }
                try Task.checkCancellation()
                return temporary
            } catch {
                try? FileManager.default.removeItem(at: temporary)
                throw error
            }
        }
        throw CampusError.invalidResponse("文件下载跳转")
    }

    public func data(path: String, form: [String: String]? = nil, json: Data? = nil) async throws -> Data {
        let url = try Self.resolve(path: path, origin: origin)
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue(origin.absoluteString, forHTTPHeaderField: "Referer")
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15",
                         forHTTPHeaderField: "User-Agent")
        if let form {
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = Self.formBody(form)
        } else if let json {
            request.httpMethod = "POST"
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.httpBody = json
        }
        try Task.checkCancellation()
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse else {
            throw CampusError.invalidResponse("学校服务")
        }
        try Self.validate(status: response.statusCode, data: data)
        return data
    }

    public static func resolve(path: String, origin: URL) throws -> URL {
        guard origin.scheme == "https", origin.user == nil, origin.password == nil,
              path.hasPrefix("/"), !path.hasPrefix("//"), !path.contains("\\"),
              let url = URL(string: path, relativeTo: origin)?.absoluteURL,
              url.scheme == origin.scheme, url.host == origin.host, url.port == origin.port,
              url.user == nil, url.password == nil else { throw CampusError.unsafeURL }
        return url
    }

    public static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let body = fields.sorted { $0.key < $1.key }.map { key, value in
            "\(key.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")=\(value.addingPercentEncoding(withAllowedCharacters: allowed) ?? "")"
        }.joined(separator: "&")
        return Data(body.utf8)
    }

    public static func validate(status: Int, data: Data) throws {
        switch status {
        case 300..<400, 401: throw CampusError.signInRequired
        case 403: throw CampusError.accessDenied
        case 429: throw CampusError.rateLimited
        case 200..<300: break
        default: throw CampusError.http(status)
        }
        let prefix = String(decoding: data.prefix(512), as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if prefix.hasPrefix("<") { throw CampusError.unexpectedHTML }
        let text = String(decoding: data, as: UTF8.self)
        if ["请用户重新登录", "无效会话", "用户未登录"].contains(where: { text.contains($0) }) {
            throw CampusError.signInRequired
        }
    }
}
