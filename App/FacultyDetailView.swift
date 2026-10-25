import CampusCore
import SwiftUI

struct FacultyDetailView: View {
    let name: String
    let detail: String
    let url: URL
    @State private var contact: FacultyContact?
    @State private var busy = false
    @State private var message: String?
    @Environment(CampusStore.self) private var store
    private var cache: URL? {
        guard url.lastPathComponent.range(of: "^[A-Za-z0-9_.-]+$", options: .regularExpression) != nil else { return nil }
        return FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?.appendingPathComponent("FacultyPublic", isDirectory: true).appendingPathComponent(url.lastPathComponent + ".json")
    }
    var body: some View {
        List {
            Section {
                CampusHero(eyebrow: "FACULTY", title: name, subtitle: detail, symbol: "person.crop.square")
            }
            Section("联系方式") {
                if let email = contact?.email {
                    LabeledContent("邮箱") { Text(email).textSelection(.enabled) }
                    if let mail = mailURL(email) { Link(destination: mail) { Label("撰写邮件", systemImage: "envelope") } }
                    ShareLink("复制／分享邮箱", item: email)
                } else { LabeledContent("邮箱", value: busy ? "读取中…" : contact == nil ? "尚未读取" : "未读取到公开信息") }
                LabeledContent("办公室") { Text(contact?.office ?? (busy ? "读取中…" : contact == nil ? "尚未读取" : "未读取到公开信息")).textSelection(.enabled) }
            }
            Section("官方资料") {
                Link("学校教师页面", destination: url)
                if let profile = contact?.profile { Link("教师个人主页", destination: profile) }
                if let date = contact?.fetched { Text("读取于 " + date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary) }
                Button("刷新联系方式", systemImage: "arrow.clockwise") { Task { await load(force: true) } }.disabled(busy)
                if busy { ProgressView() }; ServiceMessage(message: message)
                Text("仅显示官方页面明确公开的邮箱和办公地点；暂未提供时不推测。已读取资料可离线查看。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("教师信息").navigationBarTitleDisplayMode(.inline).task { await load(force: false) }.refreshable { await load(force: true) }
    }
    private func mailURL(_ email: String) -> URL? {
        var components = URLComponents(); components.scheme = "mailto"; components.path = email; return components.url
    }
    private func load(force: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        if contact == nil, let cache, let data = try? Data(contentsOf: cache) { contact = try? JSONDecoder().decode(FacultyContact.self, from: data) }
        if store.mode == .demo {
            contact = FacultyContact(email: "demo-faculty@example.invalid", office: "示例教学楼 203（虚构）"); message = "演示联系方式，不代表真实教师。"; return
        }
        if !force, let contact, Date.now.timeIntervalSince(contact.fetched) < 7 * 86400 { return }
        do {
            let value = try await FacultyContactClient().contact(at: url)
            guard !Task.isCancelled else { return }; contact = value; message = nil
            if let cache {
                try FileManager.default.createDirectory(at: cache.deletingLastPathComponent(), withIntermediateDirectories: true)
                try JSONEncoder().encode(value).write(to: cache, options: .atomic)
            }
        } catch { if !Task.isCancelled { message = contact == nil ? "未能读取官方资料，请重试或打开学校页面。" : "当前显示已缓存资料；刷新失败，请稍后重试。" } }
    }
}
