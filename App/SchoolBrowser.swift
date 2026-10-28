import CampusCore
import SwiftUI
import WebKit

struct SchoolBrowser: View {
    let service: SchoolService
    var initialURL: URL? = nil
    var ephemeral = false
    @State private var transientStore = WKWebsiteDataStore.nonPersistent()
    private var entryURL: URL { initialURL ?? service.portalURL }
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var browserState = BrowserState()
    @State private var ready = false
    @State private var preparing = true

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Label(browserState.host, systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary).padding(8)
                if let failure = browserState.failure {
                    Text(failure).font(.callout).foregroundStyle(.orange).padding()
                }
                if ready {
                    BrowserWebView(url: entryURL, dataStore: ephemeral ? transientStore : store.websiteDataStore, state: browserState, sessions: store.sessions)
                } else if preparing { ProgressView("正在准备学校页面…").frame(maxWidth: .infinity, maxHeight: .infinity) }
                else { ContentUnavailableView("暂时无法打开登录页面", systemImage: "lock", description: Text("请解锁设备，关闭页面后重新打开。")) }
            }
            .navigationTitle(service.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: entryURL) { Image(systemName: "safari") }
                        .accessibilityLabel("在系统浏览器打开学校页面")
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack {
                        Button("缩小", systemImage: "minus.magnifyingglass") { browserState.zoom = max(0.3, browserState.zoom - 0.15) }
                        Spacer()
                        EmptyView()
                        Spacer()
                        Button("放大", systemImage: "plus.magnifyingglass") { browserState.zoom = min(2, browserState.zoom + 0.15) }
                    }
                    EmptyView()
                    .font(.caption).foregroundStyle(.secondary)
                }
                    .frame(maxWidth: .infinity).padding().background(.regularMaterial)
            }
            .task {
                let prepared = await store.prepareSchoolBrowser(service)
                if ephemeral { for cookie in await store.sessions.cookies() { await transientStore.httpCookieStore.setCookie(cookie) } }
                ready = prepared
                preparing = false
                if !ready { browserState.failure = store.cacheMessage ?? "其他会话操作尚未结束，请稍后重试。" }
            }
        }
        .interactiveDismissDisabled(store.clearing)
        .onDisappear { Task {
            if service == .card { await store.checkSession(.card, force: true) }
            if service == .printing { await store.checkSession(.printing, force: true) }
            await store.checkSchoolSessions(force: true)
        } }
    }
}

@MainActor
@Observable
final class BrowserState {
    var host = "学校官方网站"
    var failure: String?
    var zoom = 0.75
}

struct BrowserWebView: UIViewRepresentable {
    let url: URL
    let dataStore: WKWebsiteDataStore
    let state: BrowserState
    let sessions: SchoolSessions

    func makeCoordinator() -> Coordinator { Coordinator(state: state, sessions: sessions) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.defaultWebpagePreferences.preferredContentMode = .desktop
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        view.uiDelegate = context.coordinator
        view.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 Version/17.0 Safari/605.1.15"
        view.allowsBackForwardNavigationGestures = true
        view.scrollView.isScrollEnabled = true
        view.pageZoom = state.zoom
        view.load(URLRequest(url: url))
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) { if view.pageZoom != state.zoom { view.pageZoom = state.zoom } }

    static func dismantleUIView(_ view: WKWebView, coordinator: Coordinator) {
        view.stopLoading()
        view.navigationDelegate = nil
        view.uiDelegate = nil
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private let state: BrowserState
        private let sessions: SchoolSessions
        init(state: BrowserState, sessions: SchoolSessions) { self.state = state; self.sessions = sessions }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            captureIdentity(webView, attempts: 20, epoch: sessions.epoch)
        }
        private func captureIdentity(_ webView: WKWebView, attempts: Int, epoch: Int) {
            guard webView.url?.host == "ehall.sustech.edu.cn" else { return }
            guard sessions.epoch == epoch else { return }
            webView.evaluateJavaScript("JSON.stringify({id: String(window.userId || ''), name: String(window.userName || '')})") { [weak self, weak webView] value, _ in
                if let text = value as? String, let data = text.data(using: .utf8),
                   let fields = try? JSONDecoder().decode([String: String].self, from: data), let id = fields["id"], !id.isEmpty {
                    self?.sessions.setCLEIdentity(id: id, name: fields["name"] ?? "", epoch: epoch)
                } else if attempts > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self, weak webView] in
                        guard let webView else { return }
                        self?.captureIdentity(webView, attempts: attempts - 1, epoch: epoch)
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .cancel }
            if url.absoluteString == "about:blank" { return .allow }
            let host = url.host?.lowercased() ?? ""
            let official = host == "sustech.edu.cn" || host.hasSuffix(".sustech.edu.cn")
            guard url.scheme == "https", official else {
                state.failure = "此链接离开学校 HTTPS 网站。请使用右侧系统浏览器入口继续；第三方支付跳转尚待真机验证。"
                return .cancel
            }
            state.failure = nil
            state.host = host
            return .allow
        }

        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            if navigationAction.targetFrame == nil { webView.load(navigationAction.request) }
            return nil
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            if (error as NSError).code != NSURLErrorCancelled {
                state.failure = "页面未能加载。请检查网络；部分服务需要校内网络或学校认可的访问方式。"
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            state.failure = "页面加载中断，请关闭后重新打开。"
        }
    }
}
