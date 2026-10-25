import CampusCore
import SwiftUI

struct WeeklyGridView: View {
    let meetings: [CourseMeeting]
    let week: Int
    @Environment(CampusStore.self) private var store
    @Environment(\.dynamicTypeSize) private var textSize
    @State private var selected: CourseMeeting?
    private let colors: [Color] = [.campusGreen, .campusOrange, .blue, .purple, .teal, .pink]
    private var last: Int { max(12, meetings.map(\.lastPeriod).max() ?? 12) }
    private var dates: [(CourseMeeting, Int)] {
        guard meetings.contains(where: { $0.weeks != nil }), let term = store.academicTerm, let first = term.date(week: week, weekday: 1), let end = term.date(week: week + 1, weekday: 1) else { return meetings.filter { $0.weeks == nil || $0.weeks!.contains(week) }.map { ($0, $0.weekday) } }
        return meetings.flatMap { item in AcademicData.dates(item, term: term).filter { $0 >= first && $0 < end }.map { (item, (AcademicTerm.calendar.component(.weekday, from: $0) + 5) % 7 + 1) } }
    }
    var body: some View {
        if textSize.isAccessibilitySize { Text("大字号模式请使用列表课表查看完整课程。").font(.caption).foregroundStyle(.secondary) }
        GeometryReader { geometry in
            let width = max(46, (geometry.size.width - 62) / 7)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: 3) {
                    VStack(spacing: 3) { Text("节").frame(height: 30); ForEach(1...last, id: \.self) { Text(String($0)).font(.caption2.monospacedDigit()).frame(height: 53) } }.frame(width: 24).foregroundStyle(.secondary)
                    ForEach(1...7, id: \.self) { day in
                        VStack(spacing: 3) {
                            Text(["一", "二", "三", "四", "五", "六", "日"][day - 1]).font(.caption.bold()).frame(height: 30)
                            ZStack(alignment: .top) {
                                VStack(spacing: 3) { ForEach(1...last, id: \.self) { _ in RoundedRectangle(cornerRadius: 6).fill(Color(uiColor: .tertiarySystemGroupedBackground)).frame(height: 53) } }
                                ForEach(dates.filter { $0.1 == day }.map(\.0)) { item in
                                    let color = courseColor(item.name)
                                    let conflicts = dates.filter { $0.1 == day && $0.0.id != item.id && $0.0.firstPeriod <= item.lastPeriod && $0.0.lastPeriod >= item.firstPeriod }.count
                                    Button { selected = item } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.name).font(.caption2.bold()).lineLimit(4)
                                            if width > 80 { Text(item.details).font(.caption2).lineLimit(3).foregroundStyle(.secondary) }
                                            if conflicts > 0 { Label("冲突", systemImage: "exclamationmark.triangle.fill").font(.caption2).foregroundStyle(.red) }
                                            Spacer(minLength: 0)
                                        }.padding(5).frame(width: width, height: CGFloat(item.lastPeriod - item.firstPeriod + 1) * 56 - 3, alignment: .topLeading)
                                            .foregroundStyle(.primary).background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
                                            .overlay(alignment: .top) { RoundedRectangle(cornerRadius: 2).fill(color).frame(height: 3) }
                                    }.buttonStyle(CampusPressStyle()).offset(y: CGFloat(item.firstPeriod - 1) * 56)
                                        .accessibilityLabel("周\(day) 第\(item.firstPeriod)至\(item.lastPeriod)节 \(item.name)")
                                }
                            }.frame(height: CGFloat(last) * 56 - 3)
                        }.frame(width: width)
                    }
                }.padding(8)
            }
        }.frame(height: CGFloat(last) * 56 + 47)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
            .sheet(item: $selected) { item in NavigationStack { List { Section(item.name) { Text(item.details); Text("周\(item.weekday) · \(item.firstPeriod)–\(item.lastPeriod)节"); Text("周次：" + (item.weeks?.map(String.init).joined(separator: ", ") ?? "待确认")) } }.navigationTitle("课程详情").toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { selected = nil } } } }.presentationDetents([.medium, .large]) }
    }
    private func courseColor(_ name: String) -> Color { colors[name.utf8.reduce(0) { ($0 + Int($1)) % colors.count }] }
}

struct EnrolledCoursesView: View {
    @Environment(CampusStore.self) private var store
    private var groups: [(String, [CourseMeeting])] { Dictionary(grouping: store.teaching?.meetings ?? [], by: \.name).sorted { $0.key < $1.key } }
    var body: some View {
        List {
            Section { Text(store.teaching?.semester.name ?? "尚未同步").font(.headline); Text("由个人课表合并，选课结果以学校记录为准。").font(.caption).foregroundStyle(.secondary) }
            ForEach(groups, id: \.0) { name, rows in
                DisclosureGroup(name) { ForEach(rows) { row in MeetingRow(meeting: row); Text("周次：" + (row.weeks?.map(String.init).joined(separator: ",") ?? "待确认")).font(.caption).foregroundStyle(.secondary) } }
            }
        }.navigationTitle("本学期课程").refreshable { await store.refreshTeaching() }
    }
}

struct AcademicCalendarView: View {
    @AppStorage("academic-level") private var level = "undergraduate"
    @State private var date = Date.now
    var body: some View {
        List {
            Section {
                Picker("培养层次", selection: $level) { Text("本科生").tag("undergraduate"); Text("研究生").tag("graduate") }
                DatePicker("查询日期", selection: $date, displayedComponents: .date)
            }
            if let term = AcademicData.term(at: date, level: level) {
                Section("当日安排") { LabeledContent("教学周", value: "第 \(term.week(date)) 周"); if let holiday = term.holiday(date) { Label(holiday, systemImage: "sun.max.fill").foregroundStyle(Color.campusOrange) }; if let makeup = term.makeup.first(where: { CampusClock.format($0.date) == CampusClock.format(date) }) { Text("补课：\(makeup.parity == 1 ? "单" : "双")周 · 周\(makeup.weekday)") }; if term.breaks.contains(CampusClock.format(date)) { Text("校历额外停课日") } }
                Section("节假日") { ForEach(Array(term.holidays.enumerated()), id: \.offset) { _, item in LabeledContent(item.name, value: CampusClock.format(item.start) + " — " + CampusClock.format(item.end)) } }
                Section("调课") { ForEach(Array(term.makeup.enumerated()), id: \.offset) { _, item in Text("\(CampusClock.format(item.date)) · 补\(item.parity == 1 ? "单" : "双")周 周\(item.weekday)") } }
            } else { Text("此日期没有已收录校历，不推算放假或补课安排。") }
            Section { Link("校历数据与来源", destination: URL(string: "https://github.com/dumixthestpd/sustech-calendar")!); Text("内置 2026 年数据；临时调整以学校通知为准。").font(.caption).foregroundStyle(.secondary) }
        }.navigationTitle("教学日历").navigationBarTitleDisplayMode(.inline)
    }
}
