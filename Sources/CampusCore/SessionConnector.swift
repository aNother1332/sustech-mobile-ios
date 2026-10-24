import Foundation

/// Exchanges an existing CAS/browser session for a service session, using GET
/// only. This never retains or resubmits a password, nor repeats a business write.
public struct SessionConnector: Sendable {
    public init() {}
    public func connect(_ entry: URL, cookies: [HTTPCookie], finalHost: String? = nil,
                        configuration: URLSessionConfiguration = .ephemeral) async throws -> [HTTPCookie] {
        configuration.timeoutIntervalForRequest = 25
        configuration.urlCache = nil
        for cookie in cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        let session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var next = entry
        var visited = Set<URL>()
        for _ in 0..<16 {
            try Task.checkCancellation()
            guard Self.allowed(next), visited.insert(next).inserted else { throw CASFailure.redirect }
            var request = URLRequest(url: next)
            request.setValue(CASPolicy.userAgent, forHTTPHeaderField: "User-Agent")
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CASFailure.network }
            if (300..<400).contains(response.statusCode) {
                guard let location = response.value(forHTTPHeaderField: "Location"),
                      let target = URL(string: location, relativeTo: next)?.absoluteURL else { throw CASFailure.redirect }
                next = target
                continue
            }
            guard response.statusCode == 200 else { throw CampusError.http(response.statusCode) }
            if next.host == CASPolicy.login.host {
                let html = String(decoding: data, as: UTF8.self)
                if (try? CASPolicy.execution(in: html)) != nil { throw CampusError.signInRequired }
                throw CASFailure.challenge
            }
            guard next.host == (finalHost ?? entry.host) else { throw CASFailure.redirect }
            return configuration.httpCookieStorage?.cookies ?? []
        }
        throw CASFailure.redirect
    }
    public static func allowed(_ url: URL) -> Bool {
        let host = url.host?.lowercased() ?? ""
        return url.scheme == "https" && url.user == nil && url.password == nil
            && (url.port == nil || url.port == 443)
            && (host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn"))
    }
}
