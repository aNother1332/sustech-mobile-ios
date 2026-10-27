import CampusCore
import SwiftUI
import UIKit

/// Provider authentication and payment stay in the provider's supported environment.
struct CardRechargeView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var message: String?
    @State private var awaitingReturn = false
    @State private var busy = false
    @State private var account: CardAccount?
    @State private var bills: [CardBill] = []
    @State private var synced: Date?
    private let schoolURL = URL(string: "https://campuscard.xh.sustech.edu.cn/?pay_money=1/#/PayMoney")!
    private let alipayURL = URL(string: "https://ur.alipay.com/_2caU83nozW8S75SNtALLHW")!

    var body: some View {
        List {
            Section {
                Label("校园卡充值", systemImage: "creditcard.fill").font(.title2.bold())
                Text("选择渠道后，在对应平台核对学校、学号、姓名、金额和收款方，再确认付款。")
                if store.mode == .demo {
                    Text("演示模式：不会打开支付入口或查询真实账单。").foregroundStyle(.secondary)
                }
            }
            Section("支付宝") {
                Button("前往支付宝充值", systemImage: "arrow.up.forward.app") { open(alipayURL) }
                    .disabled(store.mode == .demo)
                ShareLink("分享充值链接", item: alipayURL).disabled(store.mode == .demo)
                Text("链接指向预选南方科技大学的支付宝小程序。请在支付宝内核对充值对象和收款方；金额在小程序中填写。").font(.caption).foregroundStyle(.secondary)
            }
            Section("微信 / 企业微信") {
                Button("复制链接并打开企业微信", systemImage: "arrow.up.forward.app") {
                    UIPasteboard.general.url = schoolURL
                    UIApplication.shared.open(URL(string: "wxwork://")!, options: [:]) { opened in
                        message = opened ? "链接已复制，请在企业微信粘贴打开。" : "链接已复制，请手动打开企业微信。"
                    }
                }.disabled(store.mode == .demo)
                ShareLink("分享至微信或企业微信", item: schoolURL).disabled(store.mode == .demo)
                Button("复制学校充值链接", systemImage: "doc.on.doc") {
                    UIPasteboard.general.url = schoolURL
                    message = "已复制。请在企业微信或学校支持的微信环境中打开该链接。"
                }.disabled(store.mode == .demo)
                DetailNote(text: "使用系统分享菜单发送链接，再在对应客户端打开。学校页面可能要求企业微信授权；App 内的学校登录不能代替该授权。")
            }
            Section { NavigationLink("原生下单接口验证") { NativeRechargeView().id(store.sessionRevision) } }
            Section("到账查询") {
                Button("刷新余额与近期账单", systemImage: "arrow.clockwise") { Task { await refresh() } }
                    .disabled(busy || store.mode == .demo)
                if busy { ProgressView() }
                if let account { LabeledContent("当前余额", value: account.balance) }
                if let synced { Text("查询于 \(synced.formatted())").font(.caption).foregroundStyle(.secondary) }
                ServiceMessage(message: message)
                DetailNote(text: "返回 App、支付页面提示或余额变化均不单独作为本次充值成功凭证。请核对平台订单和校园卡到账记录；未确认结果时先查原订单，避免重复付款。")
                ForEach(bills.prefix(10)) { bill in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack { Text(bill.kind); Spacer(); Text(bill.amount).monospacedDigit() }
                        Text(bill.time + " · " + bill.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .refreshable { await refresh() }
        .navigationTitle("校园卡充值").navigationBarTitleDisplayMode(.inline)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, awaitingReturn {
                awaitingReturn = false
                message = "正在刷新到账记录…"
                Task { await refresh() }
            }
        }
        .onChange(of: store.sessionRevision) { _, _ in
            account = nil; bills = []; synced = nil; awaitingReturn = false; message = nil
        }
    }

    private func open(_ url: URL) {
        guard store.mode == .live else { return }
        awaitingReturn = true
        UIApplication.shared.open(url, options: [:]) { opened in
            if !opened {
                awaitingReturn = false
                message = "无法打开充值入口。可以使用分享链接，在支付宝中打开；请确认已安装支付宝。"
            } else {
                message = "已请求打开充值入口，请在支付宝中完成核对。尚未取得付款或到账结果。"
            }
        }
    }

    private func refresh() async {
        guard !busy, store.mode == .live else { return }
        busy = true; defer { busy = false }
        let version = store.sessionRevision
        let http = await store.serviceHTTP(.card)
        let client = CardClient(http: http)
        do {
            let balance = try await client.account()
            guard version == store.sessionRevision else { return }
            account = balance; store.cardBalance = balance.balance; store.recordSession(.card)
            let records = try await client.bills()
            guard version == store.sessionRevision else { return }
            bills = records; synced = .now
            message = "已读取余额与近期账单。这里显示查询结果，不代表已确认某一笔充值订单到账。"
        } catch {
            guard version == store.sessionRevision else { return }
            message = error.localizedDescription
        }
        await store.absorb(http, revision: version)
    }
}
