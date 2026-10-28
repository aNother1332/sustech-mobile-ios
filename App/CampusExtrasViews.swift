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
                BusinessHeader(title: kind.rawValue, symbol: "qrcode", color: .campusGreen)
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
                EmptyView()
                if busy { ProgressView() }; ServiceMessage(message: message)
                EmptyView()
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
            Section { BusinessHeader(title: "师资", symbol: "person.crop.rectangle.stack", color: .campusGreen) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)
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
    @State private var needsLogin = false
    @State private var login = false
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                BusinessHeader(title: "交换项目", symbol: "airplane.departure", color: .blue)
                IndependentConnectionStatus(connected: !needsLogin, requiresLogin: needsLogin) { login = true }
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("学校、地区、项目", text: $query)
                    Toggle("可申请", isOn: $onlyOpen).labelsHidden().accessibilityLabel("仅看可申请项目")
                }.padding(14).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 14))
                ServiceMessage(message: message)
                ForEach(items.filter { (!onlyOpen || $0.available) && (query.isEmpty || ($0.name + $0.location).localizedCaseInsensitiveContains(query)) }) { item in
                    NavigationLink { ExchangeDetailView(item: item).toolbar(.visible, for: .navigationBar) } label: {
                        HStack(spacing: 14) {
                            if let image = item.imageURL { EphemeralImage(url: image).frame(width: 105, height: 125).clipShape(RoundedRectangle(cornerRadius: 12)) }
                            else { Image(systemName: "globe.asia.australia").font(.system(size: 37, weight: .ultraLight)).foregroundStyle(.blue).frame(width: 70, height: 110).background(.blue.opacity(0.06), in: RoundedRectangle(cornerRadius: 12)) }
                            VStack(alignment: .leading, spacing: 8) {
                                Text(item.name).font(.subheadline.weight(.semibold)).foregroundStyle(.primary).multilineTextAlignment(.leading)
                                Text(item.location).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                                if !item.status.isEmpty { Text(item.status).font(.caption2.weight(.medium)).foregroundStyle(item.available ? Color.campusGreen : .secondary).padding(.horizontal, 8).padding(.vertical, 4).background((item.available ? Color.green : Color.gray).opacity(0.08), in: Capsule()) }
                            }
                            Spacer(minLength: 0)
                        }.padding(12).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(CampusPressStyle())
                }
                if busy { ProgressView().frame(maxWidth: .infinity) }
                if items.count < total { Button("加载更多") { Task { await load(reset: false) } }.disabled(busy).frame(maxWidth: .infinity).buttonStyle(.bordered) }
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("交换项目").navigationBarTitleDisplayMode(.inline)
            .task { await load(reset: true) }.refreshable { await load(reset: true) }
            .sheet(isPresented: $login, onDismiss: { Task { await load(reset: true) } }) { NativeLoginView() }
    }
    private func load(reset: Bool) async {
        #if DEBUG
        if store.mode == .demo {
            let data = Data(#"{"DataList":[{"ID":"demo-one","Name":"暑期交流项目（示例）","RegionName":"示例地区","ProjectSchoolName":"示例合作学校","ProjectDescription":"项目介绍与课程安排","ApplyCondition":"示例申请条件","ProjectTypeText":"暑期交流"},{"ID":"demo-two","Name":"学期交换项目（示例）","RegionName":"示例地区","ProjectSchoolName":"示例大学","ProjectTypeText":"学期交换"}]}"#.utf8)
            if let value = try? JSONDecoder().decode(WireValue.self, from: data) { items = (try? ExchangeClient.parsePrograms(value).items) ?? [] }; return
        }
        #endif
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let origin = URL(string: "https://ws.sustech.edu.cn")!
        do {
            try await store.sessions.connect(entry: URL(string: "https://cas.sustech.edu.cn/cas/login?service=https%3A%2F%2Fws.sustech.edu.cn%2FSUSTechHome.aspx")!, finalHost: origin.host)
            let http = await store.serviceHTTP(origin: origin)
            do {
                let next = reset ? 1 : page + 1; let value = try await ExchangeClient(http: http).programs(page: next)
                guard version == store.sessionRevision else { return }
                items = reset ? value.items : items + value.items.filter { row in !items.contains { $0.id == row.id } }; total = value.total; page = next; message = nil; needsLogin = false
            } catch { await store.absorb(http, revision: version); throw error }
            await store.absorb(http, revision: version)
        } catch { guard version == store.sessionRevision else { return }; needsLogin = LoginRequirement.confirmed(error); message = needsLogin ? nil : error.localizedDescription }
    }
}
private struct ExchangeDetailView: View {
    let item: ExchangeProgram
    @State private var apply = false
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if let image = item.imageURL { EphemeralImage(url: image).frame(height: 210).clipShape(RoundedRectangle(cornerRadius: 20)) }
                Text(item.name).font(.title2.bold())
                Text(item.location).font(.subheadline).foregroundStyle(.secondary)
                if !item.applicationDates.isEmpty { Label(item.applicationDates, systemImage: "calendar").font(.caption) }
                content("项目介绍", item.description); content("申请条件", item.requirements); content("费用", item.fee); content("申请范围", item.range)
                Button("查看官方申请") { apply = true }.buttonStyle(.borderedProminent).frame(maxWidth: .infinity)
            }.padding(16).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("项目详情").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $apply) { SchoolBrowser(service: .exchange, initialURL: item.url, ephemeral: true) }
    }
    @ViewBuilder private func content(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { CampusCard { Text(title).font(.headline); Text(value).font(.subheadline).lineSpacing(5).textSelection(.enabled) } }
    }
}
