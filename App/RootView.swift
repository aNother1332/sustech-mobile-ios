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
    @State private var route: String?

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let page = arguments.contains("--smoke-services") ? CampusPage.services
            : arguments.contains("--smoke-account") ? .account
            : arguments.contains("--smoke-study") ? .study : .today
        _selection = State(initialValue: page)
        #endif
    }

    var body: some View {
        Group {
        if sizeClass == .regular {
            NavigationSplitView {
                List(CampusPage.allCases, selection: Binding<CampusPage?>(
                    get: { selection }, set: { if let value = $0 { selection = value } }
                )) { page in
                    Label(page.rawValue, systemImage: page.symbol).tag(page)
                }
                .navigationTitle("SUSTechMobile").navigationBarTitleDisplayMode(.inline)
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
        }.onOpenURL { url in
            guard url.scheme == "sustechmobile", let host = url.host, ["today", "study", "code", "card", "bus", "printing", "reservations", "library"].contains(host) else { return }
            if host == "today" { selection = .today } else if host == "study" { selection = .study } else { route = host }
        }.sheet(item: Binding(get: { route.map(CampusRoute.init) }, set: { route = $0?.id })) { value in
            NavigationStack { Group { switch value.id {
            case "code": CampusCodeView()
            case "card": CardView()
            case "bus": BusView()
            case "printing": PrintingView()
            case "reservations": ReservationCenterView()
            default: LibraryView()
            } }.toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { route = nil } } } }
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

private struct CampusRoute: Identifiable { let id: String; init(_ id: String) { self.id = id } }
