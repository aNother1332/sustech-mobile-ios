import CampusCore
import SwiftUI

struct ServicesView: View {
    @Environment(CampusStore.self) private var store
    @State private var query = ""
    @State private var portal: SchoolService?

    private var services: [SchoolService] {
        SchoolService.allCases.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                CampusHero(eyebrow: "CAMPUS SERVICES", title: "办事", subtitle: "", symbol: "square.grid.2x2.fill")
                CampusSectionTitle(title: "校园服务")
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    if matches("校园码 身份码 扫码") { ServiceTile(title: "校园码", detail: "动态码 / 身份核验", symbol: "qrcode", color: .campusOrange) { CampusCodeView().id(store.sessionRevision) } }
                    if matches("校园卡 余额 账单 消费") { ServiceTile(title: "校园卡", detail: "余额 · 账单 · 消费曲线", symbol: "creditcard.fill", color: .campusOrange) { CardView().id(store.sessionRevision) } }
                    if matches("校车 站点 线路") { ServiceTile(title: "校车", detail: "附近站点 · 预计到站", symbol: "bus.fill", color: .campusGreen) { BusView() } }
                    if matches("空教室 自习") { ServiceTile(title: "空教室", detail: "找教室 · 查占用", symbol: "building.2.fill", color: .blue) { ClassroomView().id(store.sessionRevision) } }
                    if matches("打印 PDF 扫描") { ServiceTile(title: "校园打印", detail: "上传 · 队列 · 扫描", symbol: "printer.fill", color: .campusGreen) { PrintingView().id(store.sessionRevision) } }
                    if matches("预约 IC CLE 体育") { ServiceTile(title: "预约中心", detail: "IC · CLE · 体育场馆", symbol: "calendar.badge.plus", color: .purple) { ReservationCenterView().id(store.sessionRevision) } }
                    if matches("图书馆 借阅 馆藏 续借") { ServiceTile(title: "图书馆", detail: "馆藏 · 借阅 · 座位", symbol: "books.vertical.fill", color: .campusGreen) { LibraryView().id(store.sessionRevision) } }
                    if matches("日程 提醒") { ServiceTile(title: "我的日程", detail: "课程 · 考试 · 截止日期", symbol: "calendar", color: .campusOrange) { AgendaView().id(store.sessionRevision) } }
                    if matches("校历 调休 放假") { ServiceTile(title: "教学日历", detail: "教学周 · 放假 · 补课", symbol: "calendar.circle.fill", color: .campusCyan) { AcademicCalendarView() } }
                    if matches("教师 目录 院系") { ServiceTile(title: "教师目录", detail: "姓名 · 院系 · 官方主页", symbol: "person.2.fill", color: .blue) { FacultyDirectoryView() } }
                    if matches("交换 留学 国际 项目") { ServiceTile(title: "交换项目", detail: "学校 · 申请时间 · 状态", symbol: "globe.asia.australia.fill", color: .purple) { ExchangeProgramsView().id(store.sessionRevision) } }
                    if matches("排课 选课 方案") { ServiceTile(title: "排课工作台", detail: "候选课程 · 冲突检查", symbol: "rectangle.3.group.fill", color: .blue) { PlannerView() } }
                    if matches("课程 评价 NCES") { ServiceTile(title: "课程评价", detail: "搜索 · 社区评价 · 收藏", symbol: "star.bubble.fill", color: .campusOrange) { CourseReviewsView() } }
                    if matches("学业 修读 学分") { ServiceTile(title: "修读进度", detail: "学校培养方案与学分", symbol: "chart.bar.fill", color: .campusGreen) { DegreeProgressView().id(store.sessionRevision) } }
                    if matches("网络 连接 诊断") { ServiceTile(title: "网络诊断", detail: "学校服务可达性", symbol: "network", color: .blue) { DiagnosticsView() } }
                    if matches("软件 更新 版本") { ServiceTile(title: "软件更新", detail: "发布说明 · 安装指引", symbol: "arrow.down.app.fill", color: .campusGreen) { AppUpdatesView() } }
                }
                DisclosureGroup("学校网页备用入口") {

                ForEach(services) { service in
                    NavigationLink {
                        VStack(spacing: 20) {
                            CampusCard {
                                Label(service.title, systemImage: service.symbol).font(.title2.bold())
                                Text(service.summary).foregroundStyle(.secondary)
                                Text("学校网页入口").font(.caption).foregroundStyle(.secondary)
                                PortalActions(service: service) { portal = service }
                            }
                            Spacer()
                        }.padding().background(Color(uiColor: .systemGroupedBackground))
                            .navigationTitle(service.title)
                    } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(service.title)
                                Text(service.summary).font(.caption).foregroundStyle(.secondary)
                            }.padding(.vertical, 4)
                        } icon: { Image(systemName: service.symbol).foregroundStyle(Color.campusGreen) }
                    }
                }
            }
            }.padding(14).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $query, prompt: "搜索校园服务")
        .refreshable { await store.checkSchoolSessions(force: true) }
        .navigationTitle("办事").navigationBarTitleDisplayMode(.inline)
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }
    private func matches(_ value: String) -> Bool { query.isEmpty || value.localizedCaseInsensitiveContains(query) }
}
