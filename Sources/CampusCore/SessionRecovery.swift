import Foundation

public struct RecoveredSession: Sendable {
    public let cookies: [HTTPCookie]
    public let headers: [String: String]
    public init(cookies: [HTTPCookie], headers: [String: String] = [:]) {
        self.cookies = cookies; self.headers = headers
    }
}
public typealias SessionRecovery = @Sendable () async throws -> RecoveredSession

/// Authentication renewal may replay a read once; business writes never opt in.
public enum SessionReadPolicy {
    public static func canReplay(method: String, path: String) -> Bool {
        let path = path.lowercased()
        if ["cancel", "delete", "/del", "remove", "submit", "logout", "paymoney", "/book", "renew", "newattempt", "_save.do"].contains(where: path.contains) { return false }
        if ["GET", "HEAD"].contains(method.uppercased()) { return true }
        guard method.uppercased() == "POST" else { return false }
        if StudentServiceApp.allCases.contains(where: { $0.queryPath.lowercased() == path }) { return true }
        if path == "/xgxsfw/sys/qjgl/modules/wdqj/xsqjjlxq.do" { return true }
        return ["/component/query", "/xszykb/query", "/usermanager/queryxsxx", "/cjgl/grcjcx/grcjcx",
                "/cjgl/cjzhtjcx/cjcx/getxss", "/cjgl/cjzhtjcx/cjcx/querybyyq", "/xsxktz/queryrwxxcxlist",
                "/api/systemapi/getmeeting", "/api/systemapi/getuserinfo", "/api/client/account/query", "/api/client/report/detailpage", "/cdkb/querycdkblist", "/epay/vcard/getqrcode"].contains(where: path.hasPrefix)
    }
    public static func expired(status: Int, data: Data) -> Bool {
        if status == 401 || (300..<400).contains(status) { return true }
        guard (200..<300).contains(status) else { return false }
        let prefix = String(decoding: data.prefix(8192), as: UTF8.self)
        if prefix.range(of: "(?i)name=[\"']execution[\"']|cas/login|j_spring_cas_security_check", options: .regularExpression) != nil { return true }
        if ["请用户重新登录", "无效会话", "用户未登录"].contains(where: prefix.contains) { return true }
        if data.count < 8_000_000, let value = try? JSONDecoder().decode(WireValue.self, from: data) {
            let message = value["message"].text + value["msg"].text
            if ["请用户重新登录", "无效会话", "用户未登录", "未登录"].contains(where: message.contains) { return true }
            return ["300", "302", "401"].contains(value["code"].text) || ["5001", "5002", "5003"].contains(value["ErrorCode"].text)
        }
        return false
    }
}

public enum CookieChanges {
    public static func changed(from initial: [HTTPCookie], to current: [HTTPCookie]) -> [HTTPCookie] {
        func key(_ cookie: HTTPCookie) -> String { cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: ".")).lowercased() + "|" + cookie.path + "|" + cookie.name }
        let old = Dictionary(initial.map { (key($0), $0) }, uniquingKeysWith: { _, last in last })
        return current.filter { cookie in
            guard let previous = old[key(cookie)] else { return true }
            return previous.value != cookie.value || previous.expiresDate != cookie.expiresDate || previous.isSecure != cookie.isSecure
        }
    }
}
