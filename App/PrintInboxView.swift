import SwiftUI

struct PrintInboxView: View {
    @State private var files: [URL] = []
    @State private var message: String?
    var body: some View {
        List {
            if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
            ForEach(files, id: \.self) { url in NavigationLink { PrintingView(initialURL: url) } label: { Label(url.lastPathComponent, systemImage: "doc") }.swipeActions {
                Button("移除", role: .destructive) { do { try FileManager.default.removeItem(at: url); files.removeAll { $0 == url } } catch { message = "无法移除文件，请解锁设备后重试。" } }
            } }
            if files.isEmpty { ContentUnavailableView("没有待打印 PDF", systemImage: "tray", description: Text("也可在校园打印中直接导入 PDF。")) }
        }.navigationTitle("系统分享待打印").task { load() }.refreshable { load() }
    }
    private func load() {
        guard let group = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.cn.sustech.community.daily") else { message = "当前签名没有共享容器；系统分享版需单独验证签名能力。"; return }
        let root = group.appendingPathComponent("PrintInbox", isDirectory: true)
        guard let iterator = FileManager.default.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { files = []; return }
        files = iterator.compactMap { $0 as? URL }.filter { $0.pathExtension.lowercased() == "pdf" && (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        message = "仅接收文件，不自动上传。请选择文件并核对打印参数。"
    }
}
