import SwiftUI
import CampusCore

struct NativeLoginButton: View {
    @Environment(CampusStore.self) private var store
    @State private var presented = false
    var service: CASService = .teaching
    var body: some View {
        let status = store.serviceSessions[service] ?? ServiceSessionState()
        Group {
            if store.mode == .live, status.status == .expired {
                Button { presented = true } label: { Label("未登录", systemImage: "person.crop.circle.badge.exclamationmark").foregroundStyle(.red).font(.subheadline.weight(.medium)) }
            }
        }
        .disabled(store.mode == .demo || store.authenticating || store.clearing || store.writing)
        .task { await store.checkSession(service) }
        .sheet(isPresented: $presented, onDismiss: { Task { await store.checkSession(service, force: true); await store.checkSchoolSessions(force: true) } }) {
            NativeLoginView()
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
                    if let message = store.authenticationMessage { Text(message).textSelection(.enabled) }
                    if store.authenticating { Button("取消登录", role: .cancel) { loginTask?.cancel() } }
                }

            }
            .navigationTitle("学校账号").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(store.authenticating) } }
            .sheet(item: $portal) { SchoolBrowser(service: $0) }
            .onChange(of: store.challengeService) { _, service in if let service { portal = service } }
        }
        .interactiveDismissDisabled(store.authenticating)
        .onAppear { username = store.rememberedUsername ?? ""; remember = store.remembersSchoolAccount }
        .onDisappear { password = ""; loginTask?.cancel() }
    }
}
