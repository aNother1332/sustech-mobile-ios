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
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(AcademicData.dateTitle(context.date)).font(.title2.bold())
                            if let term = AcademicData.term(at: context.date) { Text("第 \(term.week(context.date)) 教学周").font(.subheadline) }
                        }
                        Spacer(minLength: 0)
                        Button { withAnimation { proxy.scrollTo("campus-weather", anchor: .bottom) } } label: {
                            HStack(spacing: 6) { if let temperature = store.campusWeather?.temperature { Text(temperature).font(.title3.weight(.semibold)).monospacedDigit() }; Image(systemName: store.campusWeather?.symbol ?? "cloud.sun").font(.title2) }
                        }.buttonStyle(.plain).accessibilityLabel("查看完整天气")
                    }.foregroundStyle(.white).padding(20).background { CampusHeaderBackground().clipShape(RoundedRectangle(cornerRadius: 20)) }
                }
                HStack(spacing: 0) {
                    quick("校园卡", "creditcard") { CardView().id(store.sessionRevision) }
                    quick("校车", "bus") { BusView() }
                    quick("打印", "printer") { PrintingView().id(store.sessionRevision) }
                    quick("预约", "calendar") { ReservationCenterView().id(store.sessionRevision) }
                }.padding(.vertical, 7)
                HStack(spacing: 12) {
                    NavigationLink { CardView().id(store.sessionRevision).toolbar(.visible, for: .navigationBar) } label: { CampusCard {
                        HStack { Text("校园卡余额").font(.caption).foregroundStyle(.secondary); if store.cardBalanceLoading { ProgressView().controlSize(.mini) } }
                        Text(store.mode == .demo ? "¥126.80" : store.cardBalance ?? "—").font(.title2.bold()).monospacedDigit()
                        if let message = store.cardBalanceMessage { Text(message).font(.caption2).foregroundStyle(.secondary) }
                    } }.buttonStyle(CampusPressStyle()).foregroundStyle(.primary).accessibilityIdentifier("home-card-balance")
                    NavigationLink { AgendaView().id(store.sessionRevision).toolbar(.visible, for: .navigationBar) } label: { CampusCard {
                        Text("待办").font(.caption).foregroundStyle(.secondary)
                        Text(pendingCount).font(.title2.bold()).monospacedDigit()
                    } }.buttonStyle(CampusPressStyle()).foregroundStyle(.primary).accessibilityIdentifier("home-card-agenda")
                }
                if store.mode == .demo { ModeNotice() }
                NativeLoginButton()
                LearningOverviewView()
                HomeAgendaView().id("home-agenda")
                CampusWeatherView().id("campus-weather")

            }.padding(16).frame(maxWidth: 1000).frame(maxWidth: .infinity)
        }.background(Color.campusPaper)
            .refreshable { await store.refreshHomeBalance(); await store.refreshTeaching(); await store.refreshBlackboard(); await store.refreshWeather(force: true) }
            .task(id: "\(store.mode.rawValue)-\(store.sessionRevision)-\(store.authenticating)") { await store.refreshHomeBalance() }
            .onChange(of: phase) { _, value in if value == .active { Task { await store.refreshHomeBalance() } } }
            .navigationTitle("今天").navigationBarTitleDisplayMode(.inline)
            .task {
                #if DEBUG
                if ProcessInfo.processInfo.arguments.contains("--smoke-home-agenda") {
                    try? await Task.sleep(for: .milliseconds(300)); proxy.scrollTo("home-agenda", anchor: .top)
                }
                if ProcessInfo.processInfo.arguments.contains("--smoke-home-weather") {
                    try? await Task.sleep(for: .milliseconds(500)); proxy.scrollTo("campus-weather", anchor: .bottom)
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
