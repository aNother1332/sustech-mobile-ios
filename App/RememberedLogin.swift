import CampusCore
import Foundation
import WebKit

struct RememberedSchoolAccount: Codable {
    let username: String
    let password: String
}

extension CampusStore {
    /// Renew authentication within the same account scope. A page waiting for
    /// this task must not be destroyed by a manual-login generation change.
    func renewRememberedCAS() async throws {
        if let task = casRenewal { try await task.value; return }
        guard mode == .live, !clearing, !authenticating,
              !UserDefaults.standard.bool(forKey: "school-auto-login-paused"),
              let account = CredentialVault.load(RememberedSchoolAccount.self, key: "school-auto-login"),
              accountScope == LocalRepository.identity(account.username) else { throw CampusError.signInRequired }
        let version = sessionRevision
        let task = Task { @MainActor in
            do {
                let cookies = try await CASClient().signIn(service: .teaching, username: account.username, password: account.password)
                let exchanged = try await SessionConnector().exchange(CASService.teaching.entry, cookies: cookies, finalHost: CASService.teaching.entry.host)
                let check = ServiceHTTP(origin: CASService.teaching.entry, cookies: exchanged.cookies)
                try await SchoolSessionProbe.teaching(check)
                guard version == self.sessionRevision, !self.clearing else { throw CancellationError() }
                for cookie in exchanged.cookies + check.changedCookies() {
                    guard version == self.sessionRevision, !self.clearing else { throw CancellationError() }
                    await self.websiteDataStore.httpCookieStore.setCookie(cookie)
                }
                guard version == self.sessionRevision, !self.clearing else { throw CancellationError() }
                self.recordSession(.teaching)
            } catch {
                if version == self.sessionRevision, let failure = error as? CASFailure, [.rejected, .challenge, .missingForm].contains(failure) {
                    UserDefaults.standard.set(true, forKey: "school-auto-login-paused")
                }
                throw error
            }
        }
        casRenewal = task
        defer { if version == sessionRevision { casRenewal = nil } }
        try await task.value
    }
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
    func resumeSchoolConnections(confirmedCASExpiry: Bool = false) async {
        guard mode == .live, !clearing, !authenticating, !writing, !resumingConnections else { return }
        resumingConnections = true; defer { resumingConnections = false }
        let version = sessionRevision
        if !confirmedCASExpiry { await checkSchoolSessions() }
        guard version == sessionRevision, mode == .live, !clearing, !authenticating, !writing,
              remembersSchoolAccount,
              AutomaticLoginPolicy.shouldAttempt(hasCredentials: true,
                paused: UserDefaults.standard.bool(forKey: "school-auto-login-paused"),
                confirmedExpired: confirmedCASExpiry || serviceSessions[.teaching]?.status == .expired || serviceSessions[.blackboard]?.status == .expired,
                lastAttempt: lastAutomaticLogin) else { return }
        lastAutomaticLogin = .now
        automaticLoginMessage = "登录态已失效，正在自动登录…"
        do { try await renewRememberedCAS(); automaticLoginMessage = nil }
        catch { automaticLoginMessage = error.localizedDescription }
        await checkSchoolSessions(force: true)
    }
}
