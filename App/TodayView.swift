import CampusCore
import SwiftUI

struct TodayView: View {
    @Environment(CampusStore.self) private var store
    @State private var portal: SchoolService?

    private var todayMeetings: [CourseMeeting] {
        let day = Calendar(identifier: .gregorian).component(.weekday, from: .now)
        let mondayBased = (day + 5) % 7 + 1
        return store.teaching?.meetings.filter { $0.weekday == mondayBased } ?? []
    }

    private var upcoming: [LearningDeadline] {
        Array((store.blackboard?.deadlines ?? []).filter { deadline in
            guard let due = deadline.due else { return true }
            return due >= .now
        }.prefix(3))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(Date.now, format: .dateTime.month(.wide).day().weekday(.wide))
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("校园日常，一处就好。")
                        .font(.largeTitle.bold()).minimumScaleFactor(0.7)
                    Text("课程、任务与校园服务")
                        .foregroundStyle(.secondary)
                }.padding(.vertical, 8)

                ModeNotice()

                if store.mode == .live, store.teaching == nil, store.blackboard == nil {
                    CampusCard {
                        Label("从连接学校服务开始", systemImage: "link").font(.headline)
                        Text("分别打开教务和 Blackboard 完成学校登录，再手动同步。也可以先体验示例界面。")
                            .font(.callout).foregroundStyle(.secondary)
                        Button("打开教务登录") { portal = .teaching }.buttonStyle(.borderedProminent)
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

                CampusCard {
                    Label("近期截止日期", systemImage: "clock").font(.headline)
                    Text("截止日期不代表尚未提交，请在课程页面核对状态。")
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
                            Button("登录 BB") { portal = .blackboard }
                            Spacer()
                            Button("同步 BB") { Task { await store.refreshBlackboard() } }
                                .disabled(store.blackboardState.isLoading || store.clearing)
                        }
                    }
                }
            }
            .frame(maxWidth: 860).padding(20).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("今天")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }
}
