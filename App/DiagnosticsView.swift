import CampusCore
import Network
import SwiftUI

struct DiagnosticsView: View {
    @State private var values: [(String, String)] = []
    @State private var busy = false
    var body: some View {
        List {
            Section { Text("检测服务可达性，不将网络故障视为登录失效。").font(.caption).foregroundStyle(.secondary); Button("重新检测") { Task { await load() } }.disabled(busy); if busy { ProgressView() } }
            ForEach(Array(values.enumerated()), id: \.offset) { _, row in LabeledContent(row.0, value: row.1) }
            Section { Text("服务可达不能证明位于校内，也不能证明已登录。打印接口在校外或未连接学校 VPN 时可能不可达。").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("网络与服务诊断").navigationBarTitleDisplayMode(.inline).task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }; values = []
        for (name, address) in [("学校认证", "https://cas.sustech.edu.cn/cas/login"), ("校园打印", "https://pms.sustech.edu.cn/client/new/cprintPc/"), ("校车公开服务", "https://buseta.sustcra.com/stops")] {
            do {
                let configuration = URLSessionConfiguration.ephemeral; configuration.timeoutIntervalForRequest = 8
                let (_, response) = try await URLSession(configuration: configuration).data(from: URL(string: address)!)
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
                values.append((name, status == 403 ? "服务拒绝访问（403）" : (200..<400).contains(status) ? "可达" : "已响应（\(status)）"))
            } catch { values.append((name, "不可达／超时")) }
        }
    }
}

struct AppUpdatesView: View {
    @State private var message = "点击检查 GitHub 发布版本"
    @State private var busy = false
    @State private var releaseURL: URL?
    var body: some View {
        List {
            Section { LabeledContent("当前版本", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"); Text(message); Button("检查更新") { Task { await check() } }.disabled(busy); if busy { ProgressView() } }
            if let releaseURL { Link("查看版本与安装文件", destination: releaseURL) }
            Section { Text("侧载版本需下载 IPA 后使用 Windows 签名工具安装；此处不会自动安装或更改证书。").font(.caption).foregroundStyle(.secondary); Link("GitHub Releases", destination: URL(string: "https://github.com/aNother1332/sustech-mobile-ios/releases")!) }
        }.navigationTitle("软件更新").navigationBarTitleDisplayMode(.inline).refreshable { await check() }
    }
    private func check() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do {
            let value = try await ServiceHTTP(origin: URL(string: "https://api.github.com")!).json("/repos/aNother1332/sustech-mobile-ios/releases/latest")
            guard let url = URL(string: value["html_url"].text), url.scheme == "https", url.host == "github.com", url.path.hasPrefix("/aNother1332/sustech-mobile-ios/releases/") else { throw CampusError.invalidResponse("发布版本") }
            releaseURL = url
            let tag = value["tag_name"].text; let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
            let newer = tag.replacingOccurrences(of: "v", with: "").compare(version, options: .numeric) == .orderedDescending
            message = newer ? "有新版本：\(tag)" : "最新公开发布：\(tag)；当前版本无需更新。"
        } catch { message = "暂未查询到公开发布版本，请到 GitHub Releases 核对。" }
    }
}
