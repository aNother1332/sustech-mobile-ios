import Foundation

/// Exchanges an existing CAS/browser session for a service session, using GET
/// only. This never retains or resubmits a password, nor repeats a business write.
public struct SessionConnector: Sendable {
    public init() {}
    public func connect(_ entry: URL, cookies: [HTTPCookie], finalHost: String? = nil,
                        configuration: URLSessionConfiguration = .ephemeral) async throws -> [HTTPCookie] {
        try await exchange(entry, cookies: cookies, finalHost: finalHost, configuration: configuration).updatedCookies
    }
    public struct Exchange: Sendable {
        public let cookies: [HTTPCookie]
        public let updatedCookies: [HTTPCookie]
        public let finalURL: URL
        public let body: Data
    }
    public func exchange(_ entry: URL, cookies: [HTTPCookie], finalHost: String? = nil,
                         configuration: URLSessionConfiguration = .ephemeral) async throws -> Exchange {
        configuration.timeoutIntervalForRequest = 25
        configuration.urlCache = nil
        for cookie in cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        let session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        var next = entry
        var visited: [URL: Int] = [:]
        for _ in 0..<16 {
            try Task.checkCancellation()
            guard Self.allowed(next), visited[next, default: 0] < 3 else { throw CASFailure.redirect }
            visited[next, default: 0] += 1
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
            if response.statusCode == 429 { throw CampusError.rateLimited }
            guard response.statusCode == 200 else { throw CampusError.http(response.statusCode) }
            if next.host == CASPolicy.login.host {
                let html = String(decoding: data, as: UTF8.self)
                if (try? CASPolicy.execution(in: html)) != nil { throw CampusError.signInRequired }
                throw CASFailure.challenge
            }
            guard next.host == (finalHost ?? entry.host) else { throw CASFailure.redirect }
            let current = configuration.httpCookieStorage?.cookies ?? []
            return Exchange(cookies: current, updatedCookies: CookieChanges.changed(from: cookies, to: current), finalURL: next, body: data)
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
