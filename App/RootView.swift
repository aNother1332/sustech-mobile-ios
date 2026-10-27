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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
        NavigationStack {
            ZStack {
                destination(selection).id(selection).transition(.opacity)
            }
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: selection)
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) { CampusNavigation(selection: $selection) }
                .toolbarBackground(Color.campusOrange, for: .navigationBar)
                .toolbarColorScheme(.light, for: .navigationBar)
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--smoke-tab-cycle") {
                for page in [CampusPage.study, .services, .account, .today] {
                    try? await Task.sleep(for: .seconds(1))
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.76)) { selection = page }
                }
            }
            #endif
        }
        .onOpenURL { url in
            guard url.scheme == "sustechmobile", let host = url.host, ["today", "study", "code", "card", "bus", "printing", "reservations"].contains(host) else { return }
            if host == "today" { selection = .today } else if host == "study" { selection = .study } else { route = host }
        }.sheet(item: Binding(get: { route.map(CampusRoute.init) }, set: { route = $0?.id })) { value in
            NavigationStack { Group { switch value.id {
            case "code": CampusCodeView()
            case "card": CardView()
            case "bus": BusView()
            case "printing": PrintingView()
            case "reservations": ReservationCenterView()
            default: TodayView()
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
