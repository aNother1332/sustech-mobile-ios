import CampusCore
import SwiftUI

struct CampusHub<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                content
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Color.campusPaper).navigationTitle(title).navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CampusPalette.header, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
    }
}

struct PrintingView: View {
    var initialURL: URL? = nil
    var body: some View {
        if let initialURL { PrintingWorkspaceView(initialURL: initialURL) }
        else {
            CampusHub(title: "校园打印", symbol: "printer") {
                CampusSectionTitle(title: "打印")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ServiceTile(title: "导入PDF", detail: "", symbol: "square.and.arrow.up", color: .campusOrange) { PrintingWorkspaceView(startImport: true) }
                    ServiceTile(title: "任务队列", detail: "", symbol: "printer", color: .campusOrange) { PrintingWorkspaceView() }
                    ServiceTile(title: "打印站点与记录", detail: "", symbol: "mappin.and.ellipse", color: .campusOrange) { PrintExtrasView() }
                    ServiceTile(title: "分享待打印", detail: "", symbol: "tray", color: .campusOrange) { PrintInboxView() }
                }
            }
        }
    }
}

struct LibraryView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        CampusHub(title: "图书馆", symbol: "books.vertical") {
            CampusSectionTitle(title: "我的图书馆")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ServiceTile(title: "我的借阅", detail: "", symbol: "books.vertical", color: .campusOrange) { LibraryLoansView().id(store.sessionRevision) }
                ServiceTile(title: "馆藏与人数", detail: "", symbol: "magnifyingglass", color: .campusOrange) { LibrarySearchView() }
                ServiceTile(title: "IC研讨间", detail: "", symbol: "door.left.hand.open", color: .campusOrange) { ICReservationView().id(store.sessionRevision) }
                ServiceTile(title: "书院场地", detail: "", symbol: "building.2", color: .campusOrange) { CollegeBookingView().id(store.sessionRevision) }
            }
        }
    }
}

struct CardView: View {
    @Environment(CampusStore.self) private var store
    @State private var balance: String?
    @State private var message: String?
    var body: some View {
        CampusHub(title: "校园卡", symbol: "creditcard") {
            if let balance { CampusCard { Text("校园卡余额").font(.caption).foregroundStyle(.secondary); Text(balance).font(.largeTitle.bold()).monospacedDigit() } }
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            CampusSectionTitle(title: "账户服务")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ServiceTile(title: "余额与账单", detail: "", symbol: "creditcard", color: .campusOrange) { CardAccountView().id(store.sessionRevision) }
                ServiceTile(title: "充值", detail: "", symbol: "plus.circle", color: .campusOrange) { CardRechargeView() }
                ServiceTile(title: "校园码", detail: "", symbol: "qrcode", color: .campusOrange) { CampusCodeView().id(store.sessionRevision) }
                ServiceTile(title: "消费曲线", detail: "", symbol: "chart.xyaxis.line", color: .campusOrange) { CardAccountView().id(store.sessionRevision) }
            }
        }.task { await load() }.refreshable { await load() }
    }
    private func load() async {
        if store.mode == .demo { balance = "¥126.80（示例）"; return }
        let version = store.sessionRevision
        let http = await store.serviceHTTP(.card)
        do {
            let value = try await CardClient(http: http).account()
            guard version == store.sessionRevision, store.mode == .live else { return }
            balance = value.balance; store.cardBalance = value.balance; message = nil; store.recordSession(.card)
        } catch { if version == store.sessionRevision { message = "余额未读取，进入余额与账单刷新"; store.recordSession(.card, error: error) } }
        await store.absorb(http, revision: version)
    }
}
