import CampusCore
import SwiftUI
import WebKit

/// Explicit host allowlists; reads provider-issued token only on its own callback.
struct ProviderBrowser: View {
    enum Kind { case recharge }
    let kind: Kind
    let received: (String) -> Void
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack { ProviderWeb(kind: kind, store: store, received: { value in received(value); dismiss() })
            .navigationTitle("充值授权").navigationBarTitleDisplayMode(.inline)
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
            let entry = URL(string: "https://campuscard.xh.sustech.edu.cn/?pay_money=1/#/PayMoney")!
            view.load(URLRequest(url: entry))
        }; return view
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {}
    @MainActor final class Coordinator: NSObject, WKNavigationDelegate {
        let parent: ProviderWeb; let revision: Int

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
                  ["cas.sustech.edu.cn", "campuscard.xh.sustech.edu.cn", "wechat.xh.sustech.edu.cn"].contains(url.host?.lowercased() ?? "") else { return .cancel }
            return .allow
        }
    }
}
