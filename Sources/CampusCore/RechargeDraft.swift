import Foundation

public struct RechargeAuth: Codable, Sendable {
    public let userId: String; public let cardId: String; public let token: String
    public var headers: [String: String] { ["userId": userId, "token": token] }
    public func validate() throws {
        guard userId == cardId, cardId.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil,
              !token.isEmpty, token.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }) else { throw CampusError.signInRequired }
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
        guard amounts.contains(amount) else { throw ServiceFailure("暂只支持学校页面列出的金额。") }
        return .object(["cardId": .string(identity.student), "xm": .string(identity.name), "je": .string(String(format: "%.2f", Double(amount))), "return_url": .string("https://campuscard.xh.sustech.edu.cn/#/pay-result")])
    }
    /// An explicit gate, never a trial POST: branch schema and order reconciliation are unverified.
    public static func requireVerifiedOrderContract() throws {
        throw ServiceFailure("原生下单未启用：尚未验证企业微信授权交接、下单分支与单笔订单到账查询。请使用现有官方页面入口。")
    }
}
