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
        List {
            Section {
                Text("校园查询、打印与预约。应用内学校页面共享登录态；独立授权或学校要求额外验证时，按提示完成连接。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("原生校园服务") {
                if matches("校园卡 余额 账单 消费 曲线") { NavigationLink { CardView().id(store.sessionRevision) } label: { Label("校园卡与消费曲线", systemImage: "creditcard") } }
                if matches("空教室 教学楼 自习") { NavigationLink { ClassroomView().id(store.sessionRevision) } label: { Label("空教室查询", systemImage: "building.2") } }
                if matches("校车 站点 到站 线路") { NavigationLink { BusView() } label: { Label("校车查询", systemImage: "bus") } }
                if matches("打印 PDF 队列") { NavigationLink { PrintingView().id(store.sessionRevision) } label: { Label("校园打印", systemImage: "printer") } }
                if matches("预约 IC CLE 体育 场馆 研讨间") { NavigationLink { ReservationCenterView().id(store.sessionRevision) } label: { Label("预约中心 · IC / CLE / 体育", systemImage: "calendar.badge.plus") } }
            }
            Section("学校网页备用入口") {
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
        }
        .searchable(text: $query, prompt: "搜索校园服务")
        .navigationTitle("办事")
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }
    private func matches(_ value: String) -> Bool { query.isEmpty || value.localizedCaseInsensitiveContains(query) }
}
