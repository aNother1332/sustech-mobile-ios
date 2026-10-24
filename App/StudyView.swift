import CampusCore
import SwiftUI

struct StudyView: View {
    private enum Section: String, CaseIterable { case timetable = "课表", exams = "考试", grades = "成绩", blackboard = "BB" }
    @Environment(CampusStore.self) private var store
    @State private var section = Section.timetable
    @State private var portal: SchoolService?
    @State private var selectedWeek = 1
    @State private var selectedTerm = "全部学期"

    init() {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        let initial: Section = arguments.contains("--smoke-exams") ? .exams
            : arguments.contains("--smoke-grades") ? .grades
            : arguments.contains("--smoke-blackboard") ? .blackboard : .timetable
        _section = State(initialValue: initial)
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ModeNotice()
                if let message = store.cacheMessage { Text(message).font(.caption).foregroundStyle(.orange) }
                Picker("学习内容", selection: $section) {
                    ForEach(Section.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented)
                switch section {
                case .blackboard: blackboardContent
                case .grades: gradesContent
                default: teachingContent
                }
            }.frame(maxWidth: 860).padding(20).frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("学习")
        .sheet(item: $portal) { SchoolBrowser(service: $0) }
        .onChange(of: store.teaching?.week, initial: true) { _, week in if let week { selectedWeek = week } }
    }

    private var teachingContent: some View {
        VStack(spacing: 20) {
            CampusCard {
                Label(store.teaching?.semester.name ?? "连接教务系统", systemImage: "graduationcap").font(.headline)
                if store.mode == .live {
                    PortalActions(service: .teaching) { portal = .teaching }
                    Button("同步全学期课表与考试") { Task { await store.refreshTeaching() } }
                        .disabled(store.teachingState.isLoading || store.clearing || store.authenticating)
                    ConnectionNotice(state: store.teachingState).font(.caption)
                }
                Text("按学校返回的周次和节次显示；调休和临时调整以学校通知为准。离线时显示最近同步结果。")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if section == .timetable {
                if let snapshot = store.teaching {
                    if snapshot.fullSemester {
                        Stepper("第 \(selectedWeek) 教学周", value: $selectedWeek, in: 1...max(30, snapshot.meetings.flatMap { $0.weeks ?? [] }.max() ?? 30))
                        if snapshot.week != nil { Button("返回当前教学周") { selectedWeek = snapshot.week ?? selectedWeek } }
                    }
                    let rows = snapshot.meetings.filter { !snapshot.fullSemester || $0.weeks?.contains(selectedWeek) == true }
                    if rows.isEmpty {
                        ContentUnavailableView("本次课表中该周没有已确认安排", systemImage: "calendar.badge.questionmark",
                            description: Text("请核对同步状态和学校临时通知。"))
                    }
                    ForEach(1...7, id: \.self) { day in
                        let meetings = rows.filter { $0.weekday == day }
                        if !meetings.isEmpty {
                            CampusCard {
                                Text(["周一", "周二", "周三", "周四", "周五", "周六", "周日"][day - 1]).font(.headline).foregroundStyle(Color.campusGreen)
                                ForEach(meetings) { MeetingRow(meeting: $0) }
                            }
                        }
                    }
                    if snapshot.fullSemester {
                        let unknown = snapshot.meetings.filter { $0.weeks == nil }
                        if !unknown.isEmpty {
                            CampusCard {
                                Text("周次待核对").font(.headline)
                                Text("这些课程没有可靠周次，不自动排入每一周。").font(.caption).foregroundStyle(.secondary)
                                ForEach(unknown) { MeetingRow(meeting: $0) }
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("课表尚未同步", systemImage: "calendar", description: Text("先登录学校账号，再同步教务。"))
                }
            } else {
                if let snapshot = store.teaching {
                    if snapshot.exams.isEmpty { Text("本次未读取到考试安排，请核对同步状态和学校页面。").foregroundStyle(.secondary) }
                    ForEach(snapshot.exams) { exam in
                        CampusCard {
                            Text(exam.course).font(.headline)
                            Label("\(exam.date) · \(exam.time)", systemImage: "clock")
                            Text(exam.room.isEmpty ? "地点待公布" : exam.room).foregroundStyle(.secondary)
                            if !exam.seat.isEmpty { Text("座位：\(exam.seat)").font(.caption) }
                        }
                    }
                } else { ContentUnavailableView("考试安排尚未同步", systemImage: "doc.text") }
            }
        }
    }
    private var gradesContent: some View {
        VStack(spacing: 20) {
            CampusCard {
                Label("成绩与学分", systemImage: "chart.bar.doc.horizontal").font(.headline)
                if store.mode == .live {
                    NativeLoginButton()
                    Button("同步全部成绩") { Task { await store.refreshGrades() } }
                        .disabled(store.gradesState.isLoading || store.clearing || store.authenticating)
                    ConnectionNotice(state: store.gradesState).font(.caption)
                }
            }
            if let snapshot = store.academic {
                let terms = Array(Set(snapshot.records.map(\.term))).sorted(by: >)
                Picker("学期", selection: $selectedTerm) {
                    Text("全部学期").tag("全部学期")
                    ForEach(terms, id: \.self) { Text($0).tag($0) }
                }.pickerStyle(.menu)
                let records = snapshot.records.filter { selectedTerm == "全部学期" || $0.term == selectedTerm }
                let summary = GradeSummary(records: records)
                CampusCard {
                    Text("GPA 记录试算").font(.headline)
                    if let points = summary.points { Text(points.formatted(.number.precision(.fractionLength(3)))).font(.largeTitle.bold()) }
                    else { Text("当前记录不足以试算") }
                    Text("计入试算学分：\(summary.includedCredits.formatted()) · 未计入记录：\(summary.excludedCount)").font(.caption)
                    Text("按每条记录的学校绩点或公开字母等级参考值加权。未合并重修/替代课程，及格制或未知等级不猜测；这不是学校官方总 GPA 或毕业审核结论。")
                        .font(.caption).foregroundStyle(.secondary)
                }
                if records.isEmpty { Text("学校本次返回的成绩列表为空。").foregroundStyle(.secondary) }
                ForEach(records) { grade in
                    CampusCard {
                        HStack { Text(grade.name).font(.headline); Spacer(); Text(grade.display.isEmpty ? grade.score : grade.display).font(.title3.bold()) }
                        Text("\(grade.code) · \(grade.term)").font(.caption).foregroundStyle(.secondary)
                        Text("学分 \(grade.credits.formatted()) · \(grade.category)").font(.subheadline)
                        if !grade.score.isEmpty, grade.score != grade.display { Text("学校原始成绩：\(grade.score)").font(.caption) }
                    }
                }
            } else { ContentUnavailableView("成绩尚未同步", systemImage: "chart.bar.doc.horizontal", description: Text("登录教务后单独同步成绩。")) }
        }
    }
    private var blackboardContent: some View {
        VStack(spacing: 20) {
            CampusCard {
                Label("Blackboard 学习中心", systemImage: "books.vertical").font(.headline)
                if store.mode == .live {
                    PortalActions(service: .blackboard) { portal = .blackboard }
                    Button("同步课程列表") { Task { await store.refreshBlackboard() } }
                        .disabled(store.blackboardState.isLoading || store.clearing || store.authenticating)
                    ConnectionNotice(state: store.blackboardState).font(.caption)
                }
                Text("进入课程后读取任务、提交状态和公告。首页汇总已同步课程；课件按需下载并保留在本机。")
                    .font(.caption).foregroundStyle(.secondary)
                NavigationLink { OfflineDownloadsView() } label: { Label("离线文件 · \(store.files.count)", systemImage: "arrow.down.document") }
            }
            if let snapshot = store.blackboard {
                ForEach(snapshot.courses) { course in
                    NavigationLink { BBCourseView(course: course) } label: {
                        CampusCard {
                            HStack { Text(course.name).font(.headline); Spacer(); Image(systemName: "chevron.right") }
                            if let detail = store.courseDetails[course.id] {
                                Text("\(detail.tasks.count) 个任务 · \(detail.announcements.count) 条公告").font(.caption).foregroundStyle(.secondary)
                            } else { Text("进入课程读取任务、公告和课件").font(.caption).foregroundStyle(.secondary) }
                        }
                    }.buttonStyle(.plain)
                }
                if snapshot.courses.isEmpty { Text("本次学校返回的课程列表为空。").foregroundStyle(.secondary) }
            } else { ContentUnavailableView("课程尚未同步", systemImage: "books.vertical", description: Text("先登录，再读取 Blackboard 课程。")) }
        }
    }
}
