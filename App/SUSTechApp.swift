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
        if arguments.contains("--smoke-library") { NavigationStack { LibraryView() } }
        else if arguments.contains("--smoke-agenda") { NavigationStack { AgendaView() } }
        else if arguments.contains("--smoke-planner") { NavigationStack { PlannerView() } }
        else if arguments.contains("--smoke-reviews") { NavigationStack { CourseReviewsView() } }
        else if arguments.contains("--smoke-degree") { NavigationStack { DegreeProgressView() } }
        else if arguments.contains("--smoke-recharge") { NavigationStack { CardRechargeView() } }
        else if arguments.contains("--smoke-card") { NavigationStack { CardView() } }
        else if arguments.contains("--smoke-classrooms") { NavigationStack { ClassroomView() } }
        else if arguments.contains("--smoke-printing") { NavigationStack { PrintingView() } }
        else if arguments.contains("--smoke-reservations") { NavigationStack { ReservationCenterView() } }
        else if arguments.contains("--smoke-ic") { NavigationStack { ICReservationView() } }
        else if arguments.contains("--smoke-cle") { NavigationStack { CLEReservationView() } }
        else if arguments.contains("--smoke-court") { NavigationStack { CourtReservationView() } }
        else { RootView() }
        #else
        RootView()
        #endif
    }

    var body: some Scene {
        WindowGroup {
            launchContent
                .environment(store)
                .environment(\.defaultMinListRowHeight, 36)
                .task { await store.checkSchoolSessions() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.checkSchoolSessions() } } }
                .tint(.campusGreen)
                .onAppear {
                    #if DEBUG
                    if ProcessInfo.processInfo.arguments.contains("--smoke-login") { showLogin = true }
                    #endif
                }
                .sheet(isPresented: $showLogin) { NativeLoginView().environment(store)
                .environment(\.defaultMinListRowHeight, 36)
                .task { await store.checkSchoolSessions() }
                .onChange(of: scenePhase) { _, phase in if phase == .active { Task { await store.checkSchoolSessions() } } } }
        }
    }
}
