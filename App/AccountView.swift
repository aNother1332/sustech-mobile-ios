import CampusCore
import SwiftUI

struct AccountView: View {
    @Environment(CampusStore.self) private var store
    @State private var portal: SchoolService?
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                Label("南科 · 日常", systemImage: "leaf").font(.title2.bold()).foregroundStyle(Color.campusGreen)
                Text("iPhone 与 iPad · 非官方校园工具\n0.1.0 开发起点，真实接口尚待设备验证。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("数据模式") {
                Picker("当前模式", selection: Binding(get: { store.mode }, set: { store.setMode($0) })) {
                    ForEach(DataMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.disabled(store.clearing)
                Text("演示数据不会作为学校数据保存。切换模式会清空当前显示的课程与任务，不会代替学校登录。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("连接学校服务") {
                Button("打开教务登录页面") { portal = .teaching }
                Button("打开 Blackboard 登录页面") { portal = .blackboard }
                Text("两项服务分别建立会话。是否已连接，以原生同步结果为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Section("本机数据") {
                Text("密码仅在学校网页中输入，应用不读取或保存密码。网页会话由本机 WebKit 保存；本批次课程数据仅在内存中使用，没有聚合服务器或统计 SDK。")
                    .font(.callout).foregroundStyle(.secondary)
                Button(store.clearing ? "正在清除…" : "清除本机网页会话与当前数据", role: .destructive) { confirmClear = true }
                    .disabled(store.clearing)
            }
            Section("关于与来源") {
                NavigationLink("上游许可与来源") { NoticesView() }
                Text("本应用不代表南方科技大学。学校页面、规则和记录为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的")
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
        .confirmationDialog("清除本应用保存的学校网页会话？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除并退出本机会话", role: .destructive) { Task { await store.clearLocalSession() } }
        } message: { Text("当前显示的数据也会移除。之后需要在学校页面重新登录。此操作不撤销学校服务器上的会话。") }
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
        }.navigationTitle("许可与来源")
    }
}
