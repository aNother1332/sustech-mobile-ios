import SwiftUI
import CampusCore

struct NativeLoginButton: View {
    @Environment(CampusStore.self) private var store
    @State private var presented = false
    var body: some View {
        Button("登录学校账号", systemImage: "person.badge.key") { presented = true }
            .buttonStyle(.borderedProminent)
            .disabled(store.mode == .demo || store.authenticating || store.clearing)
            .sheet(isPresented: $presented) { NativeLoginView() }
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
                    }.disabled(username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || password.isEmpty || store.authenticating || store.clearing)
                }
                Section {
                    Text("账号密码由本机通过 HTTPS 直接发送给学校 CAS。本版不保存密码，也不会自动反复登录。登录时会清除旧账号的缓存和会话。")
                        .font(.footnote).foregroundStyle(.secondary)
                    if let message = store.authenticationMessage { Text(message).textSelection(.enabled) }
                    if store.authenticating { Button("取消登录", role: .cancel) { loginTask?.cancel() } }
                }
                Section("学校网页登录备用") {
                    Text("验证码或其他交互验证需要在学校页面完成。打开教务或 BB 网页会清除当前离线缓存，避免切换账号后数据混用；完成后返回手动同步。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("教务完整网页登录") { portal = .teaching }
                    Button("Blackboard 完整网页登录") { portal = .blackboard }
                }.disabled(store.authenticating || store.clearing)
            }
            .navigationTitle("学校账号")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(store.authenticating) } }
            .sheet(item: $portal) { SchoolBrowser(service: $0) }
        }
        .interactiveDismissDisabled(store.authenticating)
        .onDisappear { password = ""; loginTask?.cancel() }
    }
}
