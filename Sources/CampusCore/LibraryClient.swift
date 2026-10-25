import Foundation

public struct LibraryBook: Identifiable, Sendable {
    public let id: String
    public let context: String
    public let title: String
    public let author: String
    public let year: String
}
public struct LibraryHolding: Identifiable, Sendable {
    public let id: String
    public let location: String
    public let callNumber: String
    public let status: String
}
public struct LibraryLoan: Identifiable, Sendable {
    public let id: String
    public let title: String
    public let due: String
    public let location: String
    public let renewed: String
}
public struct LibraryOccupancy: Sendable {
    public let total: Int?
    public let buildings: [String: Int]
    public let hours: String
}
public struct LibraryClient: Sendable {
    public static let origin = URL(string: "https://sustc.primo.exlibrisgroup.com.cn")!
    public static let view = "86SUSTC_INST:86SUSTC"
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public static func books(_ response: WireValue) throws -> [LibraryBook] {
        guard case .array = response["docs"] else { throw CampusError.invalidResponse("馆藏搜索") }
        return try response["docs"].rows.map { row in
            let display = row["pnx"]["display"]
            let id = row["pnx"]["control"]["recordid"].rows.first?.text ?? ""
            guard !id.isEmpty, let title = display["title"].rows.first?.text else { throw CampusError.invalidResponse("馆藏条目") }
            return LibraryBook(id: id, context: row["context"].text.isEmpty ? "L" : row["context"].text,
                title: HTMLText.plain(title), author: HTMLText.plain(display["creator"].rows.first?.text ?? "").components(separatedBy: "$$")[0], year: display["creationdate"].rows.first?.text ?? "")
        }
    }
    public func search(_ text: String, offset: Int = 0) async throws -> [LibraryBook] {
        try Self.books(await http.json("/primaws/rest/pub/pnxs", query: ["vid": Self.view, "inst": "86SUSTC", "tab": "Everything", "scope": "MyInstitution", "q": "any,contains," + text, "lang": "zh-CN", "sort": "rank", "limit": "20", "offset": String(offset), "pcAvailability": "true", "skipDelivery": "N"]))
    }
    public func holdings(_ book: LibraryBook) async throws -> [LibraryHolding] {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        guard let id = book.id.addingPercentEncoding(withAllowedCharacters: safe), let context = book.context.addingPercentEncoding(withAllowedCharacters: safe) else { throw CampusError.unsafeURL }
        let reply = try await http.json("/primaws/rest/pub/pnxs/\(context)/\(id)", query: ["vid": Self.view, "inst": "86SUSTC", "lang": "zh-CN"])
        guard case .object = reply["delivery"] else { throw CampusError.invalidResponse("馆藏详情") }
        let delivery = reply["delivery"]
        var rows = delivery["holding"].rows
        if rows.isEmpty, case .array = delivery["bestlocation"] { rows = delivery["bestlocation"].rows }
        return rows.enumerated().map { i, row in LibraryHolding(id: String(i), location: row["mainLocation"].text + " · " + row["subLocation"].text, callNumber: row["callNumber"].text, status: row["availabilityStatus"].text) }
    }
    public static func occupancy(_ html: String) -> LibraryOccupancy {
        let clean = html.replacingOccurrences(of: "(?s)<!--.*?-->", with: "", options: .regularExpression)
        let total = HTMLText.captures("在馆人数[：:]\\s*<span class=\"num\">(\\d+)</span>", in: clean).first.flatMap { Int($0[1]) }
        var places: [String: Int] = [:]
        for row in HTMLText.captures("class=\"name\">([^<]+)</span>\\s*<span class=\"num2\">(\\d+)</span>", in: clean) { places[row[1]] = Int(row[2]) }
        let hours = HTMLText.captures("class=\"num\">(\\d{1,2}:\\d{2}\\s*-\\s*\\d{1,2}:\\d{2})<", in: clean).first?[1] ?? ""
        return LibraryOccupancy(total: total, buildings: places, hours: hours)
    }
    public func loans(token: String, offset: Int = 1) async throws -> [LibraryLoan] {
        let value = try await account("loans", token: token, query: ["bulk": "50", "lang": "zh-CN", "offset": String(offset), "type": "active"])
        guard case .array = value["loans"]["loan"] else { throw CampusError.invalidResponse("借阅列表") }
        return try value["loans"]["loan"].rows.map { row in
            guard !row["loanid"].text.isEmpty else { throw CampusError.invalidResponse("借阅 ID") }
            return LibraryLoan(id: row["loanid"].text, title: row["title"].text, due: row["duedate"].text, location: row["mainlocationname"].text + " · " + row["callnumber"].text, renewed: row["renew"].text)
        }
    }
    public func renew(_ loan: LibraryLoan, token: String) async throws {
        _ = try await account("renew_loan", token: token, payload: .object(["id": .string(loan.id), "lang": .string("zh-CN")]))
    }
    private func account(_ path: String, token: String, query: [String: String] = [:], payload: WireValue? = nil) async throws -> WireValue {
        guard token.hasPrefix("eyJ"), !token.contains("\r"), !token.contains("\n") else { throw CampusError.signInRequired }
        let reply = try await http.json("/primaws/rest/priv/myaccount/" + path, query: query, payload: payload, headers: ["Authorization": "Bearer \"\(token)\""])
        if reply["reply-code"].text == "0002" { throw CampusError.signInRequired }
        guard reply["status"].text == "ok" else { throw ServiceFailure("图书馆未接受请求，请核对会话及借阅规则。") }
        return reply["data"]
    }
}
