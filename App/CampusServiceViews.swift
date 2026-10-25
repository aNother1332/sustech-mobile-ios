import CampusCore
import Charts
import SwiftUI
import UniformTypeIdentifiers
import PDFKit

struct ServiceMessage: View {
    let message: String?
    var body: some View { if let message { Text(message).font(.callout).foregroundStyle(.secondary).textSelection(.enabled) } }
}

struct CardAccountView: View {
    @Environment(CampusStore.self) private var store
    @State private var account: CardAccount?
    @State private var bills: [CardBill] = []
    @State private var message: String?
    @State private var busy = false
    @State private var synced: Date?
    @State private var days = 30
    @State private var portal = false
    private var filtered: [CardBill] {
        guard days > 0 else { return bills }
        let cutoff = CampusClock.format(.now.addingTimeInterval(-Double(days - 1) * 86400))
        return bills.filter { String($0.time.prefix(10)).replacingOccurrences(of: "/", with: "-") >= cutoff }
    }
    private var curve: [CardDay] { CardParser.curve(filtered) }
    var body: some View {
        List {
            Section {
                CampusHero(eyebrow: "CAMPUS CARD", title: "我的校园卡", subtitle: "余额 · 动态码 · 账单", symbol: "creditcard.fill")
                ModeNotice()
                SessionBadge(service: .card)
                if let account {
                    Text(account.balance).font(.largeTitle.bold()).foregroundStyle(Color.campusGreen)
                    Text("校园卡余额").font(.caption)
                    if !account.name.isEmpty { Text(account.name) }
                } else { Text("余额尚未读取") }
                Button("刷新余额与账单", systemImage: "arrow.clockwise") { Task { await refresh() } }.disabled(busy || store.mode == .demo)
                if busy { ProgressView() }
                if let synced { Text("读取于 \(synced.formatted())").font(.caption) }
                ServiceMessage(message: message)
                NavigationLink { CampusCodeView().id(store.sessionRevision) } label: { Label("出示校园码 / 身份码", systemImage: "qrcode") }
                CardBalancePreference(balance: account?.balance)
                NavigationLink { CardRechargeView() } label: { Label("校园卡充值", systemImage: "plus.circle") }
                Text("充值由支付宝或学校微信页面完成，返回后可刷新余额与账单。").font(.caption).foregroundStyle(.secondary)
            }
            Section("消费曲线") {
                Picker("账单范围", selection: $days) { Text("近 7 天").tag(7); Text("近 30 天").tag(30); Text("已读取全部").tag(0) }.pickerStyle(.segmented)
                if curve.isEmpty { Text("当前记录中没有可确认日期和支出方向的消费数据。") }
                else {
                    Chart(curve) { day in
                        LineMark(x: .value("日期", day.id), y: .value("消费（元）", day.value)).foregroundStyle(Color.campusGreen)
                        PointMark(x: .value("日期", day.id), y: .value("消费（元）", day.value)).foregroundStyle(Color.campusGreen)
                    }.frame(height: 220).accessibilityLabel("每日消费金额曲线")
                    Text("已确认支出合计 ¥\(curve.reduce(0) { $0 + $1.value }.formatted(.number.precision(.fractionLength(2))))")
                }
                DetailNote(text: "仅统计本次接口返回范围内、可确认的消费记录；充值、退款、失败与未知方向不算支出。未返回的日期不当作零消费，不代表完整历史账单。")
            }
            Section("已读取账单 · \(filtered.count) 笔") {
                ForEach(filtered) { bill in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack { Text(bill.kind); Spacer(); Text(bill.amount).monospacedDigit() }
                        Text(bill.time + " · " + bill.status).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Section { Button("打开学校校园卡页面") { portal = true } }
        }.refreshable { await refresh() }.navigationTitle("校园卡").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $portal) { SchoolBrowser(service: .card) }
        .task {
            if store.mode == .live { await refresh() }
            else {
                account = try? CardParser.account(DemoData.cardAccountHTML)
                bills = (try? CardParser.bills(DemoData.cardBillsHTML)) ?? []
                message = "演示模式：余额与流水均为虚构样例，包含一笔不计入支出的退款。"
            }
        }
    }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision
        let http = await store.serviceHTTP(.card); let client = CardClient(http: http)
        do {
            let value = try await client.account()
            guard store.sessionRevision == version else { return }; account = value; store.recordSession(.card)
            let records = try await client.bills()
            guard store.sessionRevision == version else { return }; bills = records; synced = .now; message = nil
        } catch { if version == store.sessionRevision { store.recordSession(.card, error: error); message = error.localizedDescription } }
        await store.absorb(http, revision: version)
    }
}

struct BusStopsView: View {
    @State private var location = CampusLocation()
    private var orderedStops: [BusStop] { stops.sorted { (location.distance($0) ?? .greatestFiniteMagnitude) < (location.distance($1) ?? .greatestFiniteMagnitude) } }
    @State private var stops: [BusStop] = []
    @State private var query = ""
    @State private var message: String?
    @State private var busy = false
    private let client = BusClient(http: ServiceHTTP(origin: URL(string: "https://buseta.sustcra.com")!))
    var body: some View {
        List {
            Section {
                Button("按距离查找附近站点", systemImage: "location.fill") { location.request() }
                if let note = location.message { Text(note).font(.caption).foregroundStyle(.secondary) }
                Text("数据来源：SUSTech CRA · buseta.sustcra.com").font(.caption)
                Text("到站时间为预测，方向请以站点标识为准。").font(.caption).foregroundStyle(.secondary)
                Button("刷新站点") { Task { await load() } }.disabled(busy)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
            ForEach(orderedStops.filter { query.isEmpty || ($0.name + $0.directions).localizedCaseInsensitiveContains(query) }) { stop in
                NavigationLink { BusStopView(stop: stop, client: client) } label: {
                    VStack(alignment: .leading) { Text(stop.name); Text(stop.directions).font(.caption).foregroundStyle(.secondary); if let metres = location.distance(stop) { Text("距你约 \(Int(metres)) 米").font(.caption).foregroundStyle(Color.campusGreen) } }
                }
            }
        }.refreshable { await load() }.navigationTitle("校车查询").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "站点、线路或方向").task { await load() }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { stops = try await client.stops(); message = nil } catch { message = error.localizedDescription }
    }
}
struct BusStopView: View {
    @Environment(\.scenePhase) private var phase
    let stop: BusStop; let client: BusClient
    @State private var arrivals: [BusArrival] = []
    @State private var message: String?
    @State private var synced: Date?
    @State private var busy = false
    var body: some View {
        List {
            Section {
                Text(stop.directions)
                LabeledContent("站点 ID", value: stop.id).font(.caption).textSelection(.enabled)
                ShareLink("复制／分享站点 ID", item: stop.id).font(.caption)
                Button("刷新预计到站") { Task { await load() } }.disabled(busy)
                if busy { ProgressView() }
                if let synced { Text("读取于 \(synced.formatted()) · 前台每 30 秒刷新").font(.caption) }
                ServiceMessage(message: message)
            }
            ForEach(arrivals) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.route + " · " + item.direction).font(.headline)
                    if let minutes = item.minutes { Text("预计 \(minutes) 分钟").foregroundStyle(Color.campusGreen) }
                    else { Text("暂无法预测") }
                    if let metres = item.metres, metres >= 0 { Label("距离站点 \(metres) 米", systemImage: "location") .font(.caption) }
                    if let count = item.stopsAway, count >= 0 { Text("还有 \(count) 站").font(.caption.bold()) }
                    if !item.planned.isEmpty { Text("计划时间：" + item.planned).font(.caption) }
                    if !item.reason.isEmpty { Text(item.reason).font(.caption) }
                    Text("来源：" + (item.source == "planned" ? "计划班次" : item.source)).font(.caption).foregroundStyle(.secondary)
                }
            }
            if arrivals.isEmpty, synced != nil { Text("本次未返回到站预测，请核对运营时间。") }
        }.refreshable { await load() }.navigationTitle(stop.name).task { await load(); while !Task.isCancelled { do { try await Task.sleep(for: .seconds(30)) } catch { return }; if phase == .active { await load() } } }
    }
    private func load() async {
        guard !busy else { return }; busy = true; defer { busy = false }
        do { arrivals = try await client.arrivals(stop.id); synced = .now; message = nil } catch { message = error.localizedDescription }
    }
}

struct ClassroomView: View {
    @Environment(CampusStore.self) private var store
    @State private var rooms: [Classroom] = []
    @State private var results: [String: String] = [:]
    @State private var query = ""
    @State private var week = 1
    @State private var weekday = 1
    @State private var first = 1
    @State private var last = 2
    @State private var busy = false
    @State private var message: String?
    private var filtered: [Classroom] { rooms.filter { query.isEmpty || $0.name.localizedCaseInsensitiveContains(query) } }
    var body: some View {
        List {
            Section("筛选时段") {
                Stepper("第 \(week) 教学周", value: $week, in: 1...60)
                Picker("星期", selection: $weekday) { ForEach(1...7, id: \.self) { Text("周" + ["一", "二", "三", "四", "五", "六", "日"][$0 - 1]).tag($0) } }
                Stepper("开始：第 \(first) 节", value: $first, in: 1...20)
                Stepper("结束：第 \(last) 节", value: $last, in: first...max(first, 20))
                Button("加载教室目录") { Task { await load() } }.disabled(busy || store.mode == .demo)
                Button("查询筛选结果前 20 间") { Task { await check() } }.disabled(busy || rooms.isEmpty || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
                Text("按教学周和学校节次查询课程及借用记录。‘系统未见占用’不保证教室开放或可进入；未查询和失败不视为空闲。").font(.caption).foregroundStyle(.secondary)
            }
            Section("教室 · \(filtered.count) 间") {
                ForEach(filtered) { room in
                    VStack(alignment: .leading) {
                        Text(room.name).font(.headline)
                        Text("座位：\(room.capacity.isEmpty ? "未知" : room.capacity) · \(results[room.id] ?? "尚未查询")").font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
        }.refreshable { if rooms.isEmpty { await load() } else { await check() } }.navigationTitle("空教室").navigationBarTitleDisplayMode(.inline).searchable(text: $query, prompt: "先按教学楼或教室名筛选")
        .onChange(of: week) { _, _ in results = [:] }.onChange(of: weekday) { _, _ in results = [:] }
        .onChange(of: first) { _, value in last = max(last, value); results = [:] }.onChange(of: last) { _, _ in results = [:] }
        .task { week = store.teaching?.week ?? 1 }
    }
    private func semester(_ http: ServiceHTTP) async throws -> Semester {
        try TISParser.semester(await http.data("/component/querydangqianxnxq", form: [:]))
    }
    private func load() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.teaching)
        do { let sem = try await semester(http); let value = try await ClassroomClient(http: http).catalog(semester: sem)
            guard version == store.sessionRevision else { return }; rooms = value; results = [:]; message = nil
        } catch { message = error.localizedDescription }
        await store.absorb(http, revision: version)
    }
    private func check() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let w = week, d = weekday, a = first, b = last
        let selected = Array(filtered.prefix(20)); let http = await store.serviceHTTP(.teaching)
        do {
            let sem = try await semester(http); let client = ClassroomClient(http: http)
            for room in selected {
                try Task.checkCancellation(); guard version == store.sessionRevision else { return }
                do { let entries = try await client.schedule(room, semester: sem)
                    guard version == store.sessionRevision, w == week, d == weekday, a == first, b == last else { return }
                    results[room.id] = entries.contains { $0.overlaps(week: w, weekday: d, first: a, last: b) } ? "有安排或周次待确认" : "系统未见占用"
                } catch { results[room.id] = "查询失败，状态未知"; throw error }
            }
            message = "已核对 \(selected.count) 间 · \(Date.now.formatted())"
        } catch { message = error.localizedDescription }
        await store.absorb(http, revision: version)
    }
}

struct PrintingWorkspaceView: View {
    var initialURL: URL? = nil
    var startImport = false
    @Environment(CampusStore.self) private var store
    @State private var jobs: [PrintJob] = []
    @State private var message: String?
    @State private var busy = false
    @State private var importing = false
    @State private var pdf: Data?
    @State private var filename = ""
    @State private var pages = 0
    @State private var options = PrintOptions()
    @State private var allPages = true
    @State private var confirmUpload = false
    @State private var deleting: PrintJob?
    @State private var portal = false
    var body: some View {
        Form {
            Section("选取 PDF") {
                Button("从文件导入 PDF", systemImage: "doc.badge.plus") { importing = true }.disabled(busy)
                if pdf != nil { Text(filename); Text("\(pages) 页").font(.caption) }
                Text("当前支持 50 MB 以内 PDF。提交后到打印机领取，实际费用以学校系统为准。").font(.caption).foregroundStyle(.secondary)
            }
            Section("打印参数") {
                Picker("纸张", selection: $options.paper) { Text("A4").tag(9); Text("A3").tag(8) }
                Picker("颜色", selection: $options.color) { Text("黑白").tag(1); Text("彩色").tag(2) }
                Picker("单双面", selection: $options.duplex) { Text("单面").tag(1); Text("双面 · 短边翻转").tag(2); Text("双面 · 长边翻转").tag(3) }
                Stepper("\(options.copies) 份", value: $options.copies, in: 1...99)
                Toggle("全部页", isOn: $allPages)
                if !allPages {
                    Stepper("起始页 \(options.first)", value: $options.first, in: 1...max(pages, 1))
                    Stepper("结束页 \(options.last)", value: $options.last, in: max(options.first, 1)...max(pages, max(options.first, 1)))
                }
                Button("确认打印参数并提交") { confirmUpload = true }.disabled(pdf == nil || busy || store.mode == .demo)
            }
            Section {
                CampusHero(eyebrow: "CAMPUS PRINT", title: "校园打印", subtitle: "选文件 · 设参数 · 查队列", symbol: "printer.fill")
                NavigationLink("打印站点、扫描与用量") { PrintExtrasView().id(store.sessionRevision) }; NavigationLink("系统分享待打印") { PrintInboxView() } }
            Section("打印队列") {
                SessionBadge(service: .printing)
                Button("刷新队列") { Task { await refresh() } }.disabled(busy || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
                ForEach(jobs) { job in
                    VStack(alignment: .leading) {
                        Text(job.name).font(.headline); Text("\(job.copies) 份 · \(job.attributes)").font(.caption)
                        Button("删除此任务", role: .destructive) { deleting = job }.disabled(busy)
                    }
                }
                Button("打开学校打印页面") { portal = true }
            }
        }.navigationTitle("校园打印").navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task { if let initialURL { importPDF(initialURL) } else if startImport { importing = true }; await refresh() }
        .sheet(isPresented: $portal) { SchoolBrowser(service: .printing) }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.pdf]) { result in
            do { importPDF(try result.get()) } catch { message = error.localizedDescription }
        }
        .campusConfirmation("提交 \(filename) · \(options.copies) 份？", isPresented: $confirmUpload, titleVisibility: .visible) {
            Button("提交一次") { Task { await upload() } }
        } message: { Text("请核对纸张、颜色、单双面和页码。网络超时后先查队列，避免重复提交。") }
        .campusConfirmation("删除打印任务？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            if let job = deleting { Button("删除 \(job.name)", role: .destructive) { Task { await remove(job) } } }
        }
    }
    private func importPDF(_ url: URL) {
        do {
            let scoped = url.startAccessingSecurityScopedResource(); defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
            guard size > 0, size <= 50 * 1024 * 1024 else { throw ServiceFailure("请选择 50 MB 以内 PDF。") }
            let data = try Data(contentsOf: url)
            guard let document = PDFDocument(data: data), document.pageCount > 0, !document.isLocked else { throw ServiceFailure("PDF 无法读取或需要密码。") }
            pdf = data; filename = url.lastPathComponent; pages = document.pageCount; options.first = 1; options.last = pages; message = nil
        } catch { message = error.localizedDescription }
    }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.printing)
        do { let value = try await PrintingClient(http: http).jobs(); guard version == store.sessionRevision else { return }; jobs = value; store.recordSession(.printing); message = "队列读取于 \(Date.now.formatted())" }
        catch { if version == store.sessionRevision { store.recordSession(.printing, error: error); message = error.localizedDescription } }; await store.absorb(http, revision: version)
    }
    private func upload() async {
        guard !busy, let pdf, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        var selected = options; if allPages { selected.first = 0; selected.last = 0 }
        let name = filename
        let version = store.sessionRevision; let http = await store.serviceHTTP(.printing); let client = PrintingClient(http: http)
        do {
            try await client.upload(pdf: pdf, name: name, options: selected)
            guard version == store.sessionRevision else { return }
            message = "平台已接受上传，正在核对队列。"
            jobs = try await client.jobs(); message = "平台已接受上传；请在队列核对文件后到打印机领取。"
        } catch {
            store.recordSession(.printing, error: error)
            let reason = error.localizedDescription
            if let value = try? await client.jobs(), version == store.sessionRevision { jobs = value }
            message = "本次未能完整确认结果：\(reason) 已尝试刷新队列，请核对文件后再决定是否重新提交。"
        }
        await store.absorb(http, revision: version)
    }
    private func remove(_ job: PrintJob) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.printing); let client = PrintingClient(http: http)
        do { try await client.delete(job.id); guard version == store.sessionRevision else { return }; jobs = try await client.jobs(); message = jobs.contains { $0.id == job.id } ? "任务仍在队列，请核对。" : "任务已不在当前队列。" }
        catch { store.recordSession(.printing, error: error); message = "删除结果需核对：\(error.localizedDescription)" }; await store.absorb(http, revision: version)
    }
}
