import CampusCore
import EventKit
import SwiftUI
import UserNotifications

struct AgendaEntry: Identifiable {
    let id: String; let title: String; let source: String; let start: Date; let end: Date
    var courseID = ""
}
struct AgendaView: View {
    @Environment(CampusStore.self) private var store
    @State private var extras: [AgendaEntry] = []
    @State private var warnings: [String] = []
    @State private var range = 7
    @State private var busy = false
    @State private var includeLessons = false
    @State private var monday = Calendar.current.startOfDay(for: .now)
    @State private var personalTitle = ""
    @State private var personalDate = Date.now.addingTimeInterval(3600)
    @State private var personalData = "[]"
    private typealias Personal = PersonalAgendaItem
    private var personal: [Personal] { (try? JSONDecoder().decode([Personal].self, from: Data(personalData.utf8))) ?? [] }
    private var entries: [AgendaEntry] {
        var result = extras + personal.map { AgendaEntry(id: $0.id, title: $0.title, source: "个人事项", start: $0.start, end: $0.start.addingTimeInterval(3600)) }
        result += store.deadlines.compactMap { task in guard let date = task.due else { return nil }; return AgendaEntry(id: "bb-" + task.id, title: task.title, source: task.course, start: date, end: date.addingTimeInterval(900), courseID: task.courseID) }
        for exam in store.teaching?.exams ?? [] {
            let times = HTMLText.captures("(\\d{1,2}:\\d{2})", in: exam.time)
            if let time = times.first?[1], let start = CampusClock.date(exam.date + " " + time, "yyyy-MM-dd HH:mm") {
                let end = times.count > 1 ? CampusClock.date(exam.date + " " + times[1][1], "yyyy-MM-dd HH:mm") : nil
                result.append(AgendaEntry(id: "exam-" + exam.id, title: exam.course + " 考试", source: "教务 · " + exam.room, start: start, end: end ?? start.addingTimeInterval(3600)))
            }
        }
        if includeLessons, let snapshot = store.teaching {
            for meeting in snapshot.meetings {
                guard let a = snapshot.periods.first(where: { $0.period == meeting.firstPeriod })?.start,
                      let b = snapshot.periods.first(where: { $0.period == meeting.lastPeriod })?.end else { continue }
                let days: [Date]
                if let term = store.academicTerm { days = AcademicData.dates(meeting, term: term) }
                else { days = (meeting.weeks ?? []).compactMap { Calendar.current.date(byAdding: .day, value: ($0 - 1) * 7 + meeting.weekday - 1, to: monday) } }
                for day in days {
                    guard
                          let start = CampusClock.date(CampusClock.format(day) + " " + a, "yyyy-MM-dd HH:mm"),
                          let end = CampusClock.date(CampusClock.format(day) + " " + b, "yyyy-MM-dd HH:mm") else { continue }
                    result.append(AgendaEntry(id: "lesson-\(meeting.id)-\(CampusClock.format(day))", title: meeting.name, source: meeting.details, start: start, end: end))
                }
            }
        }
        let lower = Calendar.current.startOfDay(for: .now)
        return result.filter { $0.start >= lower && $0.start < lower.addingTimeInterval(Double(range) * 86400) }.sorted { $0.start < $1.start }
    }
    var body: some View {
        List {
            Section { BusinessHeader(title: "我的日程", symbol: "calendar.badge.clock", color: .campusGreen) }.listRowInsets(EdgeInsets()).listRowBackground(Color.clear).listRowSeparator(.hidden)

            Section {
                ModeNotice()
                Picker("显示范围", selection: $range) { Text("一周").tag(7); Text("一月").tag(30); Text("一学期").tag(180) }.pickerStyle(.segmented)
                DisclosureGroup("课程日期设置") {
                    Toggle("显示课表课程", isOn: $includeLessons)
                    if let term = store.academicTerm { Text("已使用内置校历：第一周周一 " + CampusClock.format(term.monday)); NavigationLink("查看放假与补课") { AcademicCalendarView() } } else { DatePicker("第一教学周周一", selection: $monday, displayedComponents: .date) }
                    Text("有校历时自动处理已收录的节假日与补课；临时调整请核对学校通知。").font(.caption).foregroundStyle(.secondary)
                }
                EmptyView()
                if busy { ProgressView() }
                if !warnings.isEmpty { DisclosureGroup("部分来源未同步 · \(warnings.count)") { ForEach(warnings, id: \.self) { Text($0).font(.caption).foregroundStyle(.orange) } } }
            }
            ForEach(entries) { item in
                NavigationLink { EventActionView(title: item.title, start: item.start, end: item.end, key: item.id, courseID: item.courseID) } label: {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) { Text(item.start, format: .dateTime.month().day()); Text(item.start, style: .time).foregroundStyle(Color.campusGreen) }.font(.caption).frame(width: 65, alignment: .leading)
                        VStack(alignment: .leading, spacing: 3) { Text(item.title).font(.subheadline.bold()); Text(item.source).font(.caption).foregroundStyle(.secondary)
                            if entries.contains(where: { $0.id != item.id && $0.start < item.end && $0.end > item.start }) { Text("与其他日程重叠").font(.caption2).foregroundStyle(.orange) }
                        }
                    }
                }
            }
            if entries.isEmpty { Text("当前范围无已同步日程") }
            Section("个人事项") {
                TextField("事项名称", text: $personalTitle); DatePicker("时间", selection: $personalDate)
                Button("添加") { let value = personal + [Personal(id: "personal-" + UUID().uuidString, title: personalTitle, start: personalDate)]; save(value); personalTitle = "" }.disabled(personalTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                ForEach(personal, id: \.id) { item in HStack { Text(item.title); Spacer(); Text(item.start, style: .date).font(.caption) }.swipeActions { Button("删除", role: .destructive) { save(personal.filter { $0.id != item.id }); UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["campus-" + store.accountScope + "-" + item.id]) } } }
            }
        }.navigationTitle("我的日程").navigationBarTitleDisplayMode(.inline).task { personalData = UserDefaults.standard.string(forKey: "personal-agenda-" + store.accountScope) ?? "[]"; await refresh() }.refreshable { await refresh() }
    }
    private func save(_ items: [Personal]) { if let data = try? JSONEncoder().encode(items) { personalData = String(decoding: data, as: UTF8.self); UserDefaults.standard.set(personalData, forKey: "personal-agenda-" + store.accountScope) } }
    private func reservation(_ value: ReservationItem, source: String, begin: String, end: String) -> AgendaEntry? {
        guard let a = CampusClock.serverDate(value.raw[begin]), let b = CampusClock.serverDate(value.raw[end]), b > a else { return nil }
        return AgendaEntry(id: source + "-" + value.id, title: value.title, source: source + " · 状态请核对预约记录", start: a, end: b)
    }
    private func refresh() async {
        guard !busy, store.mode == .live else { return }; busy = true; defer { busy = false }; let version = store.sessionRevision
        await store.refreshTeaching(); await store.refreshBlackboard()
        for course in store.activeCourses { await store.refreshCourse(course) }
        guard version == store.sessionRevision else { return }
        var collected: [AgendaEntry] = []; var failures: [String] = []
        do { try await store.sessions.connectIC(); let http = await store.serviceHTTP(origin: SchoolService.rooms.portalURL); let mine = try await ICClient(http: http).mine(); collected += mine.filter { ReservationAgendaPolicy.activeIC($0.raw) }.compactMap { reservation($0, source: "IC", begin: "resvBeginTime", end: "resvEndTime") } } catch { failures.append("IC：" + error.localizedDescription) }
        if !store.sessions.cleID.isEmpty {
            do {
                let client = CLEClient(http: await store.serviceHTTP(origin: CLEClient.index))
                let mine = try await client.mine(sid: store.sessions.cleID)
                for item in mine where item.raw["YYZT"].text == "1" {
                    let stamp = item.raw["SKSJ"].text
                    let values = HTMLText.captures("^(\\d{4}-\\d{2}-\\d{2}) (\\d{1,2}:\\d{2})\\s*[-–~]\\s*(\\d{1,2}:\\d{2})$", in: stamp)
                    if let row = values.first, let a = CampusClock.date(row[1] + " " + row[2], "yyyy-MM-dd HH:mm"), let b = CampusClock.date(row[1] + " " + row[3], "yyyy-MM-dd HH:mm"), b > a {
                        collected.append(AgendaEntry(id: "CLE-" + item.id, title: item.title, source: "CLE", start: a, end: b))
                    } else { failures.append("CLE：有预约时段不能确定日期，请在预约中心核对。") }
                }
            } catch { failures.append("CLE：" + error.localizedDescription) }
        }

        guard version == store.sessionRevision else { return }; extras = collected; store.agendaExtras = collected; warnings = failures
    }
}

struct EventActionView: View {
    @Environment(CampusStore.self) private var store
    let title: String; let start: Date; let end: Date; let key: String
    var courseID = ""
    @State private var minutes = 30
    @State private var message: String?
    @State private var busy = false
    @State private var events = EKEventStore()
    var body: some View {
        Form {
            Section { Text(title).font(.headline); LabeledContent("开始", value: start.formatted()); LabeledContent("结束", value: end.formatted()) }
            Section {
                Picker("提前提醒", selection: $minutes) { Text("10 分钟").tag(10); Text("30 分钟").tag(30); Text("1 小时").tag(60); Text("1 天").tag(1440) }
                Button("设置本地提醒") { Task { await remind() } }.disabled(busy || start <= .now || store.mode == .demo || store.authenticating || store.clearing)
                Button("取消本地提醒") { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["campus-" + store.accountScope + "-" + key]); message = "已取消本 App 的该项待发提醒" }
                Button("添加／更新系统日历") { Task { await export() } }.disabled(busy || store.mode == .demo || store.authenticating || store.clearing)
                ServiceMessage(message: message)
                DetailNote(text: "提醒与导出基于本次已同步信息。学校变更后需重新同步和更新。系统日历事件由你管理，App 内折叠课程不会自动删除已导出日历事件。")
            }
        }.navigationTitle("日历与提醒").navigationBarTitleDisplayMode(.inline)
    }
    private func remind() async {
        guard !busy, store.mode == .live, !store.authenticating, !store.clearing else { return }
        let version = store.sessionRevision; let owner = store.accountScope; let identifier = "campus-" + owner + "-" + key
        busy = true; defer { busy = false }
        do {
            guard try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) else { throw ServiceFailure("请在系统设置中允许通知。") }
            guard version == store.sessionRevision, owner == store.accountScope, !store.clearing else { throw CancellationError() }
            let date = start.addingTimeInterval(-Double(minutes) * 60); guard date > .now else { throw ServiceFailure("提醒时间已过去，请调整提前量。") }
            let content = UNMutableNotificationContent(); content.title = title; content.body = start.formatted(); content.sound = .default; content.userInfo = ["courseID": courseID, "owner": owner]
            let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: identifier, content: content, trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            guard version == store.sessionRevision, owner == store.accountScope, !store.clearing else { UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier]); throw CancellationError() }
            message = "已设置；同一事项再次设置会替换原提醒"
        } catch { message = error.localizedDescription }
    }
    private func export() async {
        guard !busy, store.mode == .live, !store.authenticating, !store.clearing else { return }
        let version = store.sessionRevision; let owner = store.accountScope
        busy = true; defer { busy = false }
        do {
            guard try await events.requestFullAccessToEvents() else { throw ServiceFailure("请在系统设置中允许日历访问。") }
            guard version == store.sessionRevision, owner == store.accountScope, !store.clearing else { throw CancellationError() }
            let preference = "calendar-event-" + owner + "-" + key
            let existing = UserDefaults.standard.string(forKey: preference).flatMap { events.event(withIdentifier: $0) }
            let event = existing ?? EKEvent(eventStore: events)
            event.title = title; event.startDate = start; event.endDate = max(end, start.addingTimeInterval(60)); event.notes = "由 SUSTechMobile 导出，基于最近同步信息。"
            if event.calendar == nil { event.calendar = events.defaultCalendarForNewEvents }
            guard event.calendar != nil else { throw ServiceFailure("没有可写日历。") }
            try events.save(event, span: .thisEvent)
            UserDefaults.standard.set(event.eventIdentifier, forKey: preference); message = "已保存至系统日历"
        } catch { message = error.localizedDescription }
    }
}
