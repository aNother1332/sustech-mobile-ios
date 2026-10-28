import CampusCore
import Foundation

enum AcademicData {
    static func dateTitle(_ date: Date) -> String {
        var style = Date.FormatStyle.dateTime.month().day().weekday(.wide)
        style.timeZone = AcademicTerm.calendar.timeZone
        return date.formatted(style)
    }
    static func term(for snapshot: TeachingSnapshot, at date: Date = .now) -> AcademicTerm? {
        guard let term = term(at: date) else { return nil }
        let month = AcademicTerm.calendar.component(.month, from: term.monday)
        let year = AcademicTerm.calendar.component(.year, from: term.monday)
        let academicYear = month < 7 ? year - 1 : year
        guard snapshot.semester.year.hasPrefix(String(academicYear)), snapshot.semester.term == (month < 7 ? "2" : "1") else { return nil }
        return term
    }
    static func term(at date: Date = .now, level: String = UserDefaults.standard.string(forKey: "academic-level") ?? "undergraduate") -> AcademicTerm? {
        let year = AcademicTerm.calendar.component(.year, from: date)
        for y in [year, year - 1] {
            guard let a = load("calendar-\(y)-\(level)"), let b = load("calendar-\(y)-general") else { continue }
            for season in ["spring", "fall"] { if let term = AcademicTerm(level: a, general: b, season: season), term.contains(date) { return term } }
        }
        return nil
    }
    static func holiday(at date: Date) -> String? {
        let year = AcademicTerm.calendar.component(.year, from: date)
        let key = CampusClock.format(date)
        return load("calendar-\(year)-general")?["holidays"].rows.first { $0["start"].text <= key && $0["end"].text >= key }?["name"].text
    }
    private static func load(_ name: String) -> WireValue? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"), let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(WireValue.self, from: data)
    }
    static func dates(_ meeting: CourseMeeting, term: AcademicTerm) -> [Date] { term.dates(weeks: meeting.weeks ?? [], weekday: meeting.weekday) }
}

extension CampusStore {
    var academicTerm: AcademicTerm? { teaching.flatMap { AcademicData.term(for: $0) } }
}
