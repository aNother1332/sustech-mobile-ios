import CampusCore
import SwiftUI

struct LearningOverviewView: View {
    @Environment(CampusStore.self) private var store
    private var lessons: [CourseMeeting] {
        guard let snapshot = store.teaching else { return [] }
        if snapshot.fullSemester {
            guard let term = store.academicTerm else { return [] }
            return snapshot.meetings.filter { meeting in AcademicData.dates(meeting, term: term).contains { AcademicTerm.calendar.isDateInToday($0) } }.sorted { $0.firstPeriod < $1.firstPeriod }
        }
        let weekday = (AcademicTerm.calendar.component(.weekday, from: Date.now) + 5) % 7 + 1
        return snapshot.meetings.filter { $0.weekday == weekday }.sorted { $0.firstPeriod < $1.firstPeriod }
    }
    private var exam: CampusExam? { LearningHighlights.nextExam(store.teaching?.exams ?? []) }
    private var task: LearningDeadline? { LearningHighlights.nextSubmission(store.deadlines) }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !lessons.isEmpty {
                CampusSectionTitle(title: "今日课程")
                CampusCard { ForEach(lessons) { MeetingRow(meeting: $0) } }
            }
            if let exam {
                CampusSectionTitle(title: "最近考试")
                CampusCard {
                    Label(exam.course, systemImage: "pencil.and.list.clipboard").font(.headline)
                    Text(exam.date + " · " + exam.time).font(.subheadline).foregroundStyle(Color.campusOrange)
                    if !exam.room.isEmpty { Text(exam.room).font(.caption).foregroundStyle(.secondary) }
                }
            }
            if let task {
                CampusSectionTitle(title: "最近待交")
                CampusCard { DeadlineRow(deadline: task) }
            }
        }
    }
}
