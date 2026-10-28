import Foundation
import Security

public enum PrintingAuthFailure: Error, LocalizedError, Sendable {
    case rejected
    public var errorDescription: String? { "打印账号或密码不正确" }
}

/// The printing site's own nonce + RSA login; credentials go only to PMS.
public struct PrintingAuthentication: Sendable {
    public let http: ServiceHTTP
    public init(http: ServiceHTTP) { self.http = http }
    public func signIn(username: String, password: String) async throws {
        let token = try await http.json("/api/client/Auth/GetAuthToken", payload: .object([:]))
        guard token["code"].text == "0", !token["szToken"].text.isEmpty else { throw ServiceFailure("打印认证暂不可用") }
        let response = try await http.json("/api/client/Auth/PublicKey")
        let key = response["result"]["publicKey"].text; let nonce = response["result"]["nonceStr"].text
        guard response["code"].text == "0", !nonce.isEmpty else { throw ServiceFailure("打印认证暂不可用") }
        let encrypted = try Self.encrypt(password + ";" + nonce, publicKey: key)
        let login = try await http.json("/api/client/Auth/Login", payload: .object([
            "szLogonName": .string(username), "szPassword": .string(encrypted), "szToken": token["szToken"]]))
        if login["code"].text == "33558534" { throw PrintingAuthFailure.rejected }
        guard login["code"].text == "0" else { throw ServiceFailure("打印认证暂不可用") }
    }
    public static func encrypt(_ plaintext: String, publicKey: String) throws -> String {
        let encoded = publicKey.components(separatedBy: .newlines).filter { !$0.contains("-----") }.joined().filter { !$0.isWhitespace }
        guard let original = Data(base64Encoded: encoded) else { throw CampusError.invalidResponse("打印公钥") }
        var index = 0
        func field(_ data: Data, _ cursor: inout Int) throws -> (tag: UInt8, value: Data) {
            guard cursor + 2 <= data.count else { throw CampusError.invalidResponse("打印公钥") }
            let tag = data[cursor]; cursor += 1; let first = Int(data[cursor]); cursor += 1
            var length = first
            if first & 128 != 0 {
                let count = first & 127
                guard count > 0, count <= 4, cursor + count <= data.count else { throw CampusError.invalidResponse("打印公钥") }
                length = 0
                for _ in 0..<count { length = length * 256 + Int(data[cursor]); cursor += 1 }
            }
            guard length > 0, cursor + length <= data.count else { throw CampusError.invalidResponse("打印公钥") }
            let result = data.subdata(in: cursor..<(cursor + length)); cursor += length
            return (tag, result)
        }
        let root = try field(original, &index); var inner = 0
        guard root.tag == 0x30 else { throw CampusError.invalidResponse("打印公钥") }
        let first = try field(root.value, &inner)
        let der: Data
        if first.tag == 0x30 {
            let bits = try field(root.value, &inner)
            guard bits.tag == 0x03, bits.value.first == 0 else { throw CampusError.invalidResponse("打印公钥") }
            der = Data(bits.value.dropFirst())
        } else { der = original }
        let attrs: [CFString: Any] = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic]
        guard let key = SecKeyCreateWithData(der as CFData, attrs as CFDictionary, nil),
              let result = SecKeyCreateEncryptedData(key, .rsaEncryptionPKCS1, Data(plaintext.utf8) as CFData, nil) else { throw CampusError.invalidResponse("打印公钥") }
        return (result as Data).base64EncodedString()
    }
}
