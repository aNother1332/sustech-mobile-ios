import CampusCore
import SwiftUI

struct TodayView: View {
    @Environment(CampusStore.self) private var store
    @Environment(\.scenePhase) private var phase
    private var pendingCount: String {
        guard let snapshot = store.blackboard else { return "—" }
        if store.mode == .live, store.courseDetails.isEmpty, !snapshot.courses.isEmpty { return "—" }
        return "\(store.deadlines.filter { ($0.submission == .pending || $0.submission == .draft) && ($0.due ?? .distantPast) > .now }.count) 项"
    }
    var body: some View {
        ScrollViewReader { proxy in
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    CampusHero(eyebrow: "", title: AcademicData.dateTitle(context.date), subtitle: AcademicData.term(at: context.date).map { "第 \($0.week(context.date)) 教学周" } ?? "", symbol: "sun.max")
                }
                HStack(spacing: 0) {
                    quick("校园卡", "creditcard") { CardView().id(store.sessionRevision) }
                    quick("校车", "bus") { BusView() }
                    quick("打印", "printer") { PrintingView().id(store.sessionRevision) }
                    quick("预约", "calendar") { ReservationCenterView().id(store.sessionRevision) }
                }.padding(.vertical, 7)
                HStack(spacing: 12) {
                    CampusCard {
                        HStack { Text("校园卡余额").font(.caption).foregroundStyle(.secondary); if store.cardBalanceLoading { ProgressView().controlSize(.mini) } }
                        Text(store.mode == .demo ? "¥126.80" : store.cardBalance ?? "—").font(.title2.bold()).monospacedDigit()
                        if let message = store.cardBalanceMessage { NavigationLink(message) { CardView().id(store.sessionRevision).toolbar(.visible, for: .navigationBar) }.font(.caption2) }
                    }
                    CampusCard {
                        Text("已同步待办").font(.caption).foregroundStyle(.secondary)
                        Text(pendingCount).font(.title2.bold()).monospacedDigit()
                    }
                }
                if store.mode == .demo { ModeNotice() }
                if store.mode == .live, store.teaching == nil, store.blackboard == nil {
                    HStack { Text("连接学校账号").font(.headline); Spacer(); NativeLoginButton() }
                    Button("体验演示模式") { store.setMode(.demo) }.font(.caption)
                }
                LearningOverviewView()
                HomeAgendaView().id("home-agenda")
                CampusFold(title: "校园天气", symbol: "cloud.sun") { TodaySummaryView(weatherOnly: true) }
                CampusFold(title: "同步与连接", symbol: "arrow.triangle.2.circlepath") {
                    SessionBadge()
                    Button("同步教务") { Task { await store.refreshTeaching() } }.disabled(store.teachingState.isLoading || store.authenticating || store.clearing)
                    Button("同步Blackboard") { Task { await store.refreshBlackboard() } }.disabled(store.blackboardState.isLoading || store.authenticating || store.clearing)
                    ConnectionNotice(state: store.teachingState).font(.caption)
                }
            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Color.campusPaper)
            .refreshable { await store.refreshHomeBalance(); await store.refreshTeaching(); await store.refreshBlackboard() }
            .task(id: "\(store.mode.rawValue)-\(store.sessionRevision)-\(store.authenticating)") { await store.refreshHomeBalance() }
            .onChange(of: phase) { _, value in if value == .active { Task { await store.refreshHomeBalance() } } }
            .navigationTitle("今天").navigationBarTitleDisplayMode(.inline)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--smoke-home-agenda") {
                    try? await Task.sleep(for: .milliseconds(300)); proxy.scrollTo("home-agenda", anchor: .top)
                }
                #endif
            }
        }
    }
    private func quick<D: View>(_ title: String, _ symbol: String, @ViewBuilder destination: @escaping () -> D) -> some View {
        NavigationLink { destination().toolbar(.visible, for: .navigationBar) } label: {
            VStack(spacing: 9) { Image(systemName: symbol).font(.system(size: 29, weight: .regular)).foregroundStyle(Color.campusOrange); Text(title).font(.caption).foregroundStyle(.primary) }
                .frame(maxWidth: .infinity).padding(.vertical, 9).contentShape(Rectangle())
        }.buttonStyle(CampusPressStyle())
    }
}
