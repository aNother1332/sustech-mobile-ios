import CampusCore
import SwiftUI
import WebKit

struct LibrarySearchView: View {
    @Environment(CampusStore.self) private var store
    @State private var query = ""
    @State private var books: [LibraryBook] = []
    @State private var occupancy: LibraryOccupancy?
    @State private var message: String?
    @State private var busy = false
    @State private var searched = false
    @State private var offset = 0
    @State private var more = false
    @AppStorage("favorite-books") private var saved = "[]"
    private let http = ServiceHTTP(origin: LibraryClient.origin)
    var body: some View {
        List {
            Section {
                CampusHero(eyebrow: "LIBRARY", title: "图书馆", subtitle: "馆藏 · 借阅 · 校园阅读", symbol: "books.vertical.fill")
                ModeNotice()
                NavigationLink { LibraryLoansView().id(store.sessionRevision) } label: { Label("我的借阅与续借", systemImage: "books.vertical") }
                HStack {
                    Text(occupancy?.total.map { "在馆 \($0) 人" } ?? "人数未读取")
                    Spacer(); Text(occupancy?.hours ?? "").font(.caption)
                }
                if let occupancy { ForEach(occupancy.buildings.keys.sorted(), id: \.self) { key in LabeledContent(key, value: "\(occupancy.buildings[key] ?? 0) 人") } }
                DetailNote(text: "人数为学校网页快照，不代表空座。馆藏可借状态以实际借阅为准。收藏保存在本机。")
                ServiceMessage(message: message)
            }
            Section(searched ? "馆藏 · \(books.count) 项" : "搜索馆藏") {
                if busy { ProgressView() }
                ForEach(books) { book in
                    NavigationLink { LibraryBookView(book: book, client: LibraryClient(http: http)) } label: {
                        VStack(alignment: .leading, spacing: 3) { Text(book.title).font(.subheadline.bold()); Text(book.author + " · " + book.year).font(.caption).foregroundStyle(.secondary) }
                    }.swipeActions { Button(isSaved(book) ? "取消收藏" : "收藏") { toggle(book) }.tint(.campusGreen) }
                }
                if more { Button("加载更多") { Task { await search(append: true) } }.disabled(busy) }
                if searched && books.isEmpty && !busy { Text("未找到匹配馆藏") }
            }
            let favorites = (try? JSONDecoder().decode([SavedBook].self, from: Data(saved.utf8))) ?? []
            if !favorites.isEmpty { Section("收藏书目") { ForEach(favorites) { book in
                Button(book.title) { query = book.title; Task { await search() } }.swipeActions { Button("移除", role: .destructive) { var all = favorites; all.removeAll { $0.id == book.id }; save(all) } }
            } } }
        }.navigationTitle("图书馆").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "书名、作者或 ISBN").onSubmit(of: .search) { Task { await search() } }
        .refreshable { await loadOccupancy(); if searched { await search() } }
        .task {
            if store.mode == .demo {
                let data = Data(#"{"docs":[{"pnx":{"control":{"recordid":["demo-book-1"]},"display":{"title":["线性代数（虚构示例）"],"creator":["示例作者"],"creationdate":["2026"]}}},{"pnx":{"control":{"recordid":["demo-book-2"]},"display":{"title":["信号与系统（虚构示例）"],"creator":["示例作者"],"creationdate":["2026"]}}}]}"#.utf8)
                if let value = try? JSONDecoder().decode(WireValue.self, from: data) { books = (try? LibraryClient.books(value)) ?? [] }; searched = true
                message = "虚构馆藏示例；人数与个人借阅未连接。"
            } else { await loadOccupancy() }
        }
    }
    private struct SavedBook: Identifiable, Codable { var id: String; var title: String }
    private func save(_ value: [SavedBook]) { if let data = try? JSONEncoder().encode(value) { saved = String(decoding: data, as: UTF8.self) } }
    private func isSaved(_ book: LibraryBook) -> Bool { ((try? JSONDecoder().decode([SavedBook].self, from: Data(saved.utf8))) ?? []).contains { $0.id == book.id } }
    private func toggle(_ book: LibraryBook) {
        guard store.mode == .live else { return }
        var all = (try? JSONDecoder().decode([SavedBook].self, from: Data(saved.utf8))) ?? []
        if all.contains(where: { $0.id == book.id }) { all.removeAll { $0.id == book.id } } else { all.append(SavedBook(id: book.id, title: book.title)) }; save(all)
    }
    private func search(append: Bool = false) async {
        guard store.mode == .live, !busy, !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }; busy = true; defer { busy = false }
        let text = query; let next = append ? offset + 20 : 0
        do { let value = try await LibraryClient(http: http).search(text, offset: next)
            guard text == query else { return }; offset = next; more = value.count == 20
            books = append ? books + value.filter { new in !books.contains { $0.id == new.id } } : value; searched = true; message = nil
        } catch { message = error.localizedDescription }
    }
    private func loadOccupancy() async {
        guard store.mode == .live else { return }
        do { let data = try await ServiceHTTP(origin: URL(string: "https://lib.sustech.edu.cn")!).data("/main.htm"); occupancy = LibraryClient.occupancy(String(decoding: data, as: UTF8.self)) }
        catch { message = "人数暂不可用：" + error.localizedDescription }
    }
}
private struct LibraryBookView: View {
    let book: LibraryBook; let client: LibraryClient
    @State private var holdings: [LibraryHolding] = []
    @State private var message: String?
    var body: some View {
        List {
            Section { Text(book.title).font(.headline); Text(book.author + " · " + book.year).font(.caption) }
            Section("馆藏位置") { ForEach(holdings) { item in VStack(alignment: .leading, spacing: 3) { Text(item.location); Text(item.callNumber + " · " + item.status).font(.caption).foregroundStyle(.secondary) } } }
            ServiceMessage(message: message)
        }.navigationTitle("馆藏详情").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
    }
    private func load() async { do { holdings = try await client.holdings(book); message = holdings.isEmpty ? "未返回纸质馆藏位置，可能为电子资源；请到学校页面核对。" : nil } catch { message = error.localizedDescription } }
}

struct LibraryLoansView: View {
    @Environment(CampusStore.self) private var store
    @State private var loans: [LibraryLoan] = []
    @State private var token = ""
    @State private var message: String?
    @State private var busy = false
    @State private var login = false
    @State private var expired = false
    @State private var verified = false
    @State private var renew: LibraryLoan?
    var body: some View {
        List {
            Section {
                if busy { ProgressView() }
                Label(busy ? "检测中" : (expired ? "图书馆需连接" : (verified ? "图书馆已连接" : "连接未验证")), systemImage: expired ? "person.badge.key" : "checkmark.circle")
                if expired { Button("连接图书馆") { login = true }.disabled(store.mode == .demo) }
                ServiceMessage(message: message)
            }
            ForEach(loans) { loan in
                VStack(alignment: .leading, spacing: 4) {
                    Text(loan.title).font(.subheadline.bold())
                    Text("到期：" + loan.due).font(.caption).foregroundStyle(.orange)
                    Text(loan.location).font(.caption).foregroundStyle(.secondary)
                    HStack {
                        Button("续借") { renew = loan }.disabled(busy || store.mode == .demo)
                        if let due = CampusClock.date(String(loan.due.prefix(10))) { NavigationLink("到期提醒") { EventActionView(title: "归还：" + loan.title, start: due, end: due.addingTimeInterval(3600), key: "loan-" + loan.id) } }
                    }.font(.caption)
                }
            }
            if loans.isEmpty && !busy && !expired { Text("本次未读取到在借记录") }
        }.navigationTitle("我的借阅").navigationBarTitleDisplayMode(.inline).task { token = CredentialVault.load(String.self, key: "library-token") ?? ""; await load() }
        .refreshable { await load() }
        .sheet(isPresented: $login, onDismiss: { Task { await load() } }) {
            ProviderBrowser(kind: .library) { value in token = value; expired = false; try? CredentialVault.save(value, key: "library-token") }
        }
        .campusConfirmation("续借《\(renew?.title ?? "")》？", isPresented: Binding(get: { renew != nil }, set: { if !$0 { renew = nil } }), titleVisibility: .visible) {
            if let loan = renew { Button("确认续借一次") { renew = nil; Task { await performRenew(loan) } } }
        } message: { Text("学校决定是否允许续借；提交后核对新的到期日期。") }
    }
    private func client() async -> LibraryClient { LibraryClient(http: await store.serviceHTTP(origin: LibraryClient.origin)) }
    private func load() async {
        guard !busy, store.mode == .live else { return }
        busy = true; defer { busy = false }; let version = store.sessionRevision
        do {
            if token.isEmpty { token = try await store.sessions.connectLibrary() }
            let value: [LibraryLoan]
            do { value = try await client().loans(token: token) }
            catch CampusError.signInRequired { token = try await store.sessions.connectLibrary(); value = try await client().loans(token: token) }
             guard version == store.sessionRevision else { return }; loans = value; expired = false; verified = true; message = value.count == 50 ? "当前显示前 50 条在借记录。" : nil }
        catch { guard version == store.sessionRevision else { return }; verified = false; expired = (error as? CampusError) == .signInRequired; if expired { token = ""; CredentialVault.delete("library-token") }; message = error.localizedDescription }
    }
    private func performRenew(_ loan: LibraryLoan) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        do { let client = await client(); try await client.renew(loan, token: token); let value = try await client.loans(token: token); loans = value
            message = value.first(where: { $0.id == loan.id }).map { "学校返回到期日：" + $0.due } ?? "未在当前借阅列表找到该书，请核对学校记录。"
        } catch { if (error as? CampusError) == .signInRequired { expired = true; verified = false }; message = "续借结果需核对：" + error.localizedDescription }
    }
}

/// Explicit host allowlists; reads provider-issued token only on its own callback.
struct ProviderBrowser: View {
    enum Kind { case library, recharge }
    let kind: Kind
    let received: (String) -> Void
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ProviderWeb(kind: kind, store: store, received: { value in received(value); dismiss() })
            .navigationTitle(kind == .library ? "图书馆连接" : "充值授权").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}
private struct ProviderWeb: UIViewRepresentable {
    let kind: ProviderBrowser.Kind; let store: CampusStore; let received: (String) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration(); configuration.websiteDataStore = store.websiteDataStore
        let view = WKWebView(frame: .zero, configuration: configuration); view.navigationDelegate = context.coordinator
        view.customUserAgent = CASPolicy.userAgent
        Task { await store.sessions.restore()
            let entry: URL
            if kind == .library {
                var parts = URLComponents(string: "https://sustc.primo.exlibrisgroup.com.cn/primaws/suprimaExtLogin")!
                parts.queryItems = [URLQueryItem(name: "institution", value: "86SUSTC_INST"), URLQueryItem(name: "lang", value: "zh-CN"), URLQueryItem(name: "target-url", value: "https://sustc.primo.exlibrisgroup.com.cn/discovery/account?vid=86SUSTC_INST:86SUSTC&section=loans&lang=zh-CN&fromLogin=true"), URLQueryItem(name: "authenticationProfile", value: "CAS2"), URLQueryItem(name: "idpCode", value: "CAS2"), URLQueryItem(name: "auth", value: "CAS"), URLQueryItem(name: "view", value: LibraryClient.view), URLQueryItem(name: "isSilent", value: "false")]
                entry = parts.url!
            } else { entry = URL(string: "https://campuscard.xh.sustech.edu.cn/?pay_money=1/#/PayMoney")! }
            view.load(URLRequest(url: entry))
        }; return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ProviderWeb; let revision: Int
        private var minting = false
        init(_ parent: ProviderWeb) { self.parent = parent; revision = parent.store.sessionRevision }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard parent.kind == .recharge, let url = webView.url,
                  url.scheme == "https", url.host == "campuscard.xh.sustech.edu.cn", url.port == nil || url.port == 443,
                  url.user == nil, url.password == nil, revision == parent.store.sessionRevision else { return }
            Task {
                let raw = try? await webView.evaluateJavaScript("JSON.stringify({userId:sessionStorage.getItem('userId')||'',cardId:sessionStorage.getItem('cardId')||'',token:sessionStorage.getItem('token')||''})")
                guard let text = raw as? String, let current = webView.url,
                      current.scheme == "https", current.host == "campuscard.xh.sustech.edu.cn", current.user == nil, current.password == nil,
                      current.port == nil || current.port == 443, revision == parent.store.sessionRevision,
                      let auth = try? JSONDecoder().decode(RechargeAuth.self, from: Data(text.utf8)), (try? auth.validate()) != nil else { return }
                parent.received(text)
            }
        }
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url, url.scheme == "https", url.user == nil, url.password == nil, url.port == nil || url.port == 443,
                  ["sustc.primo.exlibrisgroup.com.cn", "cas.sustech.edu.cn", "campuscard.xh.sustech.edu.cn", "wechat.xh.sustech.edu.cn"].contains(url.host?.lowercased() ?? "") else { return .cancel }
            if parent.kind == .library, url.host == "sustc.primo.exlibrisgroup.com.cn", !minting,
               let login = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first(where: { $0.name == "loginId" })?.value,
               login.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil {
                minting = true
                Task {
                    do {
                        let http = await parent.store.serviceHTTP(origin: LibraryClient.origin)
                        let data = try await http.data("/primaws/rest/pub/loginJwtCache/" + login, query: ["vid": LibraryClient.view])
                        let token = String(decoding: data, as: UTF8.self).trimmingCharacters(in: CharacterSet(charactersIn: "\" \r\n"))
                        guard token.hasPrefix("eyJ"), revision == parent.store.sessionRevision else { return }
                        parent.received(token)
                    } catch { minting = false }
                }
            }
            return .allow
        }
    }
}
