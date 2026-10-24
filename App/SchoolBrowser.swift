import CampusCore
import SwiftUI
import WebKit

struct SchoolBrowser: View {
    let service: SchoolService
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var browserState = BrowserState()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Label(browserState.host, systemImage: "lock.shield")
                    .font(.caption).foregroundStyle(.secondary).padding(8)
                if let failure = browserState.failure {
                    Text(failure).font(.callout).foregroundStyle(.orange).padding()
                }
                BrowserWebView(url: service.portalURL, dataStore: store.websiteDataStore, state: browserState)
            }
            .navigationTitle(service.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Link(destination: service.portalURL) { Image(systemName: "safari") }
                        .accessibilityLabel("在系统浏览器打开学校页面")
                }
                ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    HStack {
                        Button("缩小", systemImage: "minus.magnifyingglass") { browserState.zoom = max(0.3, browserState.zoom - 0.15) }
                        Spacer()
                        Text("桌面网页 · 可双指缩放").font(.caption)
                        Spacer()
                        Button("放大", systemImage: "plus.magnifyingglass") { browserState.zoom = min(2, browserState.zoom + 0.15) }
                    }
                    Text("完成学校登录后，返回应用手动同步。系统浏览器与应用会话不同；打开网页前会清除旧缓存。")
                    .font(.caption).foregroundStyle(.secondary)
                }
                    .frame(maxWidth: .infinity).padding().background(.regularMaterial)
            }
            .onAppear { store.prepareSchoolBrowser(service) }
        }
        .interactiveDismissDisabled(store.clearing)
    }
}

@MainActor
@Observable
final class BrowserState {
    var host = "学校官方网站"
    var failure: String?
    var zoom = 0.75
}

private struct BrowserWebView: UIViewRepresentable {
    let url: URL
    let dataStore: WKWebsiteDataStore
    let state: BrowserState

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

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
        init(state: BrowserState) { self.state = state }

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
