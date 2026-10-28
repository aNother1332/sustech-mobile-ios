import CampusCore
import SwiftUI

struct MyReservationsView: View {
    @Environment(CampusStore.self) private var store
    @State private var type = 0
    @State private var items: [ReservationItem] = []
    @State private var busy = false
    @State private var needsLogin = false
    @State private var portal = false
    @State private var message: String?
    @State private var cancelling: ReservationItem?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BusinessHeader(title: "我的预约", symbol: "calendar.badge.clock", color: .blue)
                Picker("类型", selection: $type) { Text("讨论间").tag(0); Text("语言辅导").tag(1) }.pickerStyle(.segmented).disabled(busy)
                IndependentConnectionStatus(connected: !needsLogin, requiresLogin: needsLogin) { portal = true }
                ServiceMessage(message: message)
                if busy { ProgressView().frame(maxWidth: .infinity) }
                ForEach(items) { item in
                    CampusCard {
                        HStack { Image(systemName: type == 0 ? "door.left.hand.open" : "bubble.left.and.bubble.right").foregroundStyle(.blue); Text(item.title).font(.headline) }
                        Text(item.detail).font(.subheadline).foregroundStyle(.secondary)
                        if type == 0 ? ReservationAgendaPolicy.activeIC(item.raw) : item.raw["YYZT"].text == "1" { Button("取消预约", role: .destructive) { cancelling = item }.disabled(busy) }
                    }
                }
                if items.isEmpty, !busy, !needsLogin, message == nil { Text("暂无预约").font(.subheadline).foregroundStyle(.secondary).frame(maxWidth: .infinity).padding(30) }
            }.padding(16).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("我的预约").navigationBarTitleDisplayMode(.inline)
            .task(id: type) { items = []; await load() }.refreshable { await load() }
            .sheet(isPresented: $portal, onDismiss: { Task { await load() } }) { SchoolBrowser(service: type == 0 ? .rooms : .cle) }
            .campusConfirmation("取消这项预约？", isPresented: Binding(get: { cancelling != nil }, set: { if !$0 { cancelling = nil } })) {
                if let item = cancelling { Button("确认取消", role: .destructive) { Task { await cancel(item) } } }
            }
    }
    private func load() async {
        while busy { do { try await Task.sleep(for: .milliseconds(100)) } catch { return } }
        guard store.mode == .live, !Task.isCancelled else { return }; busy = true; defer { busy = false }
        let revision = store.sessionRevision; let selected = type
        do {
            let result: [ReservationItem]
            if selected == 0 { try await store.sessions.connectIC(); result = try await ICClient(http: await store.serviceHTTP(origin: SchoolService.rooms.portalURL)).mine() }
            else { guard !store.sessions.cleID.isEmpty else { throw CampusError.signInRequired }; result = try await CLEClient(http: await store.serviceHTTP(origin: CLEClient.index)).mine(sid: store.sessions.cleID) }
            guard revision == store.sessionRevision, selected == type else { return }; items = result; needsLogin = false; message = nil
        } catch { guard revision == store.sessionRevision, selected == type, !Task.isCancelled else { return }; needsLogin = LoginRequirement.confirmed(error); message = needsLogin ? nil : error.localizedDescription }
    }
    private func cancel(_ item: ReservationItem) async {
        guard !busy, store.beginWrite() else { return }; busy = true
        defer { busy = false; store.endWrite() }
        let revision = store.sessionRevision; let selected = type
        do {
            if selected == 0 { try await ICClient(http: await store.serviceHTTP(origin: SchoolService.rooms.portalURL)).cancel(item) }
            else { try await CLEClient(http: await store.serviceHTTP(origin: CLEClient.index)).cancel(item) }
            let fresh: [ReservationItem]
            if selected == 0 { fresh = try await ICClient(http: await store.serviceHTTP(origin: SchoolService.rooms.portalURL)).mine() }
            else { fresh = try await CLEClient(http: await store.serviceHTTP(origin: CLEClient.index)).mine(sid: store.sessions.cleID) }
            guard revision == store.sessionRevision, selected == type else { return }
            items = fresh; message = nil
        } catch {
            guard revision == store.sessionRevision, selected == type else { return }
            needsLogin = LoginRequirement.confirmed(error)
            message = needsLogin ? nil : error.localizedDescription
        }
    }
}
