import Foundation

public enum CampusClock {
    public static func format(_ date: Date, _ pattern: String = "yyyy-MM-dd") -> String {
        CampusDateFormats.shared.string(date, pattern: pattern)
    }
    public static func date(_ text: String, _ pattern: String = "yyyy-MM-dd") -> Date? {
        CampusDateFormats.shared.date(text, pattern: pattern)
    }
    public static func serverDate(_ value: WireValue) -> Date? {
        if let number = Double(value.text), number > 100_000_000 {
            return Date(timeIntervalSince1970: number > 100_000_000_000 ? number / 1000 : number)
        }
        if value.text.contains("T") {
            let iso = ISO8601DateFormatter()
            if let result = iso.date(from: value.text) { return result }
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let result = iso.date(from: value.text) { return result }
        }
        let text = value.text.replacingOccurrences(of: "T", with: " ")
        for pattern in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd HH:mm"] {
            if let result = date(String(text.prefix(pattern == "yyyy-MM-dd HH:mm:ss" ? 19 : 16)), pattern) { return result }
        }
        return nil
    }
}
public struct ReservationItem: Identifiable, Sendable {
    public let id: String; public let title: String; public let detail: String; public let raw: WireValue
    public init(id: String, title: String, detail: String, raw: WireValue) { self.id = id; self.title = title; self.detail = detail; self.raw = raw }
}
public struct ICClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func call(_ path: String, query: [String: String] = [:], payload: WireValue? = nil) async throws -> WireValue {
        let value = try await http.json("/ic-web" + path, query: query, payload: payload)
        if value["code"].text == "300" { throw CampusError.signInRequired }
        if value["message"].text.contains("频繁") { throw CampusError.rateLimited }
        guard value["code"].text == "0" else { throw ServiceFailure(value["message"].text.isEmpty ? "IC 服务未确认操作成功，请先连接图书馆预约会话。" : value["message"].text) }
        return value["data"]
    }
    public func rooms() async throws -> [ReservationItem] {
        let groups = try await call("/roomDevice/roomInfos", query: ["classKind": "1", "kindId": "", "labId": ""])
        guard case .array = groups else { throw CampusError.invalidResponse("IC 房间") }
        var result: [String: ReservationItem] = [:]
        for group in groups.rows { for lab in group["labInfos"].rows { for room in lab["roomInfos"].rows {
            let id = room["devId"].text
            guard !id.isEmpty else { continue }
            let lending = lab["roomInfos"].rows.count == 1 && room["devName"].text == lab["labName"].text
            result[id] = ReservationItem(id: id, title: room["devName"].text,
                detail: lab["labName"].text + " · 当前已有安排 \(room["resvInfos"].rows.count) 项" + (lending ? " · 设备外借请使用学校页面" : ""),
                raw: room.replacing(["nativeBookable": .bool(!lending), "labId": lab["labId"]]))
        } } }
        return result.values.sorted { $0.title < $1.title }
    }
    public func mine() async throws -> [ReservationItem] {
        let rows = try await call("/reserve/resvInfo", query: ["beginDate": CampusClock.format(.now), "endDate": CampusClock.format(.now.addingTimeInterval(60 * 86400)), "page": "1", "pageNum": "100"])
        guard case .array = rows else { throw CampusError.invalidResponse("IC 我的预约") }
        return rows.rows.map { row in
            let begin = CampusClock.serverDate(row["resvBeginTime"]).map { CampusClock.format($0, "yyyy-MM-dd HH:mm") } ?? row["resvBeginTime"].text
            let end = CampusClock.serverDate(row["resvEndTime"]).map { CampusClock.format($0, "yyyy-MM-dd HH:mm") } ?? row["resvEndTime"].text
            return ReservationItem(id: row["uuid"].text, title: row["resvDevInfoList"].rows.first?["devName"].text ?? row["testName"].text,
                detail: "\(begin) → \(end) · 状态 \(row["resvStatus"].text)", raw: row)
        }
    }
    public static func matches(_ item: ReservationItem, room: String, begin: Date, end: Date) -> Bool {
        guard item.raw["resvDevInfoList"].rows.contains(where: { $0["devId"].text == room }),
              let a = CampusClock.serverDate(item.raw["resvBeginTime"]), let b = CampusClock.serverDate(item.raw["resvEndTime"]) else { return false }
        return CampusClock.format(a, "yyyy-MM-dd HH:mm") == CampusClock.format(begin, "yyyy-MM-dd HH:mm")
            && CampusClock.format(b, "yyyy-MM-dd HH:mm") == CampusClock.format(end, "yyyy-MM-dd HH:mm")
    }
    public func book(room: ReservationItem, begin: Date, end: Date, title: String, members: [String]) async throws {
        guard end > begin, begin > .now else { throw ServiceFailure("请选择有效的未来预约时段。") }
        guard room.raw["devId"].int != nil, room.raw["nativeBookable"] != .bool(false) else { throw ServiceFailure("该条目不是可直接预约的研讨间，请使用学校页面。") }
        let scope = try await call("/borrow/reserve/timeScope", query: ["beginDate": CampusClock.format(begin, "yyyyMMdd")])
        if case .array(let windows) = scope, windows.isEmpty { throw ServiceFailure("学校未开放该日预约。") }
        let info = try await call("/auth/userInfo")
        guard let me = info["accNo"].int, me > 0 else { throw CampusError.signInRequired }
        var accounts: Set<Int> = [me]
        for sid in members {
            let rows = try await call("/account/getMembers", query: ["key": sid, "page": "1", "pageNum": "10"])
            guard let row = rows.rows.first(where: { $0["logonName"].text == sid }), let number = row["accNo"].int,
                  row["status"].int != 2, row["localstatus"].int != 2 else { throw ServiceFailure("未找到可用的同行成员，请核对输入的学号。") }
            accounts.insert(number)
        }
        if let minimum = HTMLText.captures("([0-9]+)[-–~至][0-9]+人", in: room.title).first.flatMap({ Int($0[1]) }), minimum >= 3, accounts.count < 3 {
            throw ServiceFailure("此房间至少需要预约人和两位同行成员，请补全成员学号。")
        }
        _ = try await call("/reserve", payload: .object([
            "sysKind": .number(1), "appAccNo": .number(Double(me)), "memberKind": .number(accounts.count > 1 ? 2 : 1),
            "resvMember": .array(accounts.sorted().map { .number(Double($0)) }),
            "resvBeginTime": .string(CampusClock.format(begin, "yyyy-MM-dd HH:mm:00")), "resvEndTime": .string(CampusClock.format(end, "yyyy-MM-dd HH:mm:00")),
            "testName": .string(title.isEmpty ? "学习讨论" : title), "resvKind": .number(2), "resvProperty": .number(0),
            "appUrl": .string(""), "resvDev": .array([.number(Double(room.raw["devId"].int!))]), "memo": .string("")]))
    }
    public func cancel(_ item: ReservationItem) async throws {
        guard !item.id.isEmpty else { throw CampusError.invalidResponse("IC 取消标识") }
        _ = try await call("/reserve/delete", payload: .object(["uuid": .string(item.id)]))
    }
}

public struct CLEClient: Sendable {
    public static let index = URL(string: "https://ehall.sustech.edu.cn/dxggyw/sys/yyzxyy/*default/index.do")!
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    private static let base = "/dxggyw/sys/yyzxyy/modules/fwyy/"
    public func query(_ model: String, params: [String: String] = [:]) async throws -> [WireValue] {
        var result: [WireValue] = []
        for page in 1...20 {
            let value = try await http.json(Self.base + model + ".do", query: params.merging(["pageSize": "100", "pageNumber": String(page)]) { _, new in new })
            guard ["0", "200"].contains(value["code"].text), case .array = value["datas"][model]["rows"] else {
                throw ServiceFailure("CLE 会话或数据尚未就绪，请先打开官方页面完成连接，再返回刷新。")
            }
            let rows = value["datas"][model]["rows"].rows
            if rows.isEmpty { return result }
            guard result.suffix(rows.count) != rows else { throw CampusError.invalidResponse("CLE 重复分页") }
            result += rows
            if let total = value["datas"][model]["totalSize"].int, result.count >= total { return result }
            if rows.count < 100 { return result }
        }
        throw CampusError.invalidResponse("CLE 分页上限")
    }
    public func configs() async throws -> [WireValue] { try await query("T_NKD_YYZX_FWPZ_QUERY", params: ["SFZZSY": "1"]) }
    public func slots(day: Date) async throws -> [ReservationItem] {
        guard let config = try await configs().first else { throw ServiceFailure("当前没有开放的 CLE 服务配置。") }
        guard let year = Int(config["XN"].text) else { throw CampusError.invalidResponse("CLE 学年") }
        let value = try await http.json("/dxggyw/sys/yyzxyy/educational/getCurrentSchoolSemester.do", query: ["XQ": "\(year)-\(year + 1)-\(config["XQ"].text)"])
        guard let startText = value["datas"]["pageAction"]["rows"].rows.first?["QSRQ"].text,
              let start = CampusClock.date(String(startText.prefix(10))) else { throw CampusError.invalidResponse("CLE 校历") }
        let week = Int(floor(day.timeIntervalSince(start) / (7 * 86400))) + 1
        guard week > 0 else { throw ServiceFailure("日期不在当前学期内。") }
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!
        let weekday = (calendar.component(.weekday, from: day) + 5) % 7 + 1
        let buckets = try await query("T_NKD_YYZX_SKSJB_QUERY", params: ["*order": "+KS"])
        let occupied = try await query("hqyycs")
        let rows = try await query("hqxzkcb", params: ["DJZ": String(week)])
        return rows.filter { $0["DJZ"].int == week && $0["DJT"].int == weekday }.compactMap { row in
            let id = row["SJSZ_WID"].text
            guard !id.isEmpty, let range = buckets.first(where: { $0["KS"].text == row["DJJK"].text })?["SJD"].text, !range.isEmpty else { return nil }
            let stamp = CampusClock.format(day) + " " + range
            let count = occupied.filter { $0["FWZY_ID"].text == row["WID"].text && $0["SKSJ"].text == stamp }.reduce(0) { $0 + ($1["times"].int ?? 0) }
            let raw = row.replacing(["SKSJ": .string(stamp), "KCH": row["DJJK"], "PZ_ID": config["WID"], "occupied": .number(Double(count)),
                "capacity": .number(Double(max(1, config["SJDXZRS"].int ?? 1))), "quota": .number(Double(max(1, config["ZDYYCS"].int ?? 3)))])
            return ReservationItem(id: id, title: row["JSXM"].text + " · " + row["FWLX_DISPLAY"].text,
                detail: stamp + " · " + row["DD"].text + " · 已约 \(count)" + (row["SFXXYY"].text == "1" ? " · 仅线下" : ""), raw: raw)
        }
    }
    public func mine(sid: String) async throws -> [ReservationItem] {
        guard !sid.isEmpty else { throw CampusError.signInRequired }
        let filter: WireValue = .array([.object(["name": .string("XSXH"), "value": .string(sid), "builder": .string("equal"), "linkOpt": .string("AND")])])
        let data = try JSONEncoder().encode(filter)
        let rows = try await query("T_NKD_YYZX_XSYY_QUERY", params: ["querySetting": String(decoding: data, as: UTF8.self)])
        return rows.filter { $0["XSXH"].text == sid }.map { ReservationItem(id: $0["WID"].text, title: $0["JSXM"].text,
            detail: $0["SKSJ"].text + " · 状态 " + $0["YYZT"].text, raw: $0) }
    }
    public func book(_ slot: ReservationItem, sid: String, name: String, note: String) async throws {
        guard !sid.isEmpty, !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, note.count <= 500 else { throw ServiceFailure("请先连接 CLE 身份，并填写 1–500 字预约说明。") }
        let row = slot.raw
        guard let day = CampusClock.date(String(row["SKSJ"].text.prefix(10))) else { throw CampusError.invalidResponse("CLE 预约日期") }
        let current = try await slots(day: day)
        guard let fresh = current.first(where: { $0.id == slot.id }),
              (fresh.raw["occupied"].int ?? 0) < (fresh.raw["capacity"].int ?? 1) else { throw ServiceFailure("该时段已满或发生变化，请刷新后重新选择。") }
        let own = try await mine(sid: sid)
        guard !own.contains(where: { $0.raw["SKSJ"].text == row["SKSJ"].text && !["4", "5"].contains($0.raw["YYZT"].text) }) else { throw ServiceFailure("你已有该时段预约，请勿重复提交。") }
        let guards = try await query("T_NKD_YYZX_FWZY_SJSZ_QUERY", params: ["WID": slot.id])
        guard let check = guards.first, check["SFXXYY"].text != "1", row["SFXXYY"].text != "1" else { throw ServiceFailure("该时段不可在线预约，请查看学校页面。") }
        var form = Dictionary(uniqueKeysWithValues: ["WID", "YYZT_DISPLAY", "YYSJ", "WJSCSJ", "BZ", "SCWJ", "LSYY_DISPLAY", "LSYY", "WFYXXTX", "YFYJSXXTX", "SFGLYQX_DISPLAY", "SFGLYQX"].map { ($0, "") })
        form.merge(["FWLX_DISPLAY": row["FWLX_DISPLAY"].text, "FWLX": row["FWLX"].text, "FWLS_DISPLAY": row["JSXM"].text,
            "FWLS": row["FWLX"].text + "-" + row["JSGH"].text, "FWZY_DISPLAY": row["DD"].text, "FWZY": row["WID"].text,
            "XSXH": sid, "XSXM": name, "JSGH": row["JSGH"].text, "JSXM": row["JSXM"].text, "SKSJ": row["SKSJ"].text,
            "KCH": row["KCH"].text, "YYZT": "1", "YYSM": note, "FWZY_ID": row["WID"].text,
            "FWRQ": String(row["SKSJ"].text.prefix(10)), "PZ_ID": row["PZ_ID"].text, "SJSZ_WID": slot.id]) { _, new in new }
        let value = try await http.json(Self.base + "T_NKD_YYZX_XSYY_SAVE.do", form: form)
        guard ["0", "200"].contains(value["code"].text) else { throw ServiceFailure("CLE 未确认预约成功，请刷新我的预约核对。") }
    }
    public func cancel(_ item: ReservationItem) async throws {
        guard item.raw["YYZT"].text == "1", let day = CampusClock.date(String(item.raw["SKSJ"].text.prefix(10))),
              day.timeIntervalSince(CampusClock.date(CampusClock.format(.now)) ?? .now) >= 2 * 86400 else { throw ServiceFailure("该记录不符合线上取消条件，请联系语言中心核实。") }
        let body = try JSONEncoder().encode(WireValue.object(["WID": .string(item.id), "YYZT": .number(4), "isAdminCancel": .bool(false)]))
        let value = try await http.json("/dxggyw/sys/yyzxyy/modules/wdyy/T_NKD_YYZX_XSYY_SAVE.do", form: ["T_NKD_YYZX_XSYY_SAVE": String(decoding: body, as: UTF8.self)])
        guard ["0", "200"].contains(value["code"].text) else { throw ServiceFailure("CLE 未确认取消成功，请刷新核对。") }
    }
}
