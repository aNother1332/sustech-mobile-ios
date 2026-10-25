import CampusCore
import Foundation
import Security
import WebKit

/// One on-device cookie store for native clients and embedded school pages.
/// Session cookies are kept in Keychain; optional remembered CAS credentials use a separate Keychain entry.
@MainActor
final class SchoolSessions: NSObject, WKHTTPCookieStoreObserver {
    let websiteDataStore = WKWebsiteDataStore.default()
    private var restored = false
    private var restoration: Task<Void, Never>?
    private var restoring = false
    private var clearing = false
    private var revision = 0
    var epoch: Int { revision }
    var cleID = ""
    var cleName = ""
    private var libraryConnectionID: UUID?
    private var libraryConnection: Task<String, Error>?
    private var connecting: [CASService: Task<Void, Never>] = [:]
    private let vault = "cn.sustech.community.daily.sessions.v1"
    override init() {
        super.init()
        websiteDataStore.httpCookieStore.add(self)
    }
    func restore() async {
        if let task = restoration { await task.value; return }
        guard !restored else { return }
        restoring = true
        let task = Task<Void, Never> { @MainActor [weak self] in
            guard let self, !Task.isCancelled else { return }
            await self.restoreVault()
        }
        restoration = task
        await task.value
        restoration = nil; restoring = false
        await save()
    }
    private func restoreVault() async {
        restored = true
        let version = revision
        if let identity = CredentialVault.load([String: String].self, key: "cle-identity") {
            cleID = identity["id"] ?? ""; cleName = identity["name"] ?? ""
        }
        var item: CFTypeRef?
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: vault, kSecReturnData as String: true]
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data, let rows = try? JSONDecoder().decode([SavedCookie].self, from: data) else { return }
        let existing = await websiteDataStore.httpCookieStore.allCookies()
        for row in rows {
            guard revision == version, !clearing else { return }
            guard row.expires == nil || row.expires! > .now,
                  !existing.contains(where: { $0.name == row.name && $0.domain == row.domain && $0.path == row.path }),
                  let cookie = row.cookie else { continue }
            await websiteDataStore.httpCookieStore.setCookie(cookie)
        }
    }
    func cookies() async -> [HTTPCookie] {
        await restore()
        return await websiteDataStore.httpCookieStore.allCookies()
    }
    func connectIfPossible(_ service: CASService) async {
        if let task = connecting[service] { await task.value; return }
        let task = Task { @MainActor in
            do {
                var parts = URLComponents(url: CASPolicy.login, resolvingAgainstBaseURL: false)!
                parts.queryItems = [URLQueryItem(name: "service", value: service.entry.absoluteString)]
                guard let entry = parts.url else { throw CASFailure.redirect }
                try await connect(entry: entry, finalHost: service.entry.host)
            } catch { /* Actual API probe reports service failure. */ }
        }
        connecting[service] = task
        await task.value
        connecting[service] = nil
    }
    func connect(entry: URL, finalHost: String? = nil) async throws {
        let version = revision
        let current = await cookies()
        let updated = try await SessionConnector().connect(entry, cookies: current, finalHost: finalHost)
        guard revision == version, !clearing else { throw CancellationError() }
        for cookie in updated {
            guard revision == version, !clearing else { throw CancellationError() }
            await websiteDataStore.httpCookieStore.setCookie(cookie)
        }
        await save()
    }
    func connectLibrary() async throws -> String {
        if let task = libraryConnection { return try await task.value }
        let version = revision
        let connectionID = UUID(); libraryConnectionID = connectionID
        let task = Task<String, Error> { @MainActor in
            let (token, updated) = try await PrimoAuthentication().connect(cookies: await cookies())
            guard version == revision, !clearing else { throw CancellationError() }
            for cookie in updated { guard version == revision, !clearing else { throw CancellationError() }; await websiteDataStore.httpCookieStore.setCookie(cookie) }
            guard version == revision, !clearing, !Task.isCancelled else { throw CancellationError() }
            try CredentialVault.save(token, key: "library-token")
            return token
        }
        libraryConnection = task; defer { if libraryConnectionID == connectionID { libraryConnection = nil; libraryConnectionID = nil } }; return try await task.value
    }
    func clear() async {
        clearing = true; revision += 1; restored = true
        libraryConnection?.cancel(); libraryConnection = nil; libraryConnectionID = nil
        cleID = ""; cleName = ""; CredentialVault.delete("library-token"); CredentialVault.delete("recharge-token"); CredentialVault.delete("court"); CredentialVault.delete("cle-identity")
        restoration?.cancel(); restoration = nil; restoring = false
        for task in connecting.values { task.cancel() }; connecting = [:]
        SecItemDelete([kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: vault] as CFDictionary)
        await websiteDataStore.removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)
        clearing = false
    }
    func setCLEIdentity(id: String, name: String, epoch: Int) {
        guard !clearing, !id.isEmpty, epoch == revision else { return }
        cleID = id; cleName = name
        try? CredentialVault.save(["id": id, "name": name], key: "cle-identity")
    }
    func connectIC() async throws {
        let existing = await cookies()
        let http = ServiceHTTP(origin: SchoolService.rooms.portalURL, cookies: existing)
        // Probe the actual service instead of treating cookie presence as proof.
        if let probe = try? await http.json("/ic-web/auth/userInfo"), probe["code"].text == "0", probe["data"]["accNo"].int != nil { return }
        let reply = try await http.json("/ic-web/auth/address", query: [
            "finalAddress": "https://booking.lib.sustech.edu.cn/ic/home", "errPageUrl": "https://booking.lib.sustech.edu.cn/#/error",
            "manager": "false", "consoleType": "16"])
        guard reply["code"].text == "0", let entry = URL(string: reply["data"].text),
              SessionConnector.allowed(entry), entry.path.contains("authcenter/toLoginPage") else { throw CASFailure.redirect }
        try await connect(entry: entry, finalHost: "booking.lib.sustech.edu.cn")
    }
    nonisolated func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
        Task { @MainActor [weak self] in await self?.save() }
    }
    private func save() async {
        guard restored, !clearing, !restoring else { return }
        let version = revision
        let cookies = await websiteDataStore.httpCookieStore.allCookies()
        guard revision == version, !clearing else { return }
        let rows = cookies.filter { cookie in
            let host = cookie.domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
            return host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn")
        }.map(SavedCookie.init)
        guard let data = try? JSONEncoder().encode(rows) else { return }
        let key: [String: Any] = [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: vault]
        if SecItemUpdate(key as CFDictionary, [kSecValueData as String: data] as CFDictionary) == errSecItemNotFound {
            var item = key; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(item as CFDictionary, nil)
        }
    }
}

private struct SavedCookie: Codable {
    let name: String; let value: String; let domain: String; let path: String
    let expires: Date?; let secure: Bool; let httpOnly: Bool?
    init(_ cookie: HTTPCookie) {
        name = cookie.name; value = cookie.value; domain = cookie.domain; path = cookie.path
        expires = cookie.expiresDate; secure = cookie.isSecure
        httpOnly = cookie.isHTTPOnly
    }
    var cookie: HTTPCookie? {
        let host = domain.trimmingCharacters(in: CharacterSet(charactersIn: "."))
        guard host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn") else { return nil }
        var props: [HTTPCookiePropertyKey: Any] = [.name: name, .value: value, .domain: domain, .path: path,
            .secure: secure ? "TRUE" : "FALSE"]
        if let expires { props[.expires] = expires }
        if httpOnly == true { props[HTTPCookiePropertyKey(rawValue: "HttpOnly")] = "TRUE" }
        return HTTPCookie(properties: props)
    }
}
