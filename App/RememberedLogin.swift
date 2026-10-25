import CampusCore
import Foundation

struct RememberedSchoolAccount: Codable {
    let username: String
    let password: String
}

extension CampusStore {
    var rememberedUsername: String? { CredentialVault.load(RememberedSchoolAccount.self, key: "school-auto-login")?.username }
    var remembersSchoolAccount: Bool { rememberedUsername != nil }
    @discardableResult func forgetSchoolAccount() -> Bool {
        UserDefaults.standard.set(true, forKey: "school-auto-login-paused")
        do {
            try CredentialVault.remove("school-auto-login")
            automaticLoginMessage = "已删除记住的账号密码，现有登录态仍可使用。"
            return true
        } catch {
            automaticLoginMessage = "自动登录已关闭，但钥匙串凭据未能删除，请解锁设备后重试。"
            return false
        }
    }
    /// Foreground only. Reuse cookies first; never submit on an inconclusive network probe.
    func resumeSchoolConnections() async {
        guard mode == .live, !clearing, !authenticating, !writing, !resumingConnections else { return }
        resumingConnections = true; defer { resumingConnections = false }
        let version = sessionRevision
        await checkSchoolSessions()
        guard version == sessionRevision, mode == .live, !clearing, !authenticating, !writing,
              let account = CredentialVault.load(RememberedSchoolAccount.self, key: "school-auto-login"),
              AutomaticLoginPolicy.shouldAttempt(hasCredentials: true,
                paused: UserDefaults.standard.bool(forKey: "school-auto-login-paused"),
                confirmedExpired: serviceSessions[.teaching]?.status == .expired || serviceSessions[.blackboard]?.status == .expired,
                lastAttempt: lastAutomaticLogin) else { return }
        lastAutomaticLogin = .now
        automaticLoginMessage = "登录态已失效，正在自动登录…"
        await signIn(username: account.username, password: account.password, remember: true, automatic: true)
        await checkSchoolSessions(force: true)
    }
}
