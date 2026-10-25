import SwiftUI
import CampusCore

struct NativeLoginButton: View {
    @Environment(CampusStore.self) private var store
    @State private var presented = false
    var service: CASService = .teaching
    var body: some View {
        let status = store.serviceSessions[service] ?? ServiceSessionState()
        Group {
            if store.mode == .demo { Text("演示模式").font(.caption).foregroundStyle(.secondary) }
            else {
                Menu {
                    Button(status.valid ? "重新登录 / 切换账号" : "登录学校账号") { presented = true }
                    Button("重新检测连接") { Task { await store.checkSession(service, force: true) } }.disabled(status.status == .checking)
                } label: {
                    Label(status.valid ? "已登录" : (status.status == .expired ? "登录学校账号" : status.label), systemImage: status.valid ? "checkmark.circle.fill" : "person.badge.key")
                        .font(.caption)
                }
            }
        }
        .disabled(store.mode == .demo || store.authenticating || store.clearing || store.writing)
        .task { await store.checkSession(service) }
        .sheet(isPresented: $presented, onDismiss: { Task { await store.checkSession(service, force: true); await store.checkSchoolSessions(force: true) } }) {
            if service == .printing { SchoolBrowser(service: .printing) }
            else if service == .card { SchoolBrowser(service: .card) }
            else { NativeLoginView() }
        }
    }
}

struct NativeLoginView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var remember = false
    @State private var loginTask: Task<Void, Never>?
    @State private var portal: SchoolService?

    var body: some View {
        NavigationStack {
            Form {
                Section("统一身份认证") {
                    TextField("校园账号 / 学号", text: $username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("密码", text: $password).textContentType(.password)
                    Toggle("记住账号密码并自动登录", isOn: $remember)
                        .disabled(store.authenticating || store.clearing || store.writing)
                        .onChange(of: remember) { _, value in if !value { store.forgetSchoolAccount() } }
                    Button {
                        let account = username.trimmingCharacters(in: .whitespacesAndNewlines)
                        let secret = password
                        password = ""
                        loginTask = Task { await store.signIn(username: account, password: secret, remember: remember); await store.checkSchoolSessions(force: true) }
                    } label: {
                        if store.authenticating { ProgressView("正在连接学校…") } else { Text("登录并连接教务 / Blackboard") }
                    }.disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || store.authenticating || store.clearing || store.writing)
                }
                Section {
                    Text("账号密码由本机通过 HTTPS 直接发送给学校 CAS。开启后，账号密码仅保存于本机 iOS 钥匙串，不上传到开发者服务器。打开 App 时优先复用登录态，确认失效后自动登录；遇到验证码或密码错误会暂停，需手动处理。关闭选项会删除已记住的密码。")
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
            .navigationTitle("学校账号").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(store.authenticating) } }
            .sheet(item: $portal) { SchoolBrowser(service: $0) }
        }
        .interactiveDismissDisabled(store.authenticating)
        .onAppear { username = store.rememberedUsername ?? ""; remember = store.remembersSchoolAccount }
        .onDisappear { password = ""; loginTask?.cancel() }
    }
}
