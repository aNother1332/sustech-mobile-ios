import Foundation

public struct CLEIdentity: Sendable {
    public let id: String
    public let name: String
    public init(id: String, name: String) { self.id = id; self.name = name }
    public static func parse(_ html: String) throws -> CLEIdentity {
        guard let raw = HTMLText.captures("(?m)(?:var\\s+)?pageMeta\\s*=\\s*(\\{[^\\r\\n]+\\})\\s*;?", in: html).first?[1],
              let data = raw.data(using: .utf8), let value = try? JSONDecoder().decode(WireValue.self, from: data),
              !value["params"]["USERID"].text.isEmpty else { throw CampusError.signInRequired }
        return CLEIdentity(id: value["params"]["USERID"].text, name: value["params"]["USERNAME"].text)
    }
}

public enum CollegeAuthentication {
    public static let callback = URL(string: "https://booking.sustech.edu.cn/redirect")!
    public static func ticket(from url: URL) throws -> String {
        guard url.scheme == "https", url.host == callback.host, url.path == callback.path,
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "ticket" })?.value,
              value.hasPrefix("ST-"), value.count < 2048 else { throw CampusError.signInRequired }
        return value
    }
    public static func token(_ response: WireValue) throws -> String {
        guard response["IsSuccess"] == .bool(true), !response["Data"]["Token"].text.isEmpty else {
            throw ServiceFailure(response["Message"].text.isEmpty ? "书院认证暂不可用" : response["Message"].text)
        }
        return response["Data"]["Token"].text
    }
}
