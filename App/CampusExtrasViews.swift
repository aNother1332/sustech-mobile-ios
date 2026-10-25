import CampusCore
import CoreImage.CIFilterBuiltins
import SwiftUI
import WebKit

struct CampusCodeView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var phase
    @State private var kind = CardCodeKind.campus
    @State private var image: UIImage?
    @State private var expires = Date.distantPast
    @State private var message: String?
    @State private var busy = false
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CampusHero(eyebrow: "CAMPUS PASS", title: kind.rawValue, subtitle: "学校动态码 · 仅在前台展示有效内容", symbol: "qrcode")
                SessionBadge(service: .card)
                Picker("码类型", selection: $kind) { ForEach(CardCodeKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented)
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(spacing: 12) {
                        if let image, context.date < expires, phase == .active {
                            Image(uiImage: image).interpolation(.none).resizable().scaledToFit().padding(20).background(.white).clipShape(RoundedRectangle(cornerRadius: 18)).frame(maxWidth: 340).accessibilityLabel(kind.rawValue)
                            Text("\(max(0, Int(expires.timeIntervalSince(context.date)))) 秒后刷新").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                        } else { ContentUnavailableView(store.mode == .demo ? "演示不生成可用校园码" : "校园码已隐藏或待刷新", systemImage: "qrcode", description: Text("刷新成功后显示，过期内容不保留。")) }
                    }
                }
                Button("刷新" , systemImage: "arrow.clockwise") { Task { await load() } }.buttonStyle(.borderedProminent).disabled(busy || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
                Text("校园码与身份码用途以学校说明及终端支持为准；无法添加到 Apple Wallet。请勿分享截图。").font(.caption).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: 640).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("校园码").navigationBarTitleDisplayMode(.inline)
            .refreshable { await load() }
            .task(id: kind) {
                image = nil; await load()
                while !Task.isCancelled {
                    do { try await Task.sleep(for: .seconds(kind.lifetime)) } catch { return }
                    if phase == .active { await load() }
                }
            }
            .onChange(of: phase) { _, value in image = nil; expires = .distantPast; if value == .active { Task { await load() } } }
            .onChange(of: store.sessionRevision) { _, _ in image = nil; expires = .distantPast }
            .onDisappear { image = nil; expires = .distantPast }
    }
    private func load() async {
        guard !busy, store.mode == .live, phase == .active else { return }; busy = true; image = nil; defer { busy = false }
        let revision = store.sessionRevision; let selected = kind; let http = await store.serviceHTTP(.card)
        do {
            let text = try await CardCodeClient(http: http).code(selected)
            guard revision == store.sessionRevision, selected == kind, phase == .active, !Task.isCancelled else { return }
            let filter = CIFilter.qrCodeGenerator(); filter.message = Data(text.utf8); filter.correctionLevel = "Q"
            guard let output = filter.outputImage, let cg = CIContext().createCGImage(output.transformed(by: CGAffineTransform(scaleX: 10, y: 10)), from: output.extent.applying(CGAffineTransform(scaleX: 10, y: 10))) else { throw ServiceFailure("二维码生成失败。") }
            image = UIImage(cgImage: cg); expires = .now.addingTimeInterval(selected.lifetime); message = nil; store.recordSession(.card)
        } catch { guard revision == store.sessionRevision else { return }; message = error.localizedDescription; store.recordSession(.card, error: error) }
        await store.absorb(http, revision: revision)
    }
}

struct FacultyDirectoryView: View {
    struct Person: Identifiable { let id: Int; let name: String; let detail: String; let search: String; let url: URL }
    @State private var query = ""
    @State private var people: [Person] = []
    @State private var generated = ""
    var body: some View {
        List {
            Section { Text("学校公开教师目录 · 离线快照").font(.subheadline.bold()); Text("资料更新：" + generated).font(.caption).foregroundStyle(.secondary) }
            ForEach(people.filter { query.isEmpty || $0.search.localizedCaseInsensitiveContains(query) }) { person in
                NavigationLink { FacultyDetailView(name: person.name, detail: person.detail, url: person.url) } label: { HStack(spacing: 12) { Image(systemName: "person.crop.square").foregroundStyle(Color.campusGreen).font(.title2); VStack(alignment: .leading, spacing: 4) { Text(person.name).foregroundStyle(.primary).font(.subheadline.bold()); Text(person.detail).font(.caption).foregroundStyle(.secondary) }; Spacer(); Image(systemName: "info.circle").font(.caption).foregroundStyle(.secondary) } }
            }
            if people.isEmpty { Text("目录资源暂不可读。") }
        }.navigationTitle("教师目录").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "中英文姓名、院系、职称").task { load() }
    }
    private func load() {
        guard let url = Bundle.main.url(forResource: "faculty_directory", withExtension: "json"), let data = try? Data(contentsOf: url), let value = try? JSONDecoder().decode(WireValue.self, from: data) else { return }
        generated = value["generatedAt"].text
        people = value["records"].rows.enumerated().compactMap { index, row in
            guard let url = URL(string: row["url"].text), url.scheme == "https", url.host == "www.sustech.edu.cn", url.path.hasPrefix("/zh/faculties/") else { return nil }
            let names = [row["nameZh"].text, row["nameEn"].text].filter { !$0.isEmpty }.joined(separator: " · ")
            let details = [row["departmentZh"].text, row["titleZh"].text].filter { !$0.isEmpty }.joined(separator: " · ")
            return Person(id: index, name: names, detail: details, search: names + details + row["departmentEn"].text + row["titleEn"].text, url: url)
        }
    }
}

struct ExchangeProgramsView: View {
    @Environment(CampusStore.self) private var store
    @State private var items: [ExchangeProgram] = []
    @State private var page = 0
    @State private var total = 0
    @State private var busy = false
    @State private var message: String?
    @State private var query = ""
    @State private var onlyOpen = false
    @State private var portal = false
    @State private var detail: ExchangeProgram?
    var body: some View {
        List {
            Section {
                Toggle("仅看可申请项目", isOn: $onlyOpen)
                Button("官方交换平台") { portal = true }
                ServiceMessage(message: message); if busy { ProgressView() }
            }
            if store.mode == .demo {
                Section("虚构示例 · 不代表真实开放项目") {
                    ForEach(["暑期交流项目", "学期交换项目"], id: \.self) { name in
                        VStack(alignment: .leading, spacing: 6) { Text("示例 · " + name).font(.subheadline.bold()); Text("示例地区 · 示例合作学校").font(.caption).foregroundStyle(.secondary); Label("示例：申请窗口内", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(Color.campusGreen); Text("真实项目时间、资格与申请以官方平台为准").font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
            ForEach(items.filter { (!onlyOpen || $0.available) && (query.isEmpty || ($0.name + $0.location).localizedCaseInsensitiveContains(query)) }) { item in
                Button { detail = item } label: { VStack(alignment: .leading, spacing: 6) {
                    Text(item.name).font(.subheadline.bold()).foregroundStyle(.primary)
                    Text(item.location).font(.caption).foregroundStyle(.secondary)
                    Label(item.status.isEmpty ? (item.available ? "可申请" : "请核对申请状态") : item.status, systemImage: item.available ? "checkmark.circle.fill" : "clock").font(.caption).foregroundStyle(item.available ? Color.campusGreen : .secondary)
                    Text(item.range).font(.caption).foregroundStyle(.secondary)
                } }
            }
            if items.count < total { Button("加载更多 · \(items.count)/\(total)") { Task { await load(reset: false) } }.disabled(busy) }
        }.navigationTitle("交换项目").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "在已加载项目中搜索学校、地区")
            .task { await load(reset: true) }.refreshable { await load(reset: true) }
            .sheet(isPresented: $portal, onDismiss: { Task { await load(reset: true) } }) { SchoolBrowser(service: .exchange) }
            .sheet(item: $detail) { item in SchoolBrowser(service: .exchange, initialURL: item.url) }
    }
    private func load(reset: Bool) async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let origin = URL(string: "https://ws.sustech.edu.cn")!
        do {
            try await store.sessions.connect(entry: URL(string: "https://cas.sustech.edu.cn/cas/login?service=https%3A%2F%2Fws.sustech.edu.cn%2FSUSTechHome.aspx")!, finalHost: origin.host)
            let http = await store.serviceHTTP(origin: origin)
            do { let next = reset ? 1 : page + 1; let value = try await ExchangeClient(http: http).programs(page: next); guard version == store.sessionRevision else { return }; items = reset ? value.items : items + value.items.filter { row in !items.contains { $0.id == row.id } }; total = value.total; page = next; message = items.isEmpty ? "未返回项目" : nil } catch { await store.absorb(http, revision: version); throw error }
            await store.absorb(http, revision: version)
        } catch { guard version == store.sessionRevision else { return }; message = error.localizedDescription }
    }
}
