import SwiftUI

@main
struct SUSTechApp: App {
    @State private var store: CampusStore
    @State private var showLogin = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let state = CampusStore()
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--smoke-demo") { state.setMode(.demo) }
        if ProcessInfo.processInfo.arguments.contains("--smoke-folded") { state.setCourseHidden("demo-math", hidden: true) }
        #endif
        _store = State(initialValue: state)
    }

    @ViewBuilder private var launchContent: some View {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--smoke-agenda") { NavigationStack { AgendaView() } }
        else if arguments.contains("--smoke-printing-login") { PrintingLoginView() }
        else if arguments.contains("--smoke-settings") { NavigationStack { SettingsView() } }
        else if arguments.contains("--smoke-my-reservations") { NavigationStack { MyReservationsView() } }
        else if arguments.contains("--smoke-reviews") { NavigationStack { CourseReviewsView() } }
        else if arguments.contains("--smoke-degree") { NavigationStack { DegreeProgressView() } }
        else if arguments.contains("--smoke-recharge") { NavigationStack { CardRechargeView() } }
        else if arguments.contains("--smoke-bus") { NavigationStack { BusView() } }
        else if arguments.contains("--smoke-faculty-detail") { NavigationStack { FacultyDetailView(name: "示例教师", detail: "示例院系 · 示例职称", url: URL(string: "https://www.sustech.edu.cn/zh/faculties/wuyabei.html")!) } }
        else if arguments.contains("--smoke-faculty") { NavigationStack { FacultyDirectoryView() } }
        else if arguments.contains("--smoke-calendar") { NavigationStack { AcademicCalendarView() } }
        else if arguments.contains("--smoke-code") { NavigationStack { CampusCodeView() } }
        else if arguments.contains("--smoke-exchange") { NavigationStack { ExchangeProgramsView() } }
        else if arguments.contains("--smoke-widgets") { NavigationStack { WidgetSettingsView() } }
        else if arguments.contains("--smoke-card") { NavigationStack { CardView() } }
        else if arguments.contains("--smoke-classrooms") { NavigationStack { ClassroomView() } }
        else if arguments.contains("--smoke-print-stations") { NavigationStack { PrintExtrasView() } }
        else if arguments.contains("--smoke-college") { NavigationStack { CollegeBookingView() } }
        else if arguments.contains("--smoke-printing") { NavigationStack { PrintingView() } }
        else if arguments.contains("--smoke-reservations") { NavigationStack { ReservationCenterView() } }
        else if arguments.contains("--smoke-ic") { NavigationStack { ICReservationView() } }
        else if arguments.contains("--smoke-cle") { NavigationStack { CLEReservationView() } }
        else { RootView() }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            launchContent
                .environment(store)
                .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--smoke-dark") ? .dark : nil)
                .transformEnvironment(\.dynamicTypeSize) { value in if ProcessInfo.processInfo.arguments.contains("--smoke-large") { value = .accessibility2 } }
                .environment(\.defaultMinListRowHeight, 36)
                .task { await store.resumeSchoolConnections() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.resumeSchoolConnections() } } }
                .font(.system(.body, design: .default))
                .background { DisplayCapabilityReader().frame(width: 0, height: 0).allowsHitTesting(false) }
                .tint(.campusOrange)
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--smoke-login") { showLogin = true }
                    #endif
                }
                .sheet(isPresented: $showLogin) { NativeLoginView().environment(store)
                .environment(\.defaultMinListRowHeight, 36)
                .task { await store.resumeSchoolConnections() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.resumeSchoolConnections() } } } }
        }
    }
}
