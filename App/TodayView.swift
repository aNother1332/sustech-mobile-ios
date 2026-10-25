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
                CampusHero(eyebrow: "SUSTECH MOBILE", title: Date.now.formatted(.dateTime.month().day().weekday(.wide)), subtitle: "校园生活，一目了然", symbol: "sun.max.fill")
                TodaySummaryView()
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 145))], spacing: 10) {
                    ServiceTile(title: "校园码", detail: "校园码 / 身份核验", symbol: "qrcode", color: .campusOrange) { CampusCodeView().id(store.sessionRevision) }
                    ServiceTile(title: "附近校车", detail: "站点与预计到站", symbol: "bus.fill", color: .campusGreen) { BusView() }
                }
                ModeNotice()
                SessionBadge()
                HStack { NavigationLink("我的日程") { AgendaView().id(store.sessionRevision) }; Spacer(); NavigationLink("图书馆") { LibraryView().id(store.sessionRevision) }; NavigationLink("排课") { PlannerView() } }.font(.subheadline)

                if store.mode == .live, store.teaching == nil, store.blackboard == nil {
                    CampusCard {
                        Label("从连接学校服务开始", systemImage: "link").font(.headline)
                        Text("先登录学校账号并同步；网页登录可用于验证码等情况。也可以先体验示例界面。")
                            .font(.callout).foregroundStyle(.secondary)
                        NativeLoginButton()
                        Button("体验演示模式") { store.setMode(.demo) }.buttonStyle(.bordered)
                    }
                }

                CampusCard {
                    HStack {
                        Label("今天的课程", systemImage: "calendar").font(.headline)
                        Spacer()
                        if let week = store.teaching?.week {
                            Text("第 \(week) 周").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if store.teaching == nil {
                        Text("同步课表后，在这里查看今天的安排。").foregroundStyle(.secondary)
                    } else if todayMeetings.isEmpty {
                        Text(store.mode == .demo ? "示例课表今天没有安排，完整示例见「学习」。" : "本次读取的课表中，今天没有课程。请留意学校临时调整。")
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
                    Text("已同步课程 · 折叠课程不参与提醒")
                        .font(.caption).foregroundStyle(.secondary)
                    if upcoming.isEmpty {
                        Text(store.blackboard == nil ? "连接 Blackboard 后查看。" : "本次读取未发现近期截止日期；不代表没有其他任务。")
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
