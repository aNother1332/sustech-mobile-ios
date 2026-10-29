import Foundation

public struct CampusWeather: Sendable {
    public let summary: String
    public let aqi: Int?
    public var temperature: String? {
        HTMLText.captures("(?<!体感)气温\\s*(-?[0-9]+(?:\\.[0-9]+)?)\\s*[℃°]", in: summary).first.map { $0[1] + "℃" }
    }
    public var symbol: String { summary.contains("无降雨") ? "cloud.sun" : summary.contains("雨") ? "cloud.rain" : "cloud.sun" }
    public init(summary: String, aqi: Int?) { self.summary = summary; self.aqi = aqi }
    public static func read() async throws -> CampusWeather {
        let weather = ServiceHTTP(origin: URL(string: "https://api.sustech.online")!)
        let air = ServiceHTTP(origin: URL(string: "https://air-quality-api.open-meteo.com")!)
        async let w = weather.json("/weather")
        async let a = try? air.json("/v1/air-quality", query: ["latitude": "22.60", "longitude": "113.99", "current": "us_aqi", "timezone": "Asia/Shanghai"])
        let value = try await w
        guard !value["msg"].text.isEmpty else { throw CampusError.invalidResponse("校园天气") }
        let airValue = await a
        return CampusWeather(summary: value["msg"].text, aqi: airValue?["current"]["us_aqi"].int)
    }
}

public struct ExchangeProgram: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let location: String
    public let range: String
    public let status: String
    public let available: Bool
    public let imageURL: URL?
    public let description: String
    public let requirements: String
    public let fee: String
    public let applicationDates: String
    public let url: URL
}
public struct ExchangeClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func programs(page: Int) async throws -> (items: [ExchangeProgram], total: Int) {
        let raw = String(decoding: try await http.data("/Main/GetSmartLeftMenuTData.do"), as: UTF8.self)
            .replacingOccurrences(of: "\\/", with: "/").replacingOccurrences(of: "&amp;", with: "&")
        guard let match = HTMLText.captures("StudentExchange_2247/ProjectList[0-9]*\\.do\\?[^\"']*?ts=([0-9]+)[^\"']*?userToken=([0-9A-Fa-f]+)", in: raw).first else { throw ServiceFailure("交换平台未返回项目会话，请先打开官方平台完成认证。") }
        let value = try await http.json("/StudentExchange_2247/GetShortProjectListForStudent.do", query: ["pageSize": "24", "currentPageIndex": String(page), "ts": match[1], "userToken": match[2]])
        return try Self.parsePrograms(value)
    }
    public static func parsePrograms(_ value: WireValue) throws -> (items: [ExchangeProgram], total: Int) {
        guard case .array = value["DataList"] else { throw CampusError.invalidResponse("交换项目列表") }
        let items = value["DataList"].rows.compactMap { row -> ExchangeProgram? in
            guard !row["ID"].text.isEmpty, !row["Name"].text.isEmpty else { return nil }
            var parts = URLComponents(string: "https://ws.sustech.edu.cn/StudentExchange_2247/ProjectDetail2247.do")!
            parts.queryItems = [URLQueryItem(name: "ID", value: row["ID"].text), URLQueryItem(name: "Code", value: row["Code"].text), URLQueryItem(name: "token", value: row["TokenKey"].text)]
            guard let url = parts.url else { return nil }
            let image = row["ProjectImageUrl"].text.isEmpty ? nil : URL(string: HTMLText.decoded(row["ProjectImageUrl"].text), relativeTo: URL(string: "https://ws.sustech.edu.cn")!)?.absoluteURL
            let safeImage = image.flatMap { url in url.scheme == "https" && url.host == "ws.sustech.edu.cn" && url.user == nil && url.password == nil ? url : nil }
            let location = [row["RegionName"].text, row["ProjectSchoolName"].text.isEmpty ? row["ProjectAgencyName"].text : row["ProjectSchoolName"].text, row["ProjectTypeText"].text].map(HTMLText.plain).filter { !$0.isEmpty }.joined(separator: " · ")
            return ExchangeProgram(id: row["ID"].text, name: HTMLText.plain(row["Name"].text), location: location,
                range: HTMLText.plain(row["ApplyRangeText"].text), status: HTMLText.plain(row["StudentExchangeProjectStatusIDText"].text.isEmpty ? row["IsValidTextByEndDate"].text : row["StudentExchangeProjectStatusIDText"].text),
                available: (row["IsAppliable"].int ?? 0) > 0, imageURL: safeImage,
                description: HTMLText.plain(row["ProjectDescription"].text), requirements: HTMLText.plain(row["ApplyCondition"].text), fee: HTMLText.plain(row["FeeDescript"].text),
                applicationDates: [row["ApplyBeginDate"].text, row["ApplyEndDate"].text].map(HTMLText.plain).filter { !$0.isEmpty }.joined(separator: " – "), url: url)

        }
        return (items, value["RecordCount"].int ?? items.count)
    }
}

public enum CardCodeKind: String, CaseIterable, Sendable { case campus = "校园码", identity = "身份码"; public var lifetime: Double { self == .campus ? 30 : 60 } }
public struct CardCodeClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func code(_ kind: CardCodeKind) async throws -> String {
        if kind == .identity {
            let html = String(decoding: try await http.data("/epay/h5/v5qrcode", query: ["codetype": "O5"]), as: UTF8.self)
            for tag in HTMLText.captures("(?i)<input\\b[^>]*>", in: html) {
                let attrs = HTMLText.attributes(tag[0]); if attrs["id"] == "myText", let text = attrs["value"], !text.isEmpty { return text }
            }
            throw CampusError.invalidResponse("身份码")
        }
        let html = String(decoding: try await http.data("/epay/vcard/index"), as: UTF8.self)
        var meta: [String: String] = [:]
        for tag in HTMLText.captures("(?i)<meta\\b[^>]*>", in: html) { let attrs = HTMLText.attributes(tag[0]); if let key = attrs["name"], let value = attrs["content"] { meta[key] = value } }
        guard let header = meta["_csrf_header"], let token = meta["_csrf"], !token.isEmpty,
              header.range(of: "^[A-Za-z0-9-]+$", options: .regularExpression) != nil else { throw CampusError.invalidResponse("校园码 CSRF") }
        let value = try await http.json("/epay/vcard/getqrcode", method: "POST", headers: [header: token])
        guard !value["qrcode"].text.isEmpty else { throw CampusError.invalidResponse("校园码") }; return value["qrcode"].text
    }
}
