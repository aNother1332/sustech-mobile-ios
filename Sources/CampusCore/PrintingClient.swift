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
public struct PrintingClient: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    /// Public device directory. Do not require a CAS session or mark the user logged in.
    public static func publicStations() async throws -> [WireValue] {
        try await PrintingClient(http: ServiceHTTP(origin: URL(string: "https://pms.sustech.edu.cn")!)).stations()
    }
    public func stations() async throws -> [WireValue] {
        let value = try Self.unwrap(await http.json("/api/client/Station/GetList", query: ["timestamp": String(Int(Date.now.timeIntervalSince1970))]))
        guard case .array = value else { throw CampusError.invalidResponse("打印站点") }
        return value.rows
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
        let result = try Self.unwrap(await http.json("/api/client/PrintJob/Get", query: ["timestamp": "0"]))
        guard case .array = result else { throw CampusError.invalidResponse("打印队列") }
        return try result.rows.map { row in
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
