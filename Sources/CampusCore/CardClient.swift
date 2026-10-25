import Foundation

public struct CardAccount: Sendable { public let name: String; public let balance: String }
public struct CardBill: Identifiable, Sendable {
    public let id: String; public let kind: String; public let amount: String; public let time: String; public let status: String
    public var expense: Decimal? {
        guard !["充值", "退款", "退费", "收入", "失败", "撤销"].contains(where: { (kind + status).contains($0) }),
              !amount.trimmingCharacters(in: .whitespaces).hasPrefix("+") else { return nil }
        guard let match = HTMLText.captures("[0-9]+(?:\\.[0-9]+)?", in: amount).first?.first,
              let value = Decimal(string: match, locale: Locale(identifier: "en_US_POSIX")) else { return nil }
        // Do not infer an unsigned transaction is spending unless its type says so.
        guard amount.contains("-") || ["消费", "支出", "扣款"].contains(where: kind.contains) else { return nil }
        return value
    }
}
public struct CardDay: Identifiable, Sendable {
    public let id: String; public let amount: Decimal
    public var value: Double { NSDecimalNumber(decimal: amount).doubleValue }
}
public enum CardParser {
    public static func account(_ html: String) throws -> CardAccount {
        if html.range(of: "(?i)name=[\"']execution[\"']|cas/login|j_spring_cas_security_check", options: .regularExpression) != nil { throw CampusError.signInRequired }
        let pairs = HTMLText.captures("(?s)class=[\"']weui-cell__bd[\"'][^>]*>\\s*<p[^>]*>(.*?)</p>\\s*</div>\\s*<div[^>]*class=[\"']weui-cell__ft[\"'][^>]*>(.*?)</div>", in: html)
        var values: [String: String] = [:]
        for pair in pairs where pair.count >= 3 { values[HTMLText.plain(pair[1])] = HTMLText.plain(pair[2]) }
        guard let balance = values["账户余额"], !balance.isEmpty else { throw CampusError.invalidResponse("校园卡余额") }
        return CardAccount(name: values["姓名"] ?? "", balance: balance)
    }
    public static func bills(_ html: String) throws -> [CardBill] {
        if html.contains("execution") || html.contains("cas/login") { throw CampusError.signInRequired }
        let blocks = html.components(separatedBy: "weui-media-box weui-media-box_text").dropFirst()
        if blocks.isEmpty && !html.contains("暂无") && !html.contains("无记录") && !html.contains("没有交易") { throw CampusError.invalidResponse("校园卡账单") }
        return try blocks.enumerated().map { index, block in
            guard let title = HTMLText.captures("(?s)<h4[^>]*>(.*?)</h4>", in: block).first, title.count > 1 else { throw CampusError.invalidResponse("校园卡账单条目") }
            let fields = HTMLText.captures("(?s)<div[^>]*>([^<]*)</div>", in: title[1]).map { HTMLText.plain($0[1]) }
            guard fields.count >= 2 else { throw CampusError.invalidResponse("校园卡金额") }
            let time = HTMLText.captures("(?s)color:\\s*#999;\\s*flex:\\s*1[\"'][^>]*>([^<]*)</div>", in: block).first?[1] ?? ""
            let status = HTMLText.captures("(?s)<span[^>]*class=[\"']label label-[^\"']*[\"'][^>]*>(.*?)</span>", in: block).first?[1] ?? ""
            return CardBill(id: "\(index)|\(time)|\(fields[1])", kind: fields[0], amount: fields[1], time: HTMLText.plain(time), status: HTMLText.plain(status))
        }
    }
    public static func curve(_ bills: [CardBill]) -> [CardDay] {
        var totals: [String: Decimal] = [:]
        for bill in bills {
            guard let expense = bill.expense,
                  let date = HTMLText.captures("\\d{4}[-/]\\d{2}[-/]\\d{2}", in: bill.time).first?.first else { continue }
            totals[date.replacingOccurrences(of: "/", with: "-"), default: 0] += expense
        }
        return totals.sorted { $0.key < $1.key }.map { CardDay(id: $0.key, amount: $0.value) }
    }
}

public struct CardClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func account() async throws -> CardAccount { try CardParser.account(String(decoding: await http.data("/epay/h5/accountinfo"), as: UTF8.self)) }
    public func bills() async throws -> [CardBill] { try CardParser.bills(String(decoding: await http.data("/epay/h5/bill"), as: UTF8.self)) }
}
