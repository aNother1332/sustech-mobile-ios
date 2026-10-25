import Foundation

/// Silent CAS-to-Primo exchange. Only the provider's fixed ticket endpoint may receive a ticket.
public struct PrimoAuthentication: Sendable {
    public init() {}
    public static func allowed(_ url: URL) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
            && ["cas.sustech.edu.cn", "sustc.primo.exlibrisgroup.com.cn"].contains(url.host?.lowercased() ?? "")
    }
    public func connect(cookies: [HTTPCookie], configuration: URLSessionConfiguration = .ephemeral) async throws -> (String, [HTTPCookie]) {
        configuration.timeoutIntervalForRequest = 20; configuration.timeoutIntervalForResource = 60; configuration.urlCache = nil
        for cookie in cookies { configuration.httpCookieStorage?.setCookie(cookie) }
        let session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
        defer { session.finishTasksAndInvalidate() }
        func walk(_ entry: URL) async throws -> URL {
            var request = URLRequest(url: entry); var seen = Set<String>()
            for _ in 0..<16 {
                try Task.checkCancellation()
                guard let current = request.url, Self.allowed(current), seen.insert((request.httpMethod ?? "GET") + current.absoluteString).inserted else { throw CASFailure.redirect }
                if current.host == LibraryClient.origin.host, URLComponents(url: current, resolvingAgainstBaseURL: false)?.queryItems?.contains(where: { $0.name == "loginId" }) == true { return current }
                request.setValue(CASPolicy.userAgent, forHTTPHeaderField: "User-Agent")
                let (data, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse else { throw CampusError.invalidResponse("图书馆认证") }
                if (300..<400).contains(response.statusCode) {
                    guard let location = response.value(forHTTPHeaderField: "Location"), let next = URL(string: location, relativeTo: current)?.absoluteURL, Self.allowed(next) else { throw CASFailure.redirect }
                    request = URLRequest(url: next); continue
                }
                guard response.statusCode == 200 else { throw CampusError.http(response.statusCode) }
                if current.host == CASPolicy.login.host { throw CampusError.signInRequired }
                let html = String(decoding: data, as: UTF8.self)
                let tickets = HTMLText.captures("(?is)<input\\b[^>]*>", in: html).compactMap { row -> String? in let fields = HTMLText.attributes(row[0]); return fields["name"] == "ticket" ? fields["value"] : nil }
                if tickets.count == 1, let ticket = tickets.first, !ticket.isEmpty {
                    request = URLRequest(url: LibraryClient.origin.appendingPathComponent("primaws/pdsHandleLogin")); request.httpMethod = "POST"
                    request.httpBody = CampusHTTPClient.formBody(["ticket": ticket, "update": "Apply"]); request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type"); continue
                }
                return current
            }
            throw CASFailure.redirect
        }
        var cas = URLComponents(url: CASPolicy.login, resolvingAgainstBaseURL: false)!
        cas.queryItems = [URLQueryItem(name: "service", value: "https://sustc.primo.exlibrisgroup.com.cn/infra/casRedirect?ctx=/primaws")]
        _ = try await walk(cas.url!)
        var parts = URLComponents(string: "https://sustc.primo.exlibrisgroup.com.cn/primaws/suprimaExtLogin")!
        parts.queryItems = [URLQueryItem(name: "institution", value: "86SUSTC_INST"), URLQueryItem(name: "lang", value: "zh-CN"), URLQueryItem(name: "target-url", value: "https://sustc.primo.exlibrisgroup.com.cn/discovery/account?vid=86SUSTC_INST:86SUSTC&section=loans&lang=zh-CN&fromLogin=true"), URLQueryItem(name: "authenticationProfile", value: "CAS2"), URLQueryItem(name: "idpCode", value: "CAS2"), URLQueryItem(name: "auth", value: "CAS"), URLQueryItem(name: "view", value: LibraryClient.view), URLQueryItem(name: "isSilent", value: "false")]
        let landing = try await walk(parts.url!)
        guard let id = URLComponents(url: landing, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "loginId" })?.value,
              id.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil else { throw CampusError.signInRequired }
        var mint = URLComponents(url: LibraryClient.origin.appendingPathComponent("primaws/rest/pub/loginJwtCache/" + id), resolvingAgainstBaseURL: false)!
        mint.queryItems = [URLQueryItem(name: "vid", value: LibraryClient.view)]
        let (data, response) = try await session.data(from: mint.url!)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw CampusError.signInRequired }
        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n"))
        guard token.hasPrefix("eyJ"), !token.contains("\r"), !token.contains("\n") else { throw CampusError.signInRequired }
        return (token, configuration.httpCookieStorage?.cookies ?? [])
    }
}
