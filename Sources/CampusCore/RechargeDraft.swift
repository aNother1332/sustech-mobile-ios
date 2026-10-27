import Foundation

public struct RechargeAuth: Codable, Sendable {
    public let userId: String; public let cardId: String; public let token: String
    /// Accept only an explicitly pasted first-party WxLogin callback or locally exported JSON.
    public static func imported(_ text: String) throws -> RechargeAuth {
        guard text.utf8.count < 16384 else { throw CampusError.signInRequired }
        if let data = text.data(using: .utf8), let value = try? JSONDecoder().decode(RechargeAuth.self, from: data) { try value.validate(); return value }
        guard let url = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", url.host == "campuscard.xh.sustech.edu.cn", url.user == nil, url.password == nil,
              url.port == nil || url.port == 443 else { throw ServiceFailure("请粘贴学校充值授权回调链接。") }
        let fragment = url.fragment.flatMap { URLComponents(string: "https://campuscard.xh.sustech.edu.cn/" + $0) }
        let items = (url.queryItems ?? []) + (fragment?.queryItems ?? [])
        guard items.filter({ $0.name == "user" }).count == 1, items.filter({ $0.name == "access_token" }).count == 1,
              let user = items.first(where: { $0.name == "user" })?.value, let token = items.first(where: { $0.name == "access_token" })?.value else { throw ServiceFailure("链接不含充值授权，请在企业微信完成授权后复制回调链接。") }
        let result = RechargeAuth(userId: user, cardId: user, token: token); try result.validate(); return result
    }
    public var headers: [String: String] { ["userId": userId, "token": token] }
    public func validate() throws {
        guard userId == cardId, cardId.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
              !token.isEmpty, token.utf8.count < 4096, token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { throw CampusError.signInRequired }
    }
}
public struct RechargeIdentity: Sendable { public let student: String; public let name: String }
public enum RechargeDraft {
    public static let amounts = [1, 10, 20, 30, 50, 100, 200, 500]
    public static func identity(_ value: WireValue, auth: RechargeAuth) throws -> RechargeIdentity {
        try auth.validate()
        guard value["stuempno"].text == auth.cardId, !value["custname"].text.isEmpty else { throw ServiceFailure("充值身份与当前授权不一致。") }
        return RechargeIdentity(student: value["stuempno"].text, name: value["custname"].text)
    }
    public static func fields(amount: Int, identity: RechargeIdentity) throws -> WireValue {
        return try fields(amountText: String(amount), identity: identity)
    }
    /// A local draft only: this does not establish school support for custom amounts.
    public static func fields(amountText: String, identity: RechargeIdentity) throws -> WireValue {
        let amount = try normalizedAmount(amountText)
        return .object(["cardId": .string(identity.student), "xm": .string(identity.name), "je": .string(amount), "return_url": .string("https://campuscard.xh.sustech.edu.cn/#/pay-result")])
    }
    public static func normalizedAmount(_ text: String) throws -> String {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard input.range(of: "^[0-9]{1,3}(?:\\.[0-9]{1,2})?$", options: .regularExpression) != nil,
              let value = Decimal(string: input, locale: Locale(identifier: "en_US_POSIX")), value > 0, value <= 500 else {
            throw ServiceFailure("请输入 0.01–500 元，最多两位小数；此范围仅为本机草稿限制。")
        }
        let parts = input.split(separator: ".", omittingEmptySubsequences: false)
        let whole = String(Int(parts[0]) ?? 0)
        return whole + "." + (parts.count == 1 ? "00" : String(parts[1]).padding(toLength: 2, withPad: "0", startingAt: 0))
    }
    /// An explicit gate, never a trial POST: branch schema and order reconciliation are unverified.
    public static func requireVerifiedOrderContract() throws {
        throw ServiceFailure("原生下单未启用：尚未验证企业微信授权交接、下单分支与单笔订单到账查询。请使用现有官方页面入口。")
    }
}
