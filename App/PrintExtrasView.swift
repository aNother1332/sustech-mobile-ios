import CampusCore
import SwiftUI

struct PrintExtrasView: View {
    @Environment(CampusStore.self) private var store
    @State private var tab = 0
    @State private var rows: [WireValue] = []
    @State private var begin = Date.now.addingTimeInterval(-30 * 86400)
    @State private var end = Date.now
    @State private var page = 1
    @State private var type = 1
    @State private var pages = 1
    @State private var message: String?
    @State private var busy = false
    @State private var deleting: WireValue?
    var body: some View {
        List {
            Section { BusinessHeader(title: "打印服务", symbol: "printer.dotmatrix", color: .blue) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)

            Section {
                if tab != 0 { SessionBadge(service: .printing) }
                Picker("查询", selection: $tab) { Text("打印站点").tag(0); Text("扫描任务").tag(1); Text("用量").tag(2) }.pickerStyle(.segmented).disabled(busy)
                if tab == 2 {
                    DatePicker("开始", selection: $begin, displayedComponents: .date); DatePicker("结束", selection: $end, displayedComponents: .date)
                    Picker("类型", selection: $type) { Text("打印").tag(1); Text("扫描").tag(2); Text("复印").tag(3) }
                }
                EmptyView()
                if busy { ProgressView() }; ServiceMessage(message: message, hideLogin: tab != 0)
            }
            if rows.isEmpty && !busy { Text(tab == 0 ? "暂无站点数据，请下拉刷新。" : "暂无记录").foregroundStyle(.secondary) }
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                VStack(alignment: .leading, spacing: 3) {
                    if tab == 0 {
                        Text(row["szName"].text).font(.subheadline.bold())
                        Text(row["szStatInfo"].text).font(.caption).foregroundStyle(.secondary)
                        let status = row["dwStatus"].int
                        Text(status.map { $0 == 0 ? "未开放" : ($0 & 1 != 0 ? "空闲" : ($0 & 2 != 0 ? "忙碌" : "状态需核对")) } ?? "状态未知").font(.caption).foregroundStyle(.secondary)
                    } else if tab == 1 {
                        Text(row["szDisplayName"].text).font(.subheadline.bold())
                        Text("\(row["dwFileSize"].text) 字节 · \(row["dwSubmitDate"].text) \(row["dwSubmitTime"].text)").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("\(row["dwDate"].text) · \(row["dwPages"].text) 页").font(.subheadline)
                        let cents = (row["dwUsedCardMoney"].int ?? 0) + (row["dwUsedFreeMoney"].int ?? 0) + (row["dwUsedMoney"].int ?? 0)
                        Text("¥\((Double(cents) / 100).formatted(.number.precision(.fractionLength(2))))").font(.caption)
                    }
                }.swipeActions {
                    if tab == 1, row["dwJobId"].int != nil { Button("删除", role: .destructive) { deleting = row }.disabled(busy || store.writing) }
                }
            }
            if tab == 2 && page < pages { Button("下一页 · \(page)/\(pages)") { Task { page += 1; await load() } }.disabled(busy) }
            if tab == 1 { DetailNote(text: "此处读取扫描任务元数据。下载地址尚未验证，领取原文件请使用学校打印页面。") }
        }.navigationTitle("打印站点与用量").navigationBarTitleDisplayMode(.inline).refreshable { page = 1; await load() }
        .task { await load() }.onChange(of: tab) { _, _ in rows = []; page = 1; Task { await load() } }
        .campusConfirmation("删除此扫描文件？", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            Button("从学校服务器删除", role: .destructive) { if let item = deleting { deleting = nil; Task { await remove(item) } } }
        } message: { Text("将删除学校打印系统中的扫描文件，无法在应用中恢复。") }
    }
    private func remove(_ row: WireValue) async {
        guard !busy, let id = row["dwJobId"].int, store.beginWrite() else { return }
        busy = true; defer { busy = false; store.endWrite() }
        let version = store.sessionRevision; let http = await store.serviceHTTP(.printing)
        do {
            let reply = try await http.json("/api/client/Scan/Del", payload: .object(["dwJobId": .integer(Int64(id))]))
            guard version == store.sessionRevision else { return }
            guard reply["code"].int == 0 else { throw ServiceFailure(reply["message"].text.isEmpty ? "学校未确认删除成功。" : reply["message"].text) }
            rows.removeAll { $0["dwJobId"].int == id }; message = "扫描任务已删除。"; store.recordSession(.printing)
        } catch { guard version == store.sessionRevision else { return }; message = "未确认删除结果，请刷新任务列表核对；不会自动重试。"; store.recordSession(.printing, error: error) }
        await store.absorb(http, revision: version)
    }
    private func load() async {
        if store.mode == .demo {
            rows = tab == 0 ? [.object(["szName": .string("示例教学楼 · 彩色打印"), "szStatInfo": .string("虚构示例设备"), "dwStatus": .integer(1)]), .object(["szName": .string("示例图书馆 · 黑白打印"), "szStatInfo": .string("虚构示例设备"), "dwStatus": .integer(2)])] : []
            message = "演示站点，不代表真实设备状态。"; return
        }
        guard !busy, store.mode == .live, begin <= end else { return }; busy = true; defer { busy = false }
        let version = store.sessionRevision; let selected = tab
        if selected == 0 {
            do {
                let stations = try await PrintingClient.publicStations()
                guard version == store.sessionRevision, selected == tab else { return }
                rows = stations; message = "共 \(stations.count) 个站点 · " + Date.now.formatted(date: .omitted, time: .shortened)
            } catch { if version == store.sessionRevision, selected == tab { message = error.localizedDescription } }
            return
        }
        let http = await store.serviceHTTP(.printing)
        do {
            let response: WireValue
            if selected == 2 {
                response = try await http.json("/api/client/Report/DetailPage", payload: .object(["dwBeginDate": .string(CampusClock.format(begin, "yyyyMMdd")), "dwEndDate": .string(CampusClock.format(end, "yyyyMMdd")), "dwType": .integer(Int64(type)), "dwPageNo": .integer(Int64(page)), "dwRowCount": .integer(50)]))
            } else { response = try await http.json(selected == 0 ? "/api/client/Station/GetList" : "/api/client/Scan/Get", query: ["timestamp": "0"]) }
            let value = try PrintingClient.unwrap(response)
            guard case .array = value else { throw CampusError.invalidResponse("打印扩展查询") }
            guard version == store.sessionRevision, selected == tab else { return }; rows = value.rows; pages = response["dwTotalPage"].int ?? 1; message = "更新于 " + Date.now.formatted(date: .omitted, time: .shortened); store.recordSession(.printing)
        } catch { guard version == store.sessionRevision, selected == tab else { return }; message = error.localizedDescription; store.recordSession(.printing, error: error) }
        await store.absorb(http, revision: version)
    }
}
