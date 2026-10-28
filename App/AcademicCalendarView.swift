import CampusCore
import SwiftUI

private struct SchoolCalendarNote: Decodable {
    let month: Int; let category: String; let text: String
    static var all: [SchoolCalendarNote] {
        guard let url = Bundle.main.url(forResource: "calendar-2026-notes", withExtension: "json"), let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([SchoolCalendarNote].self, from: data)) ?? []
    }
}

struct AcademicCalendarView: View {
    @AppStorage("academic-level") private var level = "undergraduate"
    @State private var month = AcademicTerm.calendar.component(.month, from: .now)
    private let year = 2026
    private let green = Color(red: 0.10, green: 0.39, blue: 0.42)
    private let calendar = AcademicTerm.calendar
    private var weeks: [[Date]] {
        guard let first = calendar.date(from: DateComponents(year: year, month: month, day: 1)),
              let count = calendar.range(of: .day, in: .month, for: first)?.count else { return [] }
        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        return (0..<Int(ceil(Double(count + offset) / 7))).map { row in
            (0..<7).compactMap { calendar.date(byAdding: .day, value: row * 7 + $0 - offset, to: first) }
        }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                BusinessHeader(title: "\(year)年校历", symbol: "calendar", color: green)
                HStack {
                    Picker("培养层次", selection: $level) { Text("本科生").tag("undergraduate"); Text("研究生").tag("graduate") }.pickerStyle(.segmented)
                    NavigationLink { RemoteOfficialDocument(title: "学校原版校历", url: URL(string: "https://www.sustech.edu.cn/uploads/files/2025/11/25155108_33786.pdf")!) } label: { Image(systemName: "doc.richtext").font(.title3).padding(8) }.accessibilityLabel("学校原版校历")
                }
                ScrollView(.horizontal) {
                    HStack(spacing: 6) { ForEach(1...12, id: \.self) { value in
                        Button { month = value } label: { Text("\(value)月").font(.subheadline.weight(.semibold)).padding(.horizontal, 13).padding(.vertical, 9).background(month == value ? green : green.opacity(0.06), in: Capsule()).foregroundStyle(month == value ? Color.white : green) }.buttonStyle(.plain)
                    } }
                }.scrollIndicators(.hidden)
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        Text("周次").frame(width: 58)
                        ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { Text($0).frame(maxWidth: .infinity) }
                    }.font(.caption.bold()).foregroundStyle(.white).padding(.vertical, 12).background(green)
                    ForEach(weeks.indices, id: \.self) { index in
                        let dates = weeks[index]
                        HStack(spacing: 0) {
                            weekLabel(dates).frame(width: 58)
                            ForEach(dates, id: \.self) { date in dayCell(date) }
                        }.frame(minHeight: 77).background(index % 2 == 0 ? green.opacity(0.035) : Color.campusPaper)
                        Divider()
                    }
                }.clipShape(RoundedRectangle(cornerRadius: 15))
                ForEach([("holiday", "节假日"), ("activity", "重大活动"), (level, "教学安排")], id: \.0) { category, title in
                    let notes = SchoolCalendarNote.all.filter { $0.month == month && $0.category == category }
                    if !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(title).font(.headline).foregroundStyle(green)
                            ForEach(Array(notes.enumerated()), id: \.offset) { _, note in
                                HStack(alignment: .top, spacing: 8) { RoundedRectangle(cornerRadius: 2).fill(note.text.contains("考试") ? Color.campusOrange : green.opacity(0.5)).frame(width: 3); Text(note.text).font(.subheadline).lineSpacing(4).frame(maxWidth: .infinity, alignment: .leading) }.fixedSize(horizontal: false, vertical: true)
                            }
                        }.padding(16).background(Color.campusPaper, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }.padding(16).frame(maxWidth: 1100).frame(maxWidth: .infinity)
        }.background(Color(uiColor: .systemGroupedBackground)).navigationTitle("教学日历").navigationBarTitleDisplayMode(.inline)
    }
    private func weekLabel(_ dates: [Date]) -> some View {
        let entries = dates.compactMap { date in AcademicData.term(at: date, level: level).map { ($0, date) } }
        let entry = entries.first
        let exam = entries.compactMap { $0.0.examLabel($0.1) }.first
        return VStack(spacing: 5) {
            if let entry, entry.0.week(entry.1) > 0 { Text("第\(entry.0.week(entry.1))周").font(.caption2.bold()) }
            if let exam { Text(exam).font(.system(size: 9, weight: .semibold)).multilineTextAlignment(.center).foregroundStyle(Color.campusOrange) }
        }.padding(.horizontal, 4)
    }
    private func dayCell(_ date: Date) -> some View {
        let current = calendar.component(.month, from: date) == month
        let term = AcademicData.term(at: date, level: level)
        let holiday = term?.holiday(date) ?? AcademicData.holiday(at: date)
        let makeup = term?.makeup.contains { calendar.isDate($0.date, inSameDayAs: date) } == true
        let weekend = calendar.component(.weekday, from: date) == 1 || calendar.component(.weekday, from: date) == 7
        return VStack(spacing: 6) {
            Text("\(calendar.component(.day, from: date))").font(.subheadline.weight(calendar.isDateInToday(date) ? .bold : .medium))
                .padding(5).background(calendar.isDateInToday(date) ? green : .clear, in: Circle()).foregroundStyle(calendar.isDateInToday(date) ? Color.white : weekend ? .pink : .primary)
            if let holiday { Text(holiday).font(.system(size: 9)).foregroundStyle(Color.campusOrange).lineLimit(1) }
            else if makeup { Text("补课").font(.system(size: 9)).foregroundStyle(green) }
        }.frame(maxWidth: .infinity).opacity(current ? 1 : 0.25)
    }
}

struct RemoteOfficialDocument: View {
    let title: String; let url: URL
    @State private var file = OfficialPDF()
    var body: some View {
        Group {
            if let document = file.document { OfficialPDFReader(document: document) }
            else { VStack(spacing: 16) { if file.loading { ProgressView() }; if let error = file.error { InlineFailure(message: error) } }.padding() }
        }.navigationTitle(title).navigationBarTitleDisplayMode(.inline).task { await file.load(url) }
    }
}
