import CampusCore
import SwiftUI

struct AccountView: View {
    @Environment(CampusStore.self) private var store
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(alignment: .top, spacing: 16) {
                        ZStack {
                            Circle().fill(.white.opacity(0.18)).frame(width: 78, height: 78)
                            Image(systemName: "person.crop.circle").font(.system(size: 59, weight: .ultraLight))
                        }
                        VStack(alignment: .leading, spacing: 8) {
                            Text(store.profile?.name.isEmpty == false ? store.profile!.name : "我的").font(.largeTitle.bold())
                            if let number = store.profile?.studentID, !number.isEmpty { Text(number).font(.headline.monospacedDigit()) }
                        }
                        Spacer()
                        NavigationLink { SettingsView().toolbar(.visible, for: .navigationBar) } label: { Image(systemName: "gearshape").font(.title2).padding(10).background(.white.opacity(0.15), in: Circle()) }.accessibilityLabel("设置")
                    }
                    if let profile = store.profile {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 18) {
                            field("专业", profile.major); field("院系", profile.department); field("书院", profile.college)
                        }
                    }
                }.foregroundStyle(.white).padding(24).frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
                    .background { CampusHeaderBackground().clipShape(RoundedRectangle(cornerRadius: 28)) }
                NativeLoginButton()
                ServiceMessage(message: store.profileMessage, hideLogin: true)
                CampusSectionTitle(title: "常用")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ServiceTile(title: "我的预约", detail: "", symbol: "calendar.badge.clock", color: .blue) { MyReservationsView().toolbar(.visible, for: .navigationBar) }
                    ServiceTile(title: "下载文件", detail: "", symbol: "folder", color: .campusOrange) { OfflineDownloadsView().toolbar(.visible, for: .navigationBar) }
                    ServiceTile(title: "日程提醒", detail: "", symbol: "bell", color: .campusGreen) { AgendaView().toolbar(.visible, for: .navigationBar) }
                }
            }.padding(16).frame(maxWidth: 900).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground))
            .task(id: store.sessionRevision) { await store.refreshProfile() }
            .refreshable { await store.refreshProfile() }
    }
    @ViewBuilder private func field(_ title: String, _ value: String) -> some View {
        if !value.isEmpty { VStack(alignment: .leading, spacing: 5) { Text(title).font(.caption).foregroundStyle(.white.opacity(0.75)); Text(value).font(.subheadline.weight(.semibold)) } }
    }
}

struct SettingsView: View {
    @Environment(CampusStore.self) private var store
    @State private var login = false
    @State private var confirmClear = false
    var body: some View {
        List {
            Section("账号") {
                Button("账号与登录", systemImage: "person.crop.circle") { login = true }
                if store.remembersSchoolAccount { Button("关闭自动登录") { store.forgetSchoolAccount() } }
                Button("退出登录", role: .destructive) { confirmClear = true }
            }
            Section("偏好") {
                NavigationLink("教学日历", destination: AcademicCalendarView())
                NavigationLink("桌面小组件", destination: WidgetSettingsView())
            }
            Section("存储") {
                NavigationLink("下载文件", destination: OfflineDownloadsView())
                Button("清除缓存与下载", role: .destructive) { confirmClear = true }
            }
            Section("应用") {
                NavigationLink("检查更新", destination: AppUpdatesView())
                NavigationLink("网络诊断", destination: DiagnosticsView())
                NavigationLink("关于与来源", destination: NoticesView())
            }
        }.navigationTitle("设置").navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $login) { NativeLoginView() }
            .campusConfirmation("退出并清除本机缓存与下载？", isPresented: $confirmClear) {
                Button("确认清除", role: .destructive) { Task { await store.clearLocalSession() } }
            }
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
