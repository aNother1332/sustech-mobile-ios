import CampusCore
import SwiftUI

struct ReservationCenterView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        List {
            Section { CampusHero(eyebrow: "RESERVATIONS", title: "预约中心", subtitle: "空间 · 语言辅导 · 体育", symbol: "calendar.badge.plus") }
            Section("统一预约中心") {
                NavigationLink { ICReservationView().id(store.sessionRevision) } label: { Label("IC 研讨间", systemImage: "person.3") }
                NavigationLink { CLEReservationView().id(store.sessionRevision) } label: { Label("CLE 语言辅导", systemImage: "bubble.left.and.bubble.right") }
                NavigationLink { CourtReservationView().id(store.sessionRevision) } label: { Label("体育场馆 · reservation", systemImage: "sportscourt") }
            }
            Section("其他场馆入口") {
                NavigationLink { SchoolBrowser(service: .booking) } label: { Label("原体育预约平台", systemImage: "globe") }
                Link("体育场馆官方预约页面", destination: URL(string: "https://reservation.sustech.edu.cn")!)
                Text("学校存在多个预约平台。新体育场馆目录从 reservation 平台读取；原平台入口一并保留。").font(.caption).foregroundStyle(.secondary)
            }
        }.navigationTitle("预约中心").navigationBarTitleDisplayMode(.inline)
    }
}

struct ICReservationView: View {
    @Environment(CampusStore.self) private var store
    @State private var rooms: [ReservationItem] = []
    @State private var orders: [ReservationItem] = []
    @State private var busy = false
    @State private var connected = false
    @State private var needsLogin = false
    @State private var message: String?
    @State private var portal = false
    @State private var cancelling: ReservationItem?
    var body: some View {
        List {
            Section {
                Button("刷新房间与我的预约") { Task { await refresh() } }.disabled(busy || store.mode == .demo)
                IndependentConnectionStatus(connected: connected, requiresLogin: needsLogin) { portal = true }
                if busy { ProgressView() }; ServiceMessage(message: message)
                Text("按学校实时规则预约。多人房间需填写同行成员学号；设备外借等特殊项目请使用学校页面。").font(.caption).foregroundStyle(.secondary)
            }
            Section("房间") {
                ForEach(rooms) { room in
                    if room.raw["nativeBookable"] == .bool(false) {
                        VStack(alignment: .leading) { Text(room.title); Text(room.detail).font(.caption).foregroundStyle(.secondary) }
                    } else {
                        NavigationLink { ICBookingForm(room: room) } label: {
                            VStack(alignment: .leading) { Text(room.title); Text(room.detail).font(.caption).foregroundStyle(.secondary) }
                        }
                    }
                }
            }
            Section("我的预约 · 当前起未来 60 天，最多 100 项") {
                ForEach(orders) { order in
                    VStack(alignment: .leading) {
                        Text(order.title); Text(order.detail).font(.caption)
                        Button("取消预约", role: .destructive) { cancelling = order }.disabled(busy)
                    }
                }
            }
        }.refreshable { await refresh() }.task { await refresh() }.navigationTitle("IC 研讨间").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $portal, onDismiss: { Task { await refresh() } }) { SchoolBrowser(service: .rooms) }
        .confirmationDialog("确认取消这项预约？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }), titleVisibility: .visible) {
            if let order = cancelling { Button("取消 \(order.title)", role: .destructive) { Task { await cancel(order) } } }
        }
    }
    private func client() async throws -> ICClient {
        try await store.sessions.connectIC()
        return ICClient(http: await store.serviceHTTP(origin: SchoolService.rooms.portalURL))
    }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        do { let api = try await client(); rooms = try await api.rooms(); orders = try await api.mine(); connected = true; needsLogin = false; message = "读取于 \(Date.now.formatted())" }
        catch { connected = false; needsLogin = (error as? CampusError) == .signInRequired || error is CASFailure; message = error.localizedDescription }
    }
    private func cancel(_ order: ReservationItem) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        do { let api = try await client(); try await api.cancel(order); orders = try await api.mine(); message = orders.contains { $0.id == order.id } ? "取消请求已返回，请核对记录状态。" : "当前预约列表已不包含此项。" }
        catch { if (error as? CampusError) == .signInRequired { connected = false; needsLogin = true }; message = "结果需核对：\(error.localizedDescription)" }
    }
}
private struct ICBookingForm: View {
    let room: ReservationItem
    @Environment(CampusStore.self) private var store
    @State private var begin = Date.now.addingTimeInterval(3600)
    @State private var end = Date.now.addingTimeInterval(7200)
    @State private var title = "学习讨论"
    @State private var members = ""
    @State private var busy = false
    @State private var message: String?
    @State private var confirm = false
    var body: some View {
        Form {
            Section { Text(room.title).font(.headline); Text(room.detail).font(.caption) }
            Section("预约内容") {
                DatePicker("开始", selection: $begin); DatePicker("结束", selection: $end)
                TextField("用途", text: $title)
                TextField("同行成员学号，以逗号分隔", text: $members).textInputAutocapitalization(.never)
                Button("核对并预约一次") { confirm = true }.disabled(busy || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
        }.navigationTitle("预约研讨间").navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("预约 \(room.title)？", isPresented: $confirm, titleVisibility: .visible) {
            Button("确认提交") { Task { await submit() } }
        } message: { Text("\(begin.formatted()) 至 \(end.formatted())；同行：\(members.isEmpty ? "无" : members)。以学校回执为准。") }
    }
    private func submit() async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        let requestedBegin = begin, requestedEnd = end, requestedTitle = title
        let requestedMembers = members.components(separatedBy: CharacterSet(charactersIn: ",， \n")).filter { !$0.isEmpty }
        do {
            try await store.sessions.connectIC()
            let http = await store.serviceHTTP(origin: SchoolService.rooms.portalURL); let api = ICClient(http: http)
            try await api.book(room: room, begin: requestedBegin, end: requestedEnd, title: requestedTitle, members: requestedMembers)
            let orders = try await api.mine()
            message = orders.contains { ICClient.matches($0, room: room.id, begin: requestedBegin, end: requestedEnd) } ? "已在我的预约中确认对应房间和时段。" : "学校已接受请求，但未能在我的预约中确认，请打开学校页面核对，勿重复提交。"
        } catch { message = "本次结果：\(error.localizedDescription) 若请求已发出，请先查看我的预约再重试。" }
    }
}

struct CLEReservationView: View {
    @Environment(CampusStore.self) private var store
    @State private var day = Date.now.addingTimeInterval(3 * 86400)
    @State private var slots: [ReservationItem] = []
    @State private var orders: [ReservationItem] = []
    @State private var busy = false
    @State private var connected = false
    @State private var needsLogin = false
    @State private var message: String?
    @State private var note = ""
    @State private var portal = false
    @State private var selected: ReservationItem?
    @State private var cancelling: ReservationItem?
    var body: some View {
        List {
            Section {
                IndependentConnectionStatus(connected: connected, requiresLogin: needsLogin) { portal = true }
                Text("首次请打开学校页面完成连接，之后复用会话。预约与取消条件以语言中心当前规则为准。").font(.caption).foregroundStyle(.secondary)
                DatePicker("查询日期", selection: $day, displayedComponents: .date)
                TextField("预约说明（必填，最多 500 字）", text: $note, axis: .vertical)
                Button("刷新时段与我的预约") { Task { await refresh() } }.disabled(busy || store.mode == .demo)
                if busy { ProgressView() }; ServiceMessage(message: message)
            }
            Section("当日辅导时段") {
                ForEach(slots) { slot in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(slot.title).font(.headline); Text(slot.detail).font(.caption)
                        Button("预约此时段") { selected = slot }.disabled(busy || slot.raw["SFXXYY"].text == "1" || store.mode == .demo)
                    }
                }
            }
            Section("我的预约") {
                ForEach(orders) { order in
                    VStack(alignment: .leading) {
                        Text(order.title); Text(order.detail).font(.caption)
                        if order.raw["YYZT"].text == "1" { Button("取消预约", role: .destructive) { cancelling = order }.disabled(busy) }
                    }
                }
            }
        }.refreshable { await refresh() }.task { await refresh() }.navigationTitle("CLE 语言辅导").navigationBarTitleDisplayMode(.inline).sheet(isPresented: $portal, onDismiss: { Task { await refresh() } }) { SchoolBrowser(service: .cle) }
        .onChange(of: day) { _, _ in slots = [] }
        .confirmationDialog("确认预约该辅导？", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
            if let slot = selected { Button("提交一次") { Task { await book(slot) } } }
        } message: { if let slot = selected { Text(slot.title + "\n" + slot.detail + "\n" + note) } }
        .confirmationDialog("确认取消？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }), titleVisibility: .visible) {
            if let order = cancelling { Button("取消此预约", role: .destructive) { Task { await cancel(order) } } }
        }
    }
    private func client() async -> CLEClient { CLEClient(http: await store.serviceHTTP(origin: CLEClient.index)) }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        do { let api = await client(); slots = try await api.slots(day: day); orders = try await api.mine(sid: store.sessions.cleID); connected = true; needsLogin = false; message = "读取于 \(Date.now.formatted())" }
        catch { connected = false; needsLogin = (error as? CampusError) == .signInRequired || error is CASFailure; message = error.localizedDescription }
    }
    private func book(_ slot: ReservationItem) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        let requestedNote = note
        do { let api = await client(); try await api.book(slot, sid: store.sessions.cleID, name: store.sessions.cleName, note: requestedNote)
            orders = try await api.mine(sid: store.sessions.cleID)
            message = orders.contains { $0.raw["SJSZ_WID"].text == slot.id && $0.raw["YYZT"].text == "1" } ? "已在我的预约中确认。" : "请求已返回，但预约尚未回读确认，请先到学校页面核对。"
        } catch { if (error as? CampusError) == .signInRequired { connected = false; needsLogin = true }; message = "结果需核对：\(error.localizedDescription)" }
    }
    private func cancel(_ order: ReservationItem) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        do { let api = await client(); try await api.cancel(order); orders = try await api.mine(sid: store.sessions.cleID)
            message = orders.first { $0.id == order.id }?.raw["YYZT"].text == "4" ? "已回读确认取消。" : "取消请求已返回，请核对记录状态。"
        } catch { if (error as? CampusError) == .signInRequired { connected = false; needsLogin = true }; message = "结果需核对：\(error.localizedDescription)" }
    }
}
