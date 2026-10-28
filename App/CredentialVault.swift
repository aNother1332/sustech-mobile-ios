import CampusCore
import CoreImage.CIFilterBuiltins
import Security
import SwiftUI
import UIKit

enum CredentialVault {
    static func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key, kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess, let data = item as? Data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
    static func save<T: Encodable>(_ value: T, key: String) throws {
        let data = try JSONEncoder().encode(value)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key]
        let status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query; item[kSecValueData as String] = data; item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw ServiceFailure("无法安全保存登录态，请解锁设备后重试。") }
        } else if status != errSecSuccess { throw ServiceFailure("登录态保存失败，请解锁设备后重试。") }
    }
    static func delete(_ key: String) { SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key] as CFDictionary) }
    static func remove(_ key: String) throws {
        let status = SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: "cn.sustech.community.daily." + key] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw ServiceFailure("钥匙串凭据未能删除，请解锁设备后重试。") }
    }
}
