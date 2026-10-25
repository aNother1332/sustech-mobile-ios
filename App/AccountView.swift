import CampusCore
import SwiftUI

struct AccountView: View {
    @Environment(CampusStore.self) private var store
    @State private var portal: SchoolService?
    @State private var confirmClear = false

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 14) {
                        Image(systemName: "person.crop.circle").font(.system(size: 48, weight: .light)).foregroundStyle(.white)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(store.profile?.name.isEmpty == false ? store.profile!.name : "我的").font(.title2.bold())
                            if let id = store.profile?.studentID, !id.isEmpty { Text(id).font(.subheadline).textSelection(.enabled) }
                            else if let account = store.loginAccount ?? store.rememberedUsername { Text("账号 " + account).font(.subheadline).textSelection(.enabled) }
                        }
                        Spacer()
                        Button { Task { await store.refreshProfile() } } label: { Image(systemName: "arrow.clockwise") }.accessibilityLabel("刷新个人信息")
                    }
                    if let profile = store.profile {
                        let fields = [profile.major, profile.department, profile.college].filter { !$0.isEmpty }
                        if !fields.isEmpty { Text(fields.joined(separator: " · ")).font(.subheadline).textSelection(.enabled) }
                    }
                }.foregroundStyle(.white).padding(20).frame(maxWidth: .infinity, alignment: .leading).background(CampusPalette.header, in: RoundedRectangle(cornerRadius: 21))
                if let message = store.profileMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
            }.listRowSeparator(.hidden)
            Section("数据模式") {
                Picker("当前模式", selection: Binding(get: { store.mode }, set: { store.setMode($0) })) {
                    ForEach(DataMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.disabled(store.clearing || store.authenticating || store.writing)
            }
            Section("连接学校服务") {
                HStack { Text("教务"); Spacer(); NativeLoginButton(service: .teaching) }
                HStack { Text("Blackboard"); Spacer(); NativeLoginButton(service: .blackboard) }
                if let username = store.rememberedUsername {
                    LabeledContent("已记住账号", value: username)
                    Button("关闭自动登录并删除记住的密码", role: .destructive) { store.forgetSchoolAccount() }.disabled(store.authenticating)
                }
                if let message = store.automaticLoginMessage { Text(message).font(.caption).foregroundStyle(.secondary) }
                Button("检测全部连接") { Task { await store.checkSchoolSessions(force: true) } }
                DisclosureGroup("网页登录备用") {
                    Button("教务学校页面") { portal = .teaching }
                    Button("Blackboard 学校页面") { portal = .blackboard }
                }
            }
            Section("本机数据") {
                if let message = store.cacheMessage { Text(message).foregroundStyle(.orange) }
                DetailNote(title: "存储与隐私", text: "会话和文件保存在本机，账号密码仅在你选择记住时存入本机钥匙串，没有聚合服务器或统计 SDK。退出时清除学校缓存与下载。")
                    .font(.callout).foregroundStyle(.secondary)
                Button(store.clearing ? "正在清除…" : "清除本机会话、离线数据与下载文件", role: .destructive) { confirmClear = true }
                    .disabled(store.clearing || store.writing)
            }
            Section("工具与偏好") {
                NavigationLink("网络与服务诊断") { DiagnosticsView().toolbar(.visible, for: .navigationBar) }
                NavigationLink("检查软件更新") { AppUpdatesView().toolbar(.visible, for: .navigationBar) }
                NavigationLink("教学日历与培养层次") { AcademicCalendarView().toolbar(.visible, for: .navigationBar) }
                NavigationLink("桌面小组件设置") { WidgetSettingsView().toolbar(.visible, for: .navigationBar) }
            }
            Section("关于与来源") {
                NavigationLink("上游许可与来源") { NoticesView().toolbar(.visible, for: .navigationBar) }
                Text("本应用不代表南方科技大学。学校页面、规则和记录为准。")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("我的").navigationBarTitleDisplayMode(.inline)
        .task { await store.refreshProfile() }
        .refreshable { await store.refreshProfile(); await store.checkSchoolSessions(force: true) }
        .onChange(of: portal) { _, value in if value == nil { Task { await store.checkSchoolSessions(force: true) } } }
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
        .campusConfirmation("清除本机会话、缓存和下载文件？", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("清除并退出本机会话", role: .destructive) { Task { await store.clearLocalSession() } }
        } message: { Text("已下载课件也会移除。记住的账号密码也会删除。之后需要重新登录；此操作不撤销学校服务器上的会话。") }
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
            Section("公开资料与设计来源") {
                Link("学校标识与标准色", destination: URL(string: "https://www.sustech.edu.cn/zh/school_logo.html")!)
                Link("sustech-calendar · 校历数据", destination: URL(string: "https://github.com/dumixthestpd/sustech-calendar")!)
                Link("sustech-online-ng · CRA 校园巴士", destination: URL(string: "https://github.com/sustech-cra/sustech-online-ng")!)
                NavigationLink("校园巴士数据许可 · CC BY-SA 4.0") {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            ForEach(["BusDataAttribution", "BusDataLicense"], id: \.self) { name in
                                if let url = Bundle.main.url(forResource: name, withExtension: "txt"), let text = try? String(contentsOf: url, encoding: .utf8) { Text(text).font(.caption).textSelection(.enabled) }
                            }
                        }.padding()
                    }.navigationTitle("巴士数据来源与许可").navigationBarTitleDisplayMode(.inline)
                }
                Link("Open-Meteo · 空气质量（CC BY 4.0）", destination: URL(string: "https://open-meteo.com/en/docs/air-quality-api")!)
                Text("教师资料使用上游收录的学校公开目录快照，最新资料以教师官方主页为准。").font(.caption).foregroundStyle(.secondary)
            }
            Section("上游许可") { Text(license).font(.caption).textSelection(.enabled) }
        }.navigationTitle("许可与来源").navigationBarTitleDisplayMode(.inline)
    }
}
