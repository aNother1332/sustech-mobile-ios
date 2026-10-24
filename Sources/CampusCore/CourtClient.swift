import Foundation

public struct CourtCredentials: Codable, Sendable {
    public let userID: String; public let token: String
    public init(userID: String, token: String) { self.userID = userID; self.token = token }
}
public struct CourtSlot: Identifiable, Sendable {
    public let day: String; public let start: String; public let end: String; public let status: String
    public var id: String { day + "|" + start + "|" + end }
    public var available: Bool { status == "1" }
}
/// Protocol port of the user's local court project. No scheduler, polling,
/// generated slots, automated challenge solver, or retrying booking loop.
public actor CourtClient {
    private static let headers = ["User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.49"]
    private let http: ServiceHTTP
    private var credentials: CourtCredentials?
    public init(credentials: CourtCredentials? = nil, http: ServiceHTTP = ServiceHTTP(origin: URL(string: "https://reservation.sustech.edu.cn")!)) {
        self.http = http; self.credentials = credentials
    }
    public func currentCredentials() -> CourtCredentials? { credentials }
    private func call(_ endpoint: String, query: [String: String] = [:], payload: WireValue? = nil, method: String = "GET", auth: Bool = true) async throws -> WireValue {
        var params = query
        if auth {
            guard let credentials else { throw CampusError.signInRequired }
            params["userid"] = credentials.userID; params["token"] = credentials.token
        }
        let value = try await http.json("/api/blade-app/qywx/" + endpoint, query: params,
            form: endpoint == "getOrderDetailByParam" ? [:] : nil, payload: payload, method: method, headers: Self.headers)
        guard value["code"].text == "200" else {
            if value["msg"].text.contains("鉴权") { throw CampusError.signInRequired }
            throw ServiceFailure("场馆服务未接受请求，请检查授权、时段和学校规则。")
        }
        let data = value["data"]
        if !data["token"].text.isEmpty {
            let id = [data["wxOpenid"].text, data["userid"].text, data["userId"].text, credentials?.userID ?? ""].first { !$0.isEmpty } ?? ""
            guard !id.isEmpty else { throw CampusError.invalidResponse("场馆身份") }
            credentials = CourtCredentials(userID: id, token: data["token"].text)
        }
        return data
    }
    public func login(codeOrURL: String) async throws {
        let input = codeOrURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let code: String
        if let parts = URLComponents(string: input), parts.scheme != nil {
            guard parts.scheme == "https", parts.host == "reservation.sustech.edu.cn",
                  let value = parts.queryItems?.first(where: { $0.name == "code" })?.value else { throw ServiceFailure("请粘贴学校场馆授权回调链接或一次性 code。") }
            code = value
        } else { code = input }
        guard code.range(of: "^[A-Za-z0-9_-]{10,}$", options: .regularExpression) != nil else { throw ServiceFailure("授权 code 格式不正确。") }
        _ = try await call("getUserIdByCode", query: ["code": code], auth: false)
        guard credentials != nil else { throw CampusError.invalidResponse("场馆授权") }
    }
    public func user() async throws -> WireValue { try await call("getUserInfoByUserid") }
    private func paged(_ endpoint: String, query: [String: String] = [:], method: String = "GET") async throws -> [WireValue] {
        var result: [WireValue] = []
        for page in 1...30 {
            let data = try await call(endpoint, query: query.merging(["current": String(page), "size": "100"]) { _, new in new }, method: method)
            if case .array = data { return data.rows }
            guard case .array = data["records"] else { throw CampusError.invalidResponse("场馆分页") }
            let rows = data["records"].rows
            if rows.isEmpty { return result }
            guard result.suffix(rows.count) != rows else { throw CampusError.invalidResponse("场馆重复分页") }
            result += rows
            if let total = data["total"].int, result.count >= total { return result }
            if rows.count < 100 { return result }
        }
        throw CampusError.invalidResponse("场馆分页上限")
    }
    public func gyms() async throws -> [ReservationItem] {
        try await paged("getAppGymPageByCustomerId").compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            return ReservationItem(id: row["id"].text, title: row["name"].text, detail: row["address"].text, raw: row)
        }
    }
    public func grounds(gym: String) async throws -> [ReservationItem] {
        // Never send type=2: it filters out sports courts on this system.
        try await paged("getAppGroundPageByGymId", query: ["gymId": gym], method: "POST").compactMap { row in
            guard !row["id"].text.isEmpty else { return nil }
            return ReservationItem(id: row["id"].text, title: row["name"].text, detail: row["groundTypeStr"].text, raw: row)
        }
    }
    public func slots(ground: String, day: Date) async throws -> [CourtSlot] {
        let date = CampusClock.format(day)
        let value = try await call("getOrderTimeConfigList", query: ["groundId": ground, "startDate": date, "endDate": date])
        guard case .array = value["configList"] else { throw CampusError.invalidResponse("场馆时段") }
        return value["configList"].rows.filter { $0["date"].text == date }.flatMap { config in
            config["timeBlockList"].rows.map { CourtSlot(day: date, start: $0["time"].text, end: $0["endTime"].text, status: $0["status"].text) }
        }
    }
    public func orders() async throws -> [ReservationItem] {
        try await paged("getOrderPageListByParam").map { row in
            ReservationItem(id: row["id"].text, title: row["groundName"].text,
                detail: row["startTime"].text + " → " + row["endTime"].text + " · 状态 " + row["status"].text, raw: row)
        }
    }
    public func captcha() async throws -> WireValue {
        let value = try await http.json("/api/blade-base/captcha/generate/d", payload: .object([:]), headers: Self.headers)
        guard value["captcha"]["type"].text.uppercased() == "SLIDER", !value["id"].text.isEmpty else { throw ServiceFailure("验证码类型暂不支持，请在学校页面完成预约。") }
        return value
    }
    public func checkCaptcha(_ challenge: WireValue, track: [WireValue], start: Date, stop: Date) async throws -> String {
        guard track.count >= 2 else { throw ServiceFailure("请手动拖动滑块完成验证。") }
        let cap = challenge["captcha"]
        let body: WireValue = .object(["id": challenge["id"], "data": .object([
            "bgImageWidth": cap["backgroundImageWidth"], "bgImageHeight": cap["backgroundImageHeight"],
            "templateImageWidth": cap["templateImageWidth"], "templateImageHeight": cap["templateImageHeight"],
            "startTime": .number(start.timeIntervalSince1970 * 1000), "stopTime": .number(stop.timeIntervalSince1970 * 1000), "trackList": .array(track)])])
        let value = try await http.json("/api/blade-base/captcha/check/d", payload: body, headers: Self.headers)
        guard value["code"].text == "200", !value["data"].text.isEmpty else { throw ServiceFailure("滑块验证未通过，请重新获取验证码后手动验证。") }
        return value["data"].text
    }
    public func book(ground: ReservationItem, slot: CourtSlot, captchaToken: String, phone: String, people: Int) async throws {
        guard !captchaToken.isEmpty, !phone.isEmpty, (1...100).contains(people) else { throw ServiceFailure("请填写联系电话和人数，并完成验证码。") }
        guard let day = CampusClock.date(slot.day) else { throw ServiceFailure("预约日期不正确。") }
        let fresh = try await slots(ground: ground.id, day: day)
        guard fresh.contains(where: { $0.id == slot.id && $0.available }) else { throw ServiceFailure("该时段已变化，请刷新重新选择。") }
        let user = try await user()
        let detail = try await call("getGroundDetailByParam", query: ["groundId": ground.id])
        guard !user["id"].text.isEmpty, !detail["gymId"].text.isEmpty, !detail["name"].text.isEmpty else { throw CampusError.invalidResponse("场馆预约身份或场地详情") }
        let blacklist = try await call("isGymBlackByCustomerId")
        guard blacklist != .bool(true), blacklist.text != "1" else { throw ServiceFailure("账号当前不可预约，请联系学校场馆管理人员。") }
        func stamp(_ time: String) throws -> String {
            let parts = time.split(separator: ":").compactMap { Int($0) }
            guard parts.count >= 2, (0...23).contains(parts[0]), (0...59).contains(parts[1]) else { throw ServiceFailure("学校时段格式不正确。") }
            return slot.day + String(format: " %02d:%02d:00", parts[0], parts[1])
        }
        let begin = try stamp(slot.start), end = try stamp(slot.end)
        guard let beginDate = CampusClock.date(begin, "yyyy-MM-dd HH:mm:ss"), let endDate = CampusClock.date(end, "yyyy-MM-dd HH:mm:ss"), beginDate > .now, endDate > beginDate else { throw ServiceFailure("请选择有效的未来时段。") }
        let orders = try await orders()
        let active = orders.filter { ["1", "2"].contains($0.raw["status"].text) && $0.raw["startTime"].text.hasPrefix(slot.day) }
        var duration = endDate.timeIntervalSince(beginDate)
        for item in active {
            guard let a = CampusClock.date(item.raw["startTime"].text.replacingOccurrences(of: "T", with: " "), "yyyy-MM-dd HH:mm:ss"),
                  let b = CampusClock.date(item.raw["endTime"].text.replacingOccurrences(of: "T", with: " "), "yyyy-MM-dd HH:mm:ss") else { throw ServiceFailure("已有订单时间无法核对，请到官方页面确认。") }
            if beginDate < b && endDate > a { throw ServiceFailure("与已有预约时间重叠。") }
            duration += b.timeIntervalSince(a)
        }
        guard duration <= 2 * 3600 else { throw ServiceFailure("目标日期的预约总时长将超过 2 小时，请调整选择。") }
        let now = CampusClock.format(.now, "HH:mm:00"), orderDate = slot.day + " " + now
        let payload: WireValue = .object([
            "id": .string(captchaToken), "customerId": user["id"], "customerName": user["name"].text.isEmpty ? user["customerName"] : user["name"], "customerTel": .string(phone),
            "userNum": .number(Double(people)), "customerEmail": .string(""), "gymId": detail["gymId"], "gymName": detail["gymName"],
            "groundId": .string(ground.id), "groundName": detail["name"], "groundType": .string(detail["groundType"].text.isEmpty ? "0" : detail["groundType"].text),
            "messagePushType": .string("0"), "isIllegal": .string("0"), "orderDate": .string(orderDate),
            "startTime": .string(begin), "endTime": .string(end), "tmpOrderDate": .string(orderDate), "tmpStartTime": .string(begin), "tmpEndTime": .string(end),
            "gymType": .number(2), "isOverOneDay": .string("0"), "title": .string("")])
        _ = try await call("saveOrder", payload: payload)
    }
    public func cancel(_ item: ReservationItem) async throws {
        guard !item.id.isEmpty else { throw CampusError.invalidResponse("场馆订单 ID") }
        let detail = try await call("getOrderDetailByParam", query: ["orderId": item.id], method: "POST")
        _ = try await call("operatOrder", payload: detail.replacing(["status": .number(6)]))
    }
}
