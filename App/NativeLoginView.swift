import SwiftUI
import CampusCore

struct NativeLoginButton: View {
    @Environment(CampusStore.self) private var store
    @State private var presented = false
    var service: CASService = .teaching
    var body: some View {
        let status = store.serviceSessions[service] ?? ServiceSessionState()
        Group {
            if status.valid { Label("已连接", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.campusGreen) }
            else if status.status == .checking || status.status == .unknown {
                ProgressView("检测登录态").font(.caption)
            } else if status.status == .expired {
                Button("登录学校账号", systemImage: "person.badge.key") { presented = true }.buttonStyle(.borderedProminent)
            } else {
                Button("重新检测连接", systemImage: "arrow.clockwise") { Task { await store.checkSession(service, force: true) } }
            }
        }
        .disabled(store.mode == .demo || store.authenticating || store.clearing || store.writing)
        .task { await store.checkSession(service) }
        .sheet(isPresented: $presented, onDismiss: { Task { await store.checkSchoolSessions(force: true) } }) { NativeLoginView() }
    }
}

struct NativeLoginView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var loginTask: Task<Void, Never>?
    @State private var portal: SchoolService?

    var body: some View {
        NavigationStack {
            Form {
                Section("统一身份认证") {
                    TextField("校园账号 / 学号", text: $username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密码", text: $password).textContentType(.password)
                    Button {
                        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let secret = password
                        password = ""
                        loginTask = Task { await store.signIn(username: account, password: secret) }
                    } label: {
                        if store.authenticating { ProgressView("正在连接学校…") } else { Text("登录并连接教务 / Blackboard") }
                    }.disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || store.authenticating || store.clearing || store.writing)
                }
                Section {
                    Text("账号密码由本机通过 HTTPS 直接发送给学校 CAS。本版不保存密码，也不会自动反复登录。登录时会清除旧账号的缓存和会话。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let message = store.authenticationMessage { Text(message).textSelection(.enabled) }
                    if store.authenticating { Button("取消登录", role: .cancel) { loginTask?.cancel() } }
                }
                Section("学校网页登录备用") {
                    Text("验证码或其他交互验证需要在学校页面完成。网页登录保留当前会话；完成后自动检测连接。切换账号请先退出。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("教务完整网页登录") { portal = .teaching }
                    Button("Blackboard 完整网页登录") { portal = .blackboard }
                }.disabled(store.authenticating || store.clearing || store.writing)
            }
            .navigationTitle("学校账号")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(store.authenticating) } }
            .sheet(item: $portal) { SchoolBrowser(service: $0) }
        }
        .interactiveDismissDisabled(store.authenticating)
        .onDisappear { password = ""; loginTask?.cancel() }
    }
}
