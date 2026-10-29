import CampusCore
import SwiftUI

struct StudentServicesView: View {
    let app: StudentServiceApp
    @Environment(CampusStore.self) private var store
    @State private var records: [StudentServiceRecord] = []
    @State private var page = 0
    @State private var more = false
    @State private var busy = false
    @State private var message: String?
    @State private var needsLogin = false
    @State private var login = false
    @State private var form = false
    private var service: SchoolService { app == .leave ? .leave : .activities }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                BusinessHeader(title: app.title, symbol: app == .leave ? "doc.text" : "sparkles", color: app == .leave ? .campusGreen : .campusOrange)
                if app == .leave {
                    Button { form = true } label: {
                        HStack { Image(systemName: "square.and.pencil"); Text("申请请假").fontWeight(.semibold); Spacer(); Image(systemName: "arrow.up.right") }.padding(17).foregroundStyle(.white).background(Color.campusGreen, in: RoundedRectangle(cornerRadius: 16))
                    }.buttonStyle(.plain)
                }
                if needsLogin { IndependentConnectionStatus(connected: false, requiresLogin: true) { login = true } }
                ServiceMessage(message: message, hideLogin: needsLogin)
                if records.isEmpty && !busy && message == nil && !needsLogin { Text(app == .leave ? "暂无请假记录" : "暂无活动").foregroundStyle(.secondary).padding(.vertical, 12) }
                ForEach(records) { record in
                    NavigationLink { StudentServiceDetail(app: app, record: record) } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(alignment: .top) {
                                Image(systemName: app == .leave ? "doc.text.fill" : "sparkles").font(.title2).foregroundStyle(app == .leave ? Color.campusGreen : .campusOrange).frame(width: 45, height: 45).background((app == .leave ? Color.campusGreen : .campusOrange).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 5) { Text(record.title).font(.headline).foregroundStyle(.primary); if !record.subtitle.isEmpty { Text(record.subtitle).font(.caption).foregroundStyle(.secondary) } }
                                Spacer(minLength: 0); Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                            }
                            if !record.start.isEmpty { Label(record.start + (record.end.isEmpty ? "" : " — " + record.end), systemImage: "calendar").font(.caption).foregroundStyle(.secondary) }
                            if !record.location.isEmpty { Label(record.location, systemImage: "mappin.and.ellipse").font(.caption).foregroundStyle(.secondary) }
                            if !record.text.isEmpty { Text(record.text).font(.subheadline).lineLimit(3).foregroundStyle(.primary.opacity(0.75)) }
                        }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 18))
                    }.buttonStyle(.plain)
                }
                if busy { ProgressView().frame(maxWidth: .infinity).padding() }
                if more { Button("加载更多") { Task { await load(reset: false) } }.disabled(busy).frame(maxWidth: .infinity).padding() }
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle(app.title).navigationBarTitleDisplayMode(.inline)
            .task { await load(reset: true) }.refreshable { await load(reset: true) }
            .sheet(isPresented: $login, onDismiss: { Task { await load(reset: true) } }) { NativeLoginView() }
            .sheet(isPresented: $form, onDismiss: { Task { await load(reset: true) } }) { SchoolBrowser(service: .leave, openLeaveForm: true) }
    }
    private func load(reset: Bool) async {
        guard !busy else { return }; busy = true; defer { busy = false }
        let revision = store.sessionRevision
        #if DEBUG
        if store.mode == .demo {
            let row: WireValue = app == .leave ? .object(["WID": .string("sample"), "QJLX_DISPLAY": .string("事假（虚构示例）"), "QJKSSJ": .string("2026-11-02"), "QJJSSJ": .string("2026-11-03"), "QJTS": .string("2 天"), "QJSY": .string("示例请假事由")]) : .object(["WID": .string("sample"), "HDMC": .string("校园文化活动（虚构示例）"), "HDKSSJ": .string("2026-11-02 19:00"), "HDDD": .string("示例活动中心"), "HDJS": .string("校园活动介绍"), "HDLXDM_DISPLAY": .string("文化活动")])
            records = (try? StudentServiceRecord.parse(row, app: app)).map { [$0] } ?? []; return
        }
        #endif
        guard store.mode == .live else { return }
        do {
            try await store.prepareBusiness(service)
            let http = await store.serviceHTTP(origin: app.entry)
            let next = reset ? 1 : page + 1
            let result = try await StudentServicesClient(app: app, http: http).records(page: next)
            guard revision == store.sessionRevision, !Task.isCancelled else { return }
            records = reset ? result.records : records + result.records.filter { item in !records.contains { $0.id == item.id } }
            page = next; more = result.hasMore; message = nil; needsLogin = false
            await store.absorb(http, revision: revision)
        } catch { guard revision == store.sessionRevision, !Task.isCancelled else { return }; needsLogin = LoginRequirement.confirmed(error); message = needsLogin ? nil : error.localizedDescription }
    }
}

private struct StudentServiceDetail: View {
    let app: StudentServiceApp
    let record: StudentServiceRecord
    @Environment(CampusStore.self) private var store
    @State private var detail: StudentServiceRecord?
    @State private var message: String?
    private var value: StudentServiceRecord { detail ?? record }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(value.title).font(.title2.bold())
                if !value.subtitle.isEmpty { Text(value.subtitle).foregroundStyle(.secondary) }
                Divider()
                if !value.start.isEmpty { Label(value.start + (value.end.isEmpty ? "" : " — " + value.end), systemImage: "calendar") }
                if !value.location.isEmpty { Label(value.location, systemImage: "mappin.and.ellipse") }
                if !value.status.isEmpty { Text(value.status).foregroundStyle(.campusGreen) }
                Text(value.text).font(.body).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                ServiceMessage(message: message)
            }.padding(20).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Color.campusPaper).navigationTitle(app == .leave ? "请假详情" : "活动详情").navigationBarTitleDisplayMode(.inline)
            .task { await load() }.refreshable { await load() }
    }
    private func load() async {
        guard app == .leave, store.mode == .live else { return }
        let revision = store.sessionRevision
        do {
            try await store.prepareBusiness(.leave)
            let http = await store.serviceHTTP(origin: app.entry)
            let result = try await StudentServicesClient(app: app, http: http).leaveDetail(record.id)
            guard revision == store.sessionRevision, !Task.isCancelled else { return }
            detail = result; message = nil; await store.absorb(http, revision: revision)
        } catch { if revision == store.sessionRevision, !Task.isCancelled { message = error.localizedDescription } }
    }
}
