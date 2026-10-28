import CampusCore
import WebKit

/// Runs the school's own EMAP initialization in the shared on-device cookie jar.
/// It submits no credentials or business operations.
@MainActor
final class SchoolWebBootstrap: NSObject, WKNavigationDelegate {
    private var webView: WKWebView?
    private var continuation: CheckedContinuation<CLEIdentity, Error>?
    private var deadline: Task<Void, Never>?
    private var sampling = false
    func establish(in store: WKWebsiteDataStore) async throws -> CLEIdentity {
        sampling = false
        let config = WKWebViewConfiguration(); config.websiteDataStore = store
        let view = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 700), configuration: config)
        view.customUserAgent = CASPolicy.userAgent; view.navigationDelegate = self; webView = view
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                deadline = Task { @MainActor [weak self] in
                    do { try await Task.sleep(for: .seconds(25)) } catch { return }
                    self?.finish(.failure(ServiceFailure("CLE 连接超时")))
                }
                view.load(URLRequest(url: CLEClient.index))
            }
        } onCancel: { Task { @MainActor [weak self] in self?.finish(.failure(CancellationError())) } }
    }
    private func finish(_ result: Result<CLEIdentity, Error>) {
        guard let pending = continuation else { return }; continuation = nil
        deadline?.cancel(); deadline = nil; webView?.stopLoading(); webView?.navigationDelegate = nil; webView = nil
        pending.resume(with: result)
    }
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        guard let url = navigationAction.request.url, SessionConnector.allowed(url) else { return .cancel }
        return .allow
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard webView.url?.host == "ehall.sustech.edu.cn" else {
            if webView.url?.host == CASPolicy.login.host { finish(.failure(CampusError.signInRequired)) }; return
        }
        guard !sampling else { return }; sampling = true
        Task { @MainActor [weak self, weak webView] in
            guard let self, let webView else { return }
            do {
                let script = """
                for (let attempt = 0; attempt < 8; attempt++) {
                  const response = await fetch('/dxggyw/sys/yyzxyy/modules/fwyy/T_NKD_YYZX_FWPZ_QUERY.do?pageSize=1&pageNumber=1&SFZZSY=1', {credentials:'include', headers:{'X-Requested-With':'XMLHttpRequest'}});
                  if (response.ok) {
                    const value = await response.json();
                    if (String(value.code) === '0') return JSON.stringify({id:String(window.userId || ''),name:String(window.userName || '')});
                  }
                  await new Promise(resolve => setTimeout(resolve, 700));
                }
                throw new Error('CLE bootstrap unavailable');
                """
                let result = try await webView.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .page)
                guard let string = result as? String, let data = string.data(using: .utf8),
                      let value = try? JSONDecoder().decode(WireValue.self, from: data), !value["id"].text.isEmpty else { throw ServiceFailure("CLE 连接暂不可用") }
                self.finish(.success(CLEIdentity(id: value["id"].text, name: value["name"].text)))
            } catch { self.finish(.failure(ServiceFailure("CLE 连接暂不可用"))) }
        }
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { finish(.failure(ServiceFailure("CLE 网络不可用"))) }
}
