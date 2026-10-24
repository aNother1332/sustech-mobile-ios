import SwiftUI

enum CampusPage: String, CaseIterable, Identifiable {
    case today = "今天"
    case study = "学习"
    case services = "办事"
    case account = "我的"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .study: "books.vertical"
        case .services: "square.grid.2x2"
        case .account: "person.crop.circle"
        }
    }
}

struct RootView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: CampusPage = .today

    var body: some View {
        if sizeClass == .regular {
            NavigationSplitView {
                List(CampusPage.allCases, selection: Binding<CampusPage?>(
                    get: { selection }, set: { if let value = $0 { selection = value } }
                )) { page in
                    Label(page.rawValue, systemImage: page.symbol).tag(page)
                }
                .navigationTitle("南科 · 日常")
                .safeAreaInset(edge: .bottom) {
                    Text("非官方校园工具 · 早期开发版")
                        .font(.caption).foregroundStyle(.secondary).padding()
                }
            } detail: {
                NavigationStack { destination(selection) }
            }
        } else {
            TabView(selection: $selection) {
                ForEach(CampusPage.allCases) { page in
                    NavigationStack { destination(page) }
                        .tabItem { Label(page.rawValue, systemImage: page.symbol) }
                        .tag(page)
                }
            }
        }
    }

    @ViewBuilder
    private func destination(_ page: CampusPage) -> some View {
        switch page {
        case .today: TodayView()
        case .study: StudyView()
        case .services: ServicesView()
        case .account: AccountView()
        }
    }
}

