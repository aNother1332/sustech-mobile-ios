import CampusCore
import SwiftUI

struct AccountView: View {
    @Environment(CampusStore.self) private var store
    @State private var portal: SchoolService?
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                Label("SUSTechMobile", systemImage: "leaf").font(.title2.bold()).foregroundStyle(Color.campusGreen)
                Text("iPhone 与 iPad · 非官方校园工具\n0.4.0 试用版 · 学校接口需真机核对。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("数据模式") {
                Picker("当前模式", selection: Binding(get: { store.mode }, set: { store.setMode($0) })) {
                    ForEach(DataMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.disabled(store.clearing || store.authenticating || store.writing)
                Text("演示与学校数据隔离")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("连接学校服务") {
                HStack { Text("教务"); Spacer(); NativeLoginButton(service: .teaching) }
                HStack { Text("Blackboard"); Spacer(); NativeLoginButton(service: .blackboard) }
                Button("检测全部连接") { Task { await store.checkSchoolSessions(force: true) } }
                DisclosureGroup("网页登录备用") {
                    Button("教务学校页面") { portal = .teaching }
                    Button("Blackboard 学校页面") { portal = .blackboard }
                }
            }
            Section("本机数据") {
                if let message = store.cacheMessage { Text(message).foregroundStyle(.orange) }
                DetailNote(title: "存储与隐私", text: "会话和文件保存在本机，不保存登录密码，没有聚合服务器或统计 SDK。退出时清除学校缓存与下载。")
                    .font(.callout).foregroundStyle(.secondary)
                Button(store.clearing ? "正在清除…" : "清除本机会话、离线数据与下载文件", role: .destructive) { confirmClear = true }
                    .disabled(store.clearing || store.writing)
            }
            Section("关于与来源") {
                NavigationLink("上游许可与来源") { NoticesView() }
                Text("本应用不代表南方科技大学。学校页面、规则和记录为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
        .refreshable { await store.checkSchoolSessions(force: true) }
        .onChange(of: portal) { _, value in if value == nil { Task { await store.checkSchoolSessions(force: true) } } }
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
        .confirmationDialog("清除本机会话、缓存和下载文件？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除并退出本机会话", role: .destructive) { Task { await store.clearLocalSession() } }
        } message: { Text("已下载课件也会移除。之后需要重新登录；此操作不撤销学校服务器上的会话。") }
    }
}

private struct NoticesView: View {
    private var license: String {
        guard let url = Bundle.main.url(forResource: "UpstreamLicense", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            return "PolyForm Noncommercial 1.0.0\nhttps://polyformproject.org/licenses/noncommercial/1.0.0\nRequired Notice: Copyright dumixthestpd (https://github.com/dumixthestpd/sustech_survival)"
        }
        return text
    }

    var body: some View {
        List {
            Section("协议与业务参考") {
                Link("sustech-mobile · dumixthestpd", destination: URL(string: "https://github.com/dumixthestpd/sustech-mobile")!)
                Link("sustech-cli · wormforce", destination: URL(string: "https://github.com/wormforce/sustech-cli")!)
                Link("sustech_survival · dumixthestpd", destination: URL(string: "https://github.com/dumixthestpd/sustech_survival")!)
            }
            Section("上游许可") { Text(license).font(.caption).textSelection(.enabled) }
        }.navigationTitle("许可与来源").navigationBarTitleDisplayMode(.inline)
    }
}
