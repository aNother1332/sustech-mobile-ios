import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum CASFailure: Error, LocalizedError, Equatable, Sendable {
    case challenge, rejected, missingForm, redirect, network
    public var errorDescription: String? {
        switch self {
        case .challenge: "学校要求验证码或交互验证，请使用完整网页登录完成。"
        case .rejected: "CAS 未接受本次登录。请核对账号、密码或使用学校页面查看提示；应用不会自动重试。"
        case .missingForm: "学校登录表单已变化或需要交互，请使用学校网页登录。"
        case .redirect: "学校登录跳转不符合预期，已停止传递会话。请使用学校网页登录。"
        case .network: "未能连接学校认证服务，请检查网络后手动重试。"
        }
    }
}

public enum CASService: String, CaseIterable, Sendable {
    case teaching, blackboard
    public var entry: URL {
        switch self {
        case .teaching: URL(string: "https://tis.sustech.edu.cn/cas")!
        case .blackboard: URL(string: "https://bb.sustech.edu.cn/webapps/bb-sso-BBLEARN/index.jsp")!
        }
    }
}

public enum CASPolicy {
    public static let login = URL(string: "https://cas.sustech.edu.cn/cas/login")!
    public static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"

    public static func allowed(_ url: URL, service: CASService) -> Bool {
        url.scheme == "https" && url.user == nil && url.password == nil && (url.port == nil || url.port == 443)
            && [login.host, service.entry.host].contains(url.host?.lowercased())
    }

    public static func execution(in html: String) throws -> String {
        if html.range(of: "name=[\"']g-recaptcha-response[\"']", options: [.regularExpression, .caseInsensitive]) != nil,
           html.range(of: "slideVerify|captchaVerification|su-recaptcha", options: [.regularExpression, .caseInsensitive]) != nil {
            throw CASFailure.challenge
        }
        // Only an active challenge, not an empty/hidden captcha template.
        for tag in HTMLText.captures("(?i)<input\\b[^>]*>", in: html) {
            let attrs = HTMLText.attributes(tag[0])
            let name = (attrs["name"] ?? "").lowercased()
            if ["captcha", "captcharesponse", "verifycode", "validatecode", "otp", "totp"].contains(name),
               attrs["type"]?.lowercased() != "hidden", !tag[0].lowercased().contains("disabled") {
                throw CASFailure.challenge
            }
        }
        for tag in HTMLText.captures("(?i)<input\\b[^>]*>", in: html) {
            let attrs = HTMLText.attributes(tag[0])
            if attrs["name"] == "execution", let value = attrs["value"], !value.isEmpty { return value }
        }
        throw CASFailure.missingForm
    }

    public static func redirect(_ location: String, from: URL, service: CASService) throws -> URL {
        guard let next = URL(string: location, relativeTo: from)?.absoluteURL, allowed(next, service: service) else {
            throw CASFailure.redirect
        }
        return next
    }
}

/// A fresh ephemeral cookie jar belongs to one explicit native sign-in attempt.
/// Passwords are POSTed only to CAS. Every redirect is manually checked and uses GET.
public struct CASClient: Sendable {
    private let session: URLSession
    public init(configuration: URLSessionConfiguration = .ephemeral) {
        configuration.urlCache = nil
        configuration.timeoutIntervalForRequest = 25
        configuration.timeoutIntervalForResource = 60
        session = URLSession(configuration: configuration, delegate: RedirectBlocker(), delegateQueue: nil)
    }

    public func signIn(service: CASService, username: String, password: String) async throws -> [HTTPCookie] {
        guard !username.isEmpty, !password.isEmpty else { throw CASFailure.rejected }
        var components = URLComponents(url: CASPolicy.login, resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "service", value: service.entry.absoluteString)]
        guard let page = components.url else { throw CASFailure.redirect }
        var url = page
        var submitted = false
        var visited = Set<String>()
        for _ in 0..<12 {
            try Task.checkCancellation()
            guard visited.insert(url.absoluteString + (submitted ? "-post" : "-get")).inserted else { throw CASFailure.redirect }
            let (data, response) = try await request(url, service: service)
            if (300..<400).contains(response.statusCode) {
                guard let location = response.value(forHTTPHeaderField: "Location") else { throw CASFailure.redirect }
                url = try CASPolicy.redirect(location, from: url, service: service)
                continue
            }
            guard response.statusCode == 200 else {
                if response.statusCode == 429 { throw CampusError.rateLimited }
                throw CampusError.http(response.statusCode)
            }
            if url.host == service.entry.host { return session.configuration.httpCookieStorage?.cookies ?? [] }
            guard url.host == CASPolicy.login.host, url.path == CASPolicy.login.path else { throw CASFailure.redirect }
            guard !submitted else { throw CASFailure.rejected }
            let html = String(decoding: data, as: UTF8.self)
            let execution = try CASPolicy.execution(in: html)
            let (body, result) = try await request(page, service: service, form: [
                "username": username, "password": password, "execution": execution, "_eventId": "submit"
            ])
            submitted = true
            if result.statusCode == 429 { throw CampusError.rateLimited }
            guard (300..<400).contains(result.statusCode),
                  let location = result.value(forHTTPHeaderField: "Location") else {
                if result.statusCode == 200 {
                    _ = try CASPolicy.execution(in: String(decoding: body, as: UTF8.self))
                    throw CASFailure.rejected
                }
                throw CampusError.http(result.statusCode)
            }
            url = try CASPolicy.redirect(location, from: page, service: service)
        }
        throw CASFailure.redirect
    }

    private func request(_ url: URL, service: CASService, form: [String: String]? = nil) async throws -> (Data, HTTPURLResponse) {
        guard CASPolicy.allowed(url, service: service), form == nil || (url.host == CASPolicy.login.host && url.path == CASPolicy.login.path) else {
            throw CASFailure.redirect
        }
        var request = URLRequest(url: url)
        request.setValue(CASPolicy.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        if let form {
            request.httpMethod = "POST"
            request.httpBody = CampusHTTPClient.formBody(form)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue("https://cas.sustech.edu.cn", forHTTPHeaderField: "Origin")
            request.setValue(url.absoluteString, forHTTPHeaderField: "Referer")
        }
        do {
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw CASFailure.network }
            return (data, response)
        } catch is CancellationError { throw CancellationError() }
        catch let error as CASFailure { throw error }
        catch { if Task.isCancelled { throw CancellationError() }; throw CASFailure.network }
    }
}
