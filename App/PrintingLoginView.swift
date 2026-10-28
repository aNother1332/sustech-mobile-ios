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
                    Toggle("记住并自动续接", isOn: $remember).onChange(of: remember) { _, value in
                        if !value { CredentialVault.delete("printing-auto-login"); UserDefaults.standard.set(true, forKey: "printing-auto-login-paused") }
                    }
                    Button("登录") {
                        let secret = password; let account = username.trimmingCharacters(in: .whitespacesAndNewlines); let save = remember; password = ""; busy = true
                        Task { message = await store.signInPrinting(username: account, password: secret, remember: save); busy = false; if message == nil { dismiss() } }
                    }.disabled(busy || username.isEmpty || password.isEmpty)
                    if busy { ProgressView() }; ServiceMessage(message: message)
                }.disabled(busy)
            }.navigationTitle("校园打印登录").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() }.disabled(busy) } }
        }.interactiveDismissDisabled(busy)
            .onAppear {
                let saved = CredentialVault.load(RememberedSchoolAccount.self, key: "printing-auto-login")
                username = saved?.username ?? store.rememberedUsername ?? ""; remember = saved != nil
            }
            .onDisappear { password = "" }
    }
}
