import CampusCore
import SwiftUI

struct TodayView: View {
    @Environment(CampusStore.self) private var store
    @State private var portal: SchoolService?

    private var todayMeetings: [CourseMeeting] {
        let day = Calendar(identifier: .gregorian).component(.weekday, from: .now)
        let mondayBased = (day + 5) % 7 + 1
        if let term = store.academicTerm, store.teaching?.fullSemester == true { return store.teaching?.meetings.filter { AcademicData.dates($0, term: term).contains { CampusClock.format($0) == CampusClock.format(.now) } } ?? [] }
        return store.teaching?.meetings.filter { $0.weekday == mondayBased && (store.teaching?.fullSemester != true || $0.weeks?.contains(store.teaching?.week ?? -1) == true) } ?? []
    }

    private var upcoming: [LearningDeadline] {
        Array(store.deadlines.filter { deadline in
            guard let due = deadline.due else { return true }
            return due >= .now
        }.prefix(8))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    let term = AcademicData.term(at: context.date)
                    CampusHero(eyebrow: "SUSTECH MOBILE", title: AcademicData.dateTitle(context.date), subtitle: term.map { "第 \($0.week(context.date)) 教学周" } ?? "", symbol: "sun.max.fill")
                }
                TodaySummaryView()
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                    ServiceTile(title: "校园卡", detail: "", symbol: "creditcard", color: .campusOrange) { CardView().id(store.sessionRevision) }
                    ServiceTile(title: "校车", detail: "", symbol: "bus", color: .campusOrange) { BusView() }
                    ServiceTile(title: "打印", detail: "", symbol: "printer", color: .campusOrange) { PrintingView().id(store.sessionRevision) }
                    ServiceTile(title: "预约", detail: "", symbol: "calendar", color: .campusOrange) { ReservationCenterView().id(store.sessionRevision) }
                }
                ModeNotice()
                SessionBadge()
                HStack { NavigationLink("我的日程") { AgendaView().id(store.sessionRevision) }; Spacer(); NavigationLink("图书馆") { LibraryView().id(store.sessionRevision) }; NavigationLink("排课") { PlannerView() } }.font(.subheadline)

                if store.mode == .live, store.teaching == nil, store.blackboard == nil {
                    CampusCard {
                        Label("从连接学校服务开始", systemImage: "link").font(.headline)
                        NativeLoginButton()
                        Button("体验演示模式") { store.setMode(.demo) }.buttonStyle(.bordered)
                    }
                }

                CampusCard {
                    HStack {
                        Label("今天的课程", systemImage: "calendar").font(.headline)
                        Spacer()
                        if let week = store.academicTerm.map({ $0.week(.now) }) ?? store.teaching?.week {
                            Text("第 \(week) 周").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.teaching == nil {
                        Text("同步课表后，在这里查看今天的安排。").foregroundStyle(.secondary)
                    } else if todayMeetings.isEmpty {
                        Text(store.mode == .demo ? "今天没有课程" : "今天没有已同步课程")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(todayMeetings) { MeetingRow(meeting: $0) }
                    }
                    if store.mode == .live {
                        ConnectionNotice(state: store.teachingState).font(.caption)
                        Button("同步教务") { Task { await store.refreshTeaching() } }
                            .disabled(store.teachingState.isLoading || store.clearing)
                    }
                }

                CampusCard(accent: .campusOrange) {
                    Label("近期截止日期", systemImage: "clock").font(.headline)
                        if upcoming.isEmpty {
                        Text(store.blackboard == nil ? "连接 Blackboard 后查看。" : "暂无近期截止日期")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(upcoming) { DeadlineRow(deadline: $0) }
                    }
                    if store.mode == .live {
                        ConnectionNotice(state: store.blackboardState).font(.caption)
                        HStack {
                            NativeLoginButton(service: .blackboard)
                            Spacer()
                            Button("同步 BB") { Task { await store.refreshBlackboard() } }
                                .disabled(store.blackboardState.isLoading || store.clearing)
                        }
                    }
                }
            }
            .frame(maxWidth: 1100).padding(12).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .refreshable { await store.refreshTeaching(); await store.refreshBlackboard() }
        .navigationTitle("今天").navigationBarTitleDisplayMode(.inline)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }
}
