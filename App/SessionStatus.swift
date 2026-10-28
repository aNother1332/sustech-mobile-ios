import CampusCore
import SwiftUI

struct ServiceSessionState {
    enum Status { case unknown, checking, valid, expired, unavailable }
    var status: Status = .unknown
    var checked: Date?
    var note = ""
    var valid: Bool { status == .valid }
    var label: String {
        switch status { case .unknown: "未检测"; case .checking: "检测中"; case .valid: "已登录"; case .expired: "需要登录"; case .unavailable: "暂无法验证" }
    }
}

extension CampusStore {
    func checkSession(_ service: CASService, force: Bool = false) async {
        guard mode == .live, !clearing, !authenticating else { return }
        let old = serviceSessions[service] ?? ServiceSessionState()
        if old.status == .checking {
            // A page may already be probing when the foreground task starts.
            // Wait for that verdict so automatic login can observe actual expiry.
            let revision = sessionRevision
            for _ in 0..<120 {
                guard serviceSessions[service]?.status == .checking, revision == sessionRevision else { return }
                do { try await Task.sleep(for: .milliseconds(250)) } catch { return }
            }
            return
        }
        if !force, let checked = old.checked, Date.now.timeIntervalSince(checked) < 120 { return }
        let version = sessionRevision
        let probe = UUID(); serviceProbeTokens[service] = probe
        serviceSessions[service] = ServiceSessionState(status: .checking)
        await sessions.connectIfPossible(service)
        let cookies = await sessions.cookies()
        guard version == sessionRevision, serviceProbeTokens[service] == probe else { return }
        let http = ServiceHTTP(origin: service.entry, cookies: cookies)
        do {
            switch service {
            case .teaching:
                try await SchoolSessionProbe.teaching(http)
            case .blackboard:
                let me = try await http.json("/learn/api/public/v1/users/me")
                guard !me["id"].text.isEmpty else { throw CampusError.signInRequired }
            case .card: _ = try await CardClient(http: http).account()
            case .printing: _ = try await PrintingClient(http: http).jobs()
            }
            guard version == sessionRevision, serviceProbeTokens[service] == probe else { return }
            serviceSessions[service] = ServiceSessionState(status: .valid, checked: .now)
        } catch {
            guard version == sessionRevision, serviceProbeTokens[service] == probe else { return }
            let expired = LoginRequirement.confirmed(error)
            serviceSessions[service] = ServiceSessionState(status: expired ? .expired : .unavailable, checked: .now, note: error.localizedDescription)
        }
        await absorb(http, revision: version)
    }
    func checkSchoolSessions(force: Bool = false) async {
        // Serial probes share CAS exchanges and avoid simultaneous login redirects.
        for service in [CASService.teaching, .blackboard] { await checkSession(service, force: force) }
    }
    func recordSession(_ service: CASService, error: Error? = nil) {
        serviceProbeTokens[service] = nil
        if let error {
            if serviceSessions[service]?.valid == true, error is ServiceFailure { return }
            let expired = LoginRequirement.confirmed(error)
            serviceSessions[service] = ServiceSessionState(status: expired ? .expired : .unavailable, checked: .now, note: error.localizedDescription)
        } else { serviceSessions[service] = ServiceSessionState(status: .valid, checked: .now) }
    }
}

struct SessionBadge: View {
    var service: CASService = .teaching
    var body: some View { NativeLoginButton(service: service) }
}
struct DetailNote: View {
    var title = "说明"
    let text: String
    var body: some View { EmptyView() }
}
struct IndependentConnectionStatus: View {
    let connected: Bool
    let requiresLogin: Bool
    var open: () -> Void
    var body: some View {
        if !connected && requiresLogin {
            Button(action: open) { Label("未登录", systemImage: "person.crop.circle.badge.exclamationmark").font(.subheadline.weight(.medium)).foregroundStyle(.red) }.buttonStyle(.plain)
        }
    }
}
