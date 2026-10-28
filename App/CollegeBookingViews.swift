import CampusCore
import SwiftUI

struct CollegeBookingView: View {
    @Environment(CampusStore.self) private var store
    @State private var rooms: [ReservationItem] = []
    @State private var busy = false
    @State private var message: String?
    @State private var connected = false
    @State private var portal = false
    @State private var query = ""
    var body: some View {
        List {
            Section { BusinessHeader(title: "书院场地", symbol: "building.2", color: .blue) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)

            Section {
                IndependentConnectionStatus(connected: connected, requiresLogin: !connected) { portal = true }
                if busy { ProgressView() }; ServiceMessage(message: message)
                EmptyView()
            }
            Section("学校返回的场地 · \(rooms.count)") {
                ForEach(rooms.filter { query.isEmpty || ($0.title + $0.detail).localizedCaseInsensitiveContains(query) }) { room in
                    NavigationLink { CollegeRoomView(room: room).id(store.sessionRevision) } label: {
                        VStack(alignment: .leading, spacing: 3) { Text(room.title); Text(room.detail).font(.caption).foregroundStyle(.secondary) }
                    }
                }
            }
        }.navigationTitle("书院与其他场地").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "场地名称、位置、书院")
        .task { await load() }.refreshable { await load() }
        .sheet(isPresented: $portal, onDismiss: { Task { await load() } }) { SchoolBrowser(service: .booking) }
    }
    private func load() async {
        if store.mode == .demo {
            rooms = [ReservationItem(id: "demo-room", title: "示例书院活动室（虚构）", detail: "示例楼 201", raw: .object(["CapacityNumber": .integer(12)]))]
            message = "演示场地，不代表实际开放情况。"; return
        }
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let revision = store.sessionRevision
        do {
            let api = await store.collegeBookingClient()
            let value = try await api.rooms()
            guard revision == store.sessionRevision else { return }
            rooms = value; connected = true; message = "更新于 " + Date.now.formatted(date: .omitted, time: .shortened)
        } catch { guard revision == store.sessionRevision else { return }; connected = false; message = error.localizedDescription }
    }
}

private struct CollegeRoomView: View {
    @Environment(CampusStore.self) private var store
    let room: ReservationItem
    @State private var day = Date.now
    @State private var rows: [ReservationItem] = []
    @State private var busy = false
    @State private var message: String?
    @State private var portal = false
    var body: some View {
        List {
            Section {
                Text(room.title).font(.headline); Text(room.detail).foregroundStyle(.secondary)
                if !room.raw["CapacityNumber"].text.isEmpty { LabeledContent("容纳人数", value: room.raw["CapacityNumber"].text) }
                if !room.raw["MeetingRoomNotice"].text.isEmpty { Text(HTMLText.plain(room.raw["MeetingRoomNotice"].text)).font(.caption) }
                Button("前往学校页面预约", systemImage: "arrow.up.forward.app") { portal = true }
            }
            Section("当日安排") {
                DatePicker("日期", selection: $day, displayedComponents: .date).disabled(busy)
                if busy { ProgressView() }; ServiceMessage(message: message)
                ForEach(rows) { row in VStack(alignment: .leading) { Text(row.title); Text(row.detail).font(.caption).foregroundStyle(.secondary) } }
            }
        }.navigationTitle("场地详情").navigationBarTitleDisplayMode(.inline)
        .task { await load() }.refreshable { await load() }.onChange(of: day) { _, _ in Task { await load() } }
        .sheet(isPresented: $portal, onDismiss: { Task { await load() } }) { SchoolBrowser(service: .booking) }
    }
    private func load() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }
        let revision = store.sessionRevision; rows = []
        do {
            let api = await store.collegeBookingClient(); let value = try await api.schedule(room: room.id, day: day)
            guard revision == store.sessionRevision else { return }; rows = value
            message = value.isEmpty ? "学校未返回该日安排，不代表已确认可预约。" : nil
        } catch { if revision == store.sessionRevision { message = error.localizedDescription } }
    }
}

extension CampusStore {
    func collegeBookingClient() async -> CollegeBookingClient {
        let cookies = await sessions.cookies()
        let token = cookies.first { $0.name == "meeting_manager_token" && ["booking.sustech.edu.cn", ".booking.sustech.edu.cn"].contains($0.domain.lowercased()) }?.value ?? ""
        return CollegeBookingClient(http: ServiceHTTP(origin: SchoolService.booking.portalURL, cookies: cookies), token: token)
    }
}
