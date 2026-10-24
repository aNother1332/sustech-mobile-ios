import CampusCore
import SwiftUI

struct ServicesView: View {
    @State private var query = ""
    @State private var portal: SchoolService?

    private var services: [SchoolService] {
        SchoolService.allCases.filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) || $0.summary.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        List {
            Section {
                Text("本批次提供学校网页入口。余额、预约、打印等原生功能尚在后续计划中；支付与部分跨站跳转请使用系统浏览器。")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Section("校园服务") {
                ForEach(services) { service in
                    NavigationLink {
                        VStack(spacing: 20) {
                            CampusCard {
                                Label(service.title, systemImage: service.symbol).font(.title2.bold())
                                Text(service.summary).foregroundStyle(.secondary)
                                Text("学校网页入口 · 原生对齐待完成").font(.caption).foregroundStyle(.secondary)
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
            if services.isEmpty { ContentUnavailableView.search(text: query) }
        }
        .searchable(text: $query, prompt: "搜索校园服务")
        .navigationTitle("办事")
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }
}
