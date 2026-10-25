import CampusCore
import SwiftUI

struct ServiceSessionState {
    enum Status { case unknown, checking, valid, expired, unavailable }
    var status: Status = .unknown
    var checked: Date?
    var note = ""
    var valid: Bool { status == .valid }
    var label: String {
        switch status { case .unknown: "未检测"; case .checking: "检测中"; case .valid: "已连接"; case .expired: "需要登录"; case .unavailable: "暂无法验证" }
    }
}

extension CampusStore {
    func checkSession(_ service: CASService, force: Bool = false) async {
        guard mode == .live, !clearing, !authenticating else { return }
        let old = serviceSessions[service] ?? ServiceSessionState()
        guard old.status != .checking else { return }
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
                let me = try await http.json("/user/me")
                guard !me["userName"].text.isEmpty else { throw CampusError.invalidResponse("教务本人身份") }
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
            let expired = (error as? CampusError) == .signInRequired || (error as? CampusError) == .unexpectedHTML
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
            let expired = (error as? CampusError) == .signInRequired || (error as? CampusError) == .unexpectedHTML
            serviceSessions[service] = ServiceSessionState(status: expired ? .expired : .unavailable, checked: .now, note: error.localizedDescription)
        } else { serviceSessions[service] = ServiceSessionState(status: .valid, checked: .now) }
    }
}

struct SessionBadge: View {
    @Environment(CampusStore.self) private var store
    var service: CASService = .teaching
    var body: some View {
        if store.mode == .live {
            let value = store.serviceSessions[service] ?? ServiceSessionState()
            HStack(spacing: 6) {
                Image(systemName: value.valid ? "checkmark.circle.fill" : "person.crop.circle")
                Text(value.label)
                if let checked = value.checked { Text(checked, style: .time).foregroundStyle(.secondary) }
                Spacer(minLength: 4)
                if value.status == .expired { NativeLoginButton(service: service) }
                if value.status == .unavailable { Button("重试") { Task { await store.checkSession(service, force: true) } } }
            }.font(.caption).foregroundStyle(value.valid ? Color.campusGreen : .secondary)
            .task { await store.checkSession(service) }
        }
    }
}

struct DetailNote: View {
    var title = "说明"
    let text: String
    var body: some View { DisclosureGroup(title) { Text(text).font(.caption).foregroundStyle(.secondary) }.font(.caption) }
}
