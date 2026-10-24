import CampusCore
import SwiftUI

struct StudyView: View {
    private enum Section: String, CaseIterable { case timetable = "课表", exams = "考试", blackboard = "Blackboard" }
    @Environment(CampusStore.self) private var store
    @State private var section = Section.timetable
    @State private var portal: SchoolService?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModeNotice()
                Picker("学习内容", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                if section == .blackboard { blackboardContent } else { teachingContent }
            }.frame(maxWidth: 860).padding(20).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("学习")
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
    }

    private var teachingContent: some View {
        VStack(spacing: 20) {
            CampusCard {
                Label(store.teaching?.semester.name ?? "连接教务系统", systemImage: "graduationcap").font(.headline)
                if store.mode == .live {
                    PortalActions(service: .teaching) { portal = .teaching }
                    Button("同步课表与考试") { Task { await store.refreshTeaching() } }
                        .disabled(store.teachingState.isLoading || store.clearing)
                    ConnectionNotice(state: store.teachingState).font(.caption)
                }
                Text("课表按学校返回的当前教学周显示，暂不自行推算调休或上课时刻。")
                    .font(.caption).foregroundStyle(.secondary)
            }

            if section == .timetable {
                if let snapshot = store.teaching {
                    if snapshot.meetings.isEmpty {
                        ContentUnavailableView("本次读取没有课表条目", systemImage: "calendar.badge.questionmark",
                                               description: Text("请同时检查上方同步状态，并在教务页面核对。"))
                    }
                    ForEach(1...7, id: \.self) { day in
                        let meetings = snapshot.meetings.filter { $0.weekday == day }
                        if !meetings.isEmpty {
                            CampusCard {
                                Text(["周一", "周二", "周三", "周四", "周五", "周六", "周日"][day - 1])
                                    .font(.headline).foregroundStyle(Color.campusGreen)
                                ForEach(meetings) { MeetingRow(meeting: $0) }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("课表尚未同步", systemImage: "calendar", description: Text("先在学校页面登录，再同步教务数据。"))
                }
            } else {
                if let snapshot = store.teaching {
                    if snapshot.exams.isEmpty {
                        ContentUnavailableView("本次读取没有考试条目", systemImage: "doc.text",
                                               description: Text("可能尚未公布或未能读取，请查看上方同步状态。"))
                    }
                    ForEach(snapshot.exams) { exam in
                        CampusCard {
                            Text(exam.course).font(.headline)
                            Label("\(exam.date) · \(exam.time)", systemImage: "clock")
                            Text(exam.room.isEmpty ? "地点待公布" : exam.room).foregroundStyle(.secondary)
                            if !exam.seat.isEmpty { Text("座位：\(exam.seat)").font(.caption) }
                        }
                    }
                } else {
                    ContentUnavailableView("考试安排尚未同步", systemImage: "doc.text", description: Text("先同步教务数据。"))
                }
            }
        }
    }

    private var blackboardContent: some View {
        VStack(spacing: 20) {
            CampusCard {
                Label("课程与截止日期", systemImage: "books.vertical").font(.headline)
                if store.mode == .live {
                    PortalActions(service: .blackboard) { portal = .blackboard }
                    Button("同步 Blackboard") { Task { await store.refreshBlackboard() } }
                        .disabled(store.blackboardState.isLoading || store.clearing)
                    ConnectionNotice(state: store.blackboardState).font(.caption)
                }
                Text("当前读取已加入课程和成绩册截止日期。尚未核验提交状态，不将其标为待交作业；课件下载与文件提交将在后续批次实现。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if let snapshot = store.blackboard {
                CampusCard {
                    Text("已加入课程 · \(snapshot.courses.count)").font(.headline)
                    ForEach(snapshot.courses) { course in
                        Text(course.name).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    if snapshot.courses.isEmpty { Text("学校返回的课程列表为空。").foregroundStyle(.secondary) }
                }
                CampusCard {
                    Text("截止日期").font(.headline)
                    ForEach(snapshot.deadlines) { DeadlineRow(deadline: $0) }
                    if snapshot.deadlines.isEmpty {
                        Text("本次未读取到截止日期，不代表没有其他课程任务。").foregroundStyle(.secondary)
                    }
                }
            } else {
                ContentUnavailableView("尚未读取 Blackboard", systemImage: "books.vertical", description: Text("打开学校页面登录，再返回同步。"))
            }
        }
    }
}
