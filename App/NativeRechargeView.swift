import CampusCore
import SwiftUI

struct NativeRechargeView: View {
    @Environment(CampusStore.self) private var store
    @State private var auth: RechargeAuth?
    @State private var identity: RechargeIdentity?
    @State private var amount = "3"
    @State private var draftMessage: String?
    @State private var login = false
    @State private var busy = false
    @State private var message: String?
    var body: some View {
        Form {
            Section("原生充值 · 接口验证") {
                Label(identity == nil ? "充值身份尚未验证" : "已核对充值身份", systemImage: identity == nil ? "person.crop.circle" : "checkmark.circle")
                if let identity { LabeledContent("学号", value: identity.student); LabeledContent("姓名", value: identity.name) }
                Button("检查已有充值授权") { Task { await check() } }.disabled(busy || store.mode == .demo)
                PasteButton(payloadType: String.self) { values in if let value = values.first { Task { await importAuth(value) } } }.disabled(busy || store.mode == .demo)
                Button("学校授权页面") { login = true }.disabled(busy || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
            Section("自定义金额 · 本机草稿") {
                TextField("金额（元）", text: $amount).keyboardType(.decimalPad)
                Button("检查金额格式") {
                    do { draftMessage = "¥" + (try RechargeDraft.normalizedAmount(amount)) + " · 尚未下单" }
                    catch { draftMessage = error.localizedDescription }
                }
                if let draftMessage { Text(draftMessage).font(.caption).foregroundStyle(.secondary) }
            }
            Section {
                Text("正式下单尚未启用").font(.subheadline.bold())
                Text("自定义金额是否被学校接受、单笔订单查询和支付跳转仍待验证。当前金额仅保存在此页面，不会发送充值请求。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("原生充值验证").navigationBarTitleDisplayMode(.inline).task { auth = CredentialVault.load(RechargeAuth.self, key: "recharge-token"); await check() }
        .refreshable { await check() }
        .sheet(isPresented: $login, onDismiss: { Task { await check() } }) {
            ProviderBrowser(kind: .recharge) { raw in
                guard let value = try? JSONDecoder().decode(RechargeAuth.self, from: Data(raw.utf8)), (try? value.validate()) != nil else { return }
                auth = value; try? CredentialVault.save(value, key: "recharge-token")
            }
        }
    }
    private func importAuth(_ raw: String) async {
        do {
            let value = try RechargeAuth.imported(raw)
            auth = value; identity = nil
            try CredentialVault.save(value, key: "recharge-token")
            await check()
        } catch { message = error.localizedDescription }
    }
    private func check() async {
        guard !busy, store.mode == .live else { return }
        identity = nil
        guard let auth else { message = "未取得本 App 可用的充值令牌。外部企业微信登录不会自动将令牌交给这里。"; return }
        busy = true; defer { busy = false }; let version = store.sessionRevision
        do {
            try auth.validate()
            let http = await store.serviceHTTP(origin: URL(string: "https://campuscard.xh.sustech.edu.cn")!)
            let reply = try await http.json("/api/cardInfo/" + auth.cardId, headers: auth.headers)
            let body = reply["data"] == .null ? reply : reply["data"]
            let value = try RechargeDraft.identity(body, auth: auth)
            guard version == store.sessionRevision else { return }; identity = value; message = "充值身份读取成功；仍未启用下单。"
        } catch { guard version == store.sessionRevision else { return }; identity = nil; message = error.localizedDescription }
    }
}
