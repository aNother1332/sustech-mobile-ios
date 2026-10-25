import CampusCore
import SwiftUI

struct CandidateClassesView: View {
    let choose: (CandidateClass) -> Void
    @Environment(CampusStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var classes: [CandidateClass] = []
    @State private var page = 1
    @State private var busy = false
    @State private var more = false
    @State private var message: String?
    @AppStorage("candidate-class-favorites-v1") private var saved = "[]"
    private var favorites: [CandidateClass] { (try? JSONDecoder().decode([CandidateClass].self, from: Data(saved.utf8))) ?? [] }
    var body: some View {
        List {
            Section { SessionBadge(); Text("只查询教学班并加入本地方案，不执行学校选课。").font(.caption).foregroundStyle(.secondary); ServiceMessage(message: message); if busy { ProgressView() } }
            if !favorites.isEmpty { Section("收藏教学班 · 时段为收藏时快照") { ForEach(favorites) { item in row(item) } } }
            Section("候选教学班") { ForEach(classes) { item in row(item) }; if more { Button("加载更多") { Task { await load(append: true) } }.disabled(busy) } }
        }.navigationTitle("候选课程").searchable(text: $query, prompt: "课程名称、代码或教师")
        .onSubmit(of: .search) { Task { await load() } }.refreshable { await load() }
    }
    private func row(_ item: CandidateClass) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name + " · " + item.code).font(.subheadline.bold())
            Text(item.teachers + " · \(item.credits.formatted()) 学分").font(.caption).foregroundStyle(.secondary)
            Text(item.schedule.isEmpty ? "学校未返回时段" : item.schedule).font(.caption)
            HStack {
                Button("加入当前方案") { choose(item); dismiss() }.disabled(item.slots.isEmpty)
                Spacer()
                Button(favorites.contains { $0.id == item.id } ? "取消收藏" : "收藏") {
                    var values = favorites
                    if values.contains(where: { $0.id == item.id }) { values.removeAll { $0.id == item.id } } else { values.append(item) }
                    if let data = try? JSONEncoder().encode(values) { saved = String(decoding: data, as: UTF8.self) }
                }
            }.font(.caption).buttonStyle(.borderless)
        }
    }
    private func load(append: Bool = false) async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }; let version = store.sessionRevision
        let http = await store.serviceHTTP(.teaching); let next = append ? page + 1 : 1; let text = query
        do { let value = try await CandidateClient(http: http).search(text, page: next); guard version == store.sessionRevision, text == query else { return }; classes = append ? classes + value.filter { row in !classes.contains { $0.id == row.id } } : value; page = next; more = value.count == 20; message = nil }
        catch { guard version == store.sessionRevision else { return }; message = error.localizedDescription }
        await store.absorb(http, revision: version)
    }
}
