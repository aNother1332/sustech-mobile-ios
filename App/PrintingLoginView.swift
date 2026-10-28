import CampusCore
import SwiftUI

struct PrintingLoginView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var remember = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        NavigationStack {
            Form {
                Section("打印账号") {
                    TextField("账号", text: $username).textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("打印密码", text: $password).textContentType(.password)
                    Toggle("记住并自动续接", isOn: $remember)
                    Button("登录") {
                        let secret = password; password = ""; busy = true
                        Task { message = await store.signInPrinting(username: username, password: secret, remember: remember); busy = false; if message == nil { dismiss() } }
                    }.disabled(busy || username.isEmpty || password.isEmpty)
                    if busy { ProgressView() }; ServiceMessage(message: message)
                }
            }.navigationTitle("校园打印登录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
            .onAppear { username = CredentialVault.load(RememberedSchoolAccount.self, key: "printing-auto-login")?.username ?? store.rememberedUsername ?? "" }
            .onDisappear { password = "" }
    }
}
