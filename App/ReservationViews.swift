import CampusCore
import SwiftUI

struct ReservationCenterView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BusinessHeader(title: "预约中心", symbol: "calendar.badge.plus", color: .blue)
                CampusSectionTitle(title: "场地空间")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ServiceTile(title: "IC研讨间", detail: "", symbol: "door.left.hand.open", color: .campusOrange) { ICReservationView().id(store.sessionRevision) }
                    ServiceTile(title: "书院场地", detail: "", symbol: "building.2", color: .campusOrange) { CollegeBookingView().id(store.sessionRevision) }
                }
                CampusSectionTitle(title: "语言辅导")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ServiceTile(title: "CLE辅导", detail: "", symbol: "bubble.left.and.bubble.right", color: .campusOrange) { CLEReservationView().id(store.sessionRevision) }
                }
                NavigationLink { AgendaView().id(store.sessionRevision) } label: { Label("我的预约与日程", systemImage: "calendar.badge.clock").frame(maxWidth: .infinity, alignment: .leading).padding() }
            }.padding(16).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Color.campusPaper).navigationTitle("预约中心").navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(CampusPalette.header, for: .navigationBar).toolbarBackground(.visible, for: .navigationBar).toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct ICSlotSelection: Identifiable {
    var id = UUID(); let room: ReservationItem; let start: Date; let end: Date
}
struct ICReservationView: View {
    @Environment(CampusStore.self) private var store
    @State private var rooms: [ReservationItem] = []
    @State private var orders: [ReservationItem] = []
    @State private var schedules: [String: ICRoomSchedule] = [:]
    @State private var day = Date.now
    @State private var busy = false
    @State private var connected = false
    @State private var needsLogin = false
    @State private var message: String?
    @State private var portal = false
    @State private var selected: ICSlotSelection?
    @State private var cancelling: ReservationItem?
    private let slotWidth: CGFloat = 50
    private var bookableRooms: [ReservationItem] { rooms.filter { $0.raw["nativeBookable"] != .bool(false) } }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BusinessHeader(title: "Information Commons", symbol: "person.2.crop.square.stack", color: Color(red: 0.18, green: 0.47, blue: 0.72))
                HStack {
                    DatePicker("日期", selection: $day, in: Date.now...Date.now.addingTimeInterval(7 * 86400), displayedComponents: .date).labelsHidden()
                    Spacer(); if busy { ProgressView() }
                }
                IndependentConnectionStatus(connected: connected, requiresLogin: needsLogin) { portal = true }
                ServiceMessage(message: message)
                HStack(alignment: .top, spacing: 0) {
                    VStack(spacing: 0) {
                        Text("讨论间").font(.caption).frame(width: 104, height: 34)
                        ForEach(bookableRooms) { room in Text(room.title).font(.caption.weight(.medium)).lineLimit(2).frame(width: 104, height: 58).background(Color.blue.opacity(0.035)).overlay(alignment: .bottom) { Divider() } }
                    }
                    ScrollView(.horizontal) {
                        VStack(spacing: 0) {
                            HStack(spacing: 0) { ForEach(0..<28, id: \.self) { slot in Text(String(format: "%02d:%02d", 8 + slot / 2, slot % 2 * 30)).font(.caption2.monospacedDigit()).foregroundStyle(.secondary).frame(width: slotWidth, height: 34) } }
                            ForEach(bookableRooms) { room in timeline(room) }
                        }
                    }.scrollIndicators(.hidden)
                }.background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 14)).clipShape(RoundedRectangle(cornerRadius: 14))
                if !orders.isEmpty { CampusSectionTitle(title: "我的预约") }
                ForEach(orders) { order in
                    CampusCard {
                        Text(order.title).font(.subheadline.weight(.semibold)); Text(order.detail).font(.caption).foregroundStyle(.secondary)
                        Button("取消预约", role: .destructive) { cancelling = order }.disabled(busy)
                    }
                }
            }.padding(16).frame(maxWidth: 1200).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("讨论间预约").navigationBarTitleDisplayMode(.inline)
            .task(id: CampusClock.format(day)) {
                while busy { do { try await Task.sleep(for: .milliseconds(100)) } catch { return } }
                guard !Task.isCancelled else { return }; await refresh()
            }.refreshable { await refresh() }.onChange(of: day) { _, _ in schedules = [:] }
            .sheet(isPresented: $portal, onDismiss: { Task { await refresh() } }) { SchoolBrowser(service: .rooms) }
            .sheet(item: $selected, onDismiss: { Task { await refresh() } }) { value in NavigationStack { ICBookingForm(room: value.room, initialBegin: value.start, initialEnd: value.end).toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selected = nil } } } } }
            .campusConfirmation("取消这项预约？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } })) {
                if let order = cancelling { Button("取消预约", role: .destructive) { Task { await cancel(order) } } }
            }
    }
    private func timeline(_ room: ReservationItem) -> some View {
        let schedule = schedules[room.id]
        let base = CampusClock.date(CampusClock.format(day) + " 08:00", "yyyy-MM-dd HH:mm") ?? day
        return ZStack(alignment: .leading) {
            HStack(spacing: 0) { ForEach(0..<28, id: \.self) { index in
                let start = base.addingTimeInterval(Double(index) * 1800)
                let end = min(start.addingTimeInterval(1800), schedule?.windows.last?.end ?? start.addingTimeInterval(1800))
                let allowed = schedule?.canSelect(start: start, end: end) == true && start > .now
                Button { selected = ICSlotSelection(room: room, start: start, end: end) } label: {
                    Rectangle().fill(schedule == nil ? Color.gray.opacity(0.15) : allowed ? Color.blue.opacity(0.035) : Color.gray.opacity(0.07)).frame(width: slotWidth, height: 58).overlay(alignment: .trailing) { Rectangle().fill(Color.gray.opacity(0.14)).frame(width: 0.5) }
                }.buttonStyle(.plain).disabled(!allowed || busy).accessibilityLabel("\(room.title) \(String(format: "%02d:%02d", 8 + index / 2, index % 2 * 30))")
            } }
            if let schedule {
                ForEach(schedule.occupied) { occupied in
                    let a = max(0, occupied.start.timeIntervalSince(base) / 1800); let b = min(28, occupied.end.timeIntervalSince(base) / 1800)
                    if b > a { Text(CampusClock.format(occupied.start, "HH:mm") + "–" + CampusClock.format(occupied.end, "HH:mm")).font(.system(size: 10, weight: .medium)).lineLimit(1).foregroundStyle(Color(red: 0.45, green: 0.31, blue: 0.06)).frame(width: CGFloat(b-a) * slotWidth - 2, height: 34).background(Color.yellow.opacity(0.38), in: RoundedRectangle(cornerRadius: 5)).offset(x: CGFloat(a) * slotWidth + 1).allowsHitTesting(false) }
                }
            }
        }.frame(width: slotWidth * 28, height: 58).overlay(alignment: .bottom) { Divider() }
    }
    private func client() async throws -> ICClient {
        try await store.sessions.connectIC(); return ICClient(http: await store.serviceHTTP(origin: SchoolService.rooms.portalURL))
    }
    private func refresh() async {
        guard !busy else { return }
        #if DEBUG
        if store.mode == .demo { demo(); return }
        #endif
        guard store.mode == .live else { return }; busy = true; defer { busy = false }
        let revision = store.sessionRevision; let date = day
        do {
            let api = try await client(); let list = try await api.rooms(); let availability = try await api.schedules(rooms: list, day: date); let mine = try await api.mine()
            guard revision == store.sessionRevision, CampusClock.format(date) == CampusClock.format(day) else { return }
            rooms = list; schedules = availability; orders = mine; connected = true; needsLogin = false; message = nil
        } catch { guard revision == store.sessionRevision else { return }; needsLogin = LoginRequirement.confirmed(error); message = error.localizedDescription }
    }
    private func cancel(_ order: ReservationItem) async {
        guard !busy, store.beginWrite() else { return }; busy = true; defer { busy = false; store.endWrite() }
        do { let api = try await client(); try await api.cancel(order); orders = try await api.mine(); message = nil }
        catch { message = error.localizedDescription }
    }
    private func demo() {
        #if DEBUG
        let date = CampusClock.format(day)
        let raw: WireValue = .object(["devId": .string("demo-room"), "devName": .string("示例讨论间"), "resvInfo": .array([.object(["startTime": .string(date + " 10:00:00"), "endTime": .string(date + " 12:00:00"), "resvStatus": .integer(4)])]), "openTimes": .array([.object(["openStartTime": .string("08:00"), "openEndTime": .string("21:59")])])])
        rooms = [ReservationItem(id: "demo-room", title: "示例讨论间", detail: "", raw: raw)]
        if let value = try? ICRoomSchedule.parse(raw, day: day) { schedules = ["demo-room": value] }
        #endif
    }
}
private struct ICBookingForm: View {
    let room: ReservationItem
    var initialBegin: Date? = nil
    var initialEnd: Date? = nil
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
        .onAppear { if let initialBegin { begin = initialBegin }; if let initialEnd { end = initialEnd } }
        .campusConfirmation("预约 \(room.title)？", isPresented: $confirm, titleVisibility: .visible) {
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
            Section { BusinessHeader(title: "语言辅导", symbol: "bubble.left.and.bubble.right", color: .blue) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear)

            Section {
                IndependentConnectionStatus(connected: connected, requiresLogin: needsLogin) { portal = true }
                EmptyView()
                DatePicker("查询日期", selection: $day, displayedComponents: .date)
                TextField("预约说明（必填，最多 500 字）", text: $note, axis: .vertical)
                EmptyView()
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
        .campusConfirmation("确认预约该辅导？", isPresented: Binding(get: { selected != nil }, set: { if !$0 { selected = nil } }), titleVisibility: .visible) {
            if let slot = selected { Button("提交一次") { Task { await book(slot) } } }
        } message: { if let slot = selected { Text(slot.title + "\n" + slot.detail + "\n" + note) } }
        .campusConfirmation("确认取消？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } }), titleVisibility: .visible) {
            if let order = cancelling { Button("取消此预约", role: .destructive) { Task { await cancel(order) } } }
        }
    }
    private func client() async -> CLEClient { CLEClient(http: await store.serviceHTTP(origin: CLEClient.index)) }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        do { let api = await client(); slots = try await api.slots(day: day); orders = try await api.mine(sid: store.sessions.cleID); connected = true; needsLogin = false; message = "读取于 \(Date.now.formatted())" }
        catch { connected = false; needsLogin = LoginRequirement.confirmed(error); message = error.localizedDescription }
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
