import Foundation

public struct PrintOptions: Sendable {
    public var color = 1; public var paper = 9; public var duplex = 1; public var copies = 1
    public var first = 0; public var last = 0
    public init() {}
    public func fields() throws -> [String: String] {
        guard [1, 2].contains(color), [8, 9].contains(paper), [1, 2, 3].contains(duplex),
              (1...99).contains(copies), first >= 0, first == 0 || last >= first else { throw ServiceFailure("请检查打印份数、纸张和页码范围。") }
        return ["dwColor": String(color), "dwPaperId": String(paper), "dwDuplex": String(duplex),
            "dwCopies": String(copies), "dwFrom": String(first), "dwTo": String(last), "BackURL": "result.html"]
    }
}
public struct PrintJob: Identifiable, Sendable {
    public let id: String; public let name: String; public let copies: String; public let attributes: String
}
public enum PrintingListKind: Sendable, Equatable { case stations, jobs, scans, usage }
public struct PrintingClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public static func list(_ reply: WireValue, kind: PrintingListKind) throws -> [WireValue] {
        let result = try unwrap(reply)
        guard reply.fields.keys.contains("result") else { throw CampusError.invalidResponse("打印列表") }
        // The original printDoc.js and scanDoc.js explicitly show no records for
        // a successful null result. This is NOT the usage/station contract.
        if result == .null, kind == .jobs || kind == .scans { return [] }
        guard case .array = result else { throw CampusError.invalidResponse("打印列表") }
        for row in result.rows {
            let valid: Bool
            switch kind {
            case .stations: valid = row["dwDevSN"].int != nil && !row["szName"].text.isEmpty
            case .jobs: valid = row["dwJobId"].int != nil && !row["szJobName"].text.isEmpty
            case .scans: valid = row["dwJobId"].int != nil && !row["szDisplayName"].text.isEmpty && row["dwFileSize"].int != nil
            case .usage: valid = row["dwDate"].int != nil && row["dwPages"].int != nil
            }
            guard valid else { throw CampusError.invalidResponse("打印列表条目") }
        }
        return result.rows
    }
    public static func probeMessage(status: Int, data: Data) -> String {
        let text = String(decoding: data.prefix(300), as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        if status == 403 || text.hasPrefix("Access forbidden") { return "打印服务拒绝访问（需校园网）" }
        if status == 401 { return "接口已响应，尚未登录" }
        guard status == 200, let value = try? JSONDecoder().decode(WireValue.self, from: data) else { return "未收到有效打印数据" }
        if ["4", "401"].contains(value["code"].text) { return "接口已响应，尚未登录" }
        guard value["code"].text == "0", !value["result"]["publicKey"].text.isEmpty else { return "打印接口响应异常" }
        return "公共接口可访问；校内打印未验证"
    }
    /// Public device directory. Do not require a CAS session or mark the user logged in.
    public static func publicStations() async throws -> [WireValue] {
        try await PrintingClient(http: ServiceHTTP(origin: URL(string: "https://pms.sustech.edu.cn")!)).stations()
    }
    public func stations() async throws -> [WireValue] {
        try Self.list(await http.json("/api/client/Station/GetList", query: ["timestamp": String(Int(Date.now.timeIntervalSince1970))]), kind: .stations)
    }
    public static func unwrap(_ value: WireValue) throws -> WireValue {
        guard value["code"].text == "0" else {
            let message = value["message"].text
            if ["登录", "会话"].contains(where: message.contains) { throw CampusError.signInRequired }
            throw ServiceFailure(message.isEmpty ? "打印平台未确认操作成功。" : message)
        }
        return value["result"]
    }
    public func jobs() async throws -> [PrintJob] {
        let result = try Self.list(await http.json("/api/client/PrintJob/Get", query: ["timestamp": "0"]), kind: .jobs)
        return try result.map { row in
            guard !row["dwJobId"].text.isEmpty else { throw CampusError.invalidResponse("打印任务 ID") }
            return PrintJob(id: row["dwJobId"].text, name: row["szJobName"].text, copies: row["dwCopies"].text, attributes: row["szAttribe"].text)
        }
    }
    public func delete(_ id: String) async throws {
        guard let number = Int64(id) else { throw CampusError.invalidResponse("打印任务 ID") }
        _ = try Self.unwrap(await http.json("/api/client/PrintJob/Del", payload: .object(["dwJobId": .integer(number), "dwOldJobId": .integer(number)])))
    }
    public func upload(pdf: Data, name: String, options: PrintOptions) async throws {
        guard pdf.starts(with: Data("%PDF-".utf8)), pdf.count <= 50 * 1024 * 1024 else { throw ServiceFailure("请选择 50 MB 以内的有效 PDF 文件。") }
        let boundary = "Campus-" + UUID().uuidString
        let filename = name.replacingOccurrences(of: "[^a-zA-Z0-9._-]", with: "_", options: .regularExpression)
        var body = Data()
        for (key, value) in try options.fields().sorted(by: { $0.key < $1.key }) {
            body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n\(value)\r\n".utf8))
        }
        body.append(Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"szPath\"; filename=\"\(filename)\"\r\nContent-Type: application/pdf\r\n\r\n".utf8))
        body.append(pdf); body.append(Data("\r\n--\(boundary)--\r\n".utf8))
        let data = try await http.data("/api/client/CloudPrint/Upload", body: body, contentType: "multipart/form-data; boundary=\(boundary)", headers: ["Referer": http.origin.absoluteString + "client/new/cprintPc/"])
        guard let reply = try? JSONDecoder().decode(WireValue.self, from: data) else {
            throw ServiceFailure("上传请求已发出，但返回结果无法确认。请先刷新队列核对，不要直接重复提交。")
        }
        _ = try Self.unwrap(reply)
    }
}
