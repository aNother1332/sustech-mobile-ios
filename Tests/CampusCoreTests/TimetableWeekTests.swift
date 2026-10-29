import Foundation
import Testing
@testable import CampusCore

@Test func earlierWeeksKeepEveryExplicitTISMeetingIncludingHolidayWeekdays() {
    let meetings = [
        CourseMeeting(id: "week4", name: "第四周周四", details: "", weekday: 4, firstPeriod: 1, lastPeriod: 2, weeks: [4]),
        CourseMeeting(id: "week5", name: "第五周周三", details: "", weekday: 3, firstPeriod: 3, lastPeriod: 4, weeks: [5]),
        CourseMeeting(id: "both", name: "四五周课程", details: "", weekday: 2, firstPeriod: 5, lastPeriod: 6, weeks: [4, 5]),
        CourseMeeting(id: "later", name: "后续周课程", details: "", weekday: 1, firstPeriod: 1, lastPeriod: 2, weeks: [8]),
        CourseMeeting(id: "unknown", name: "周次未知", details: "", weekday: 5, firstPeriod: 1, lastPeriod: 2)
    ]
    let snapshot = TeachingSnapshot(semester: Semester(year: "2026-2027", term: "1", name: "秋"), week: 8, meetings: meetings, exams: [], fullSemester: true)
    #expect(snapshot.meetings(inWeek: 4).map(\.id) == ["week4", "both"])
    #expect(snapshot.meetings(inWeek: 5).map(\.id) == ["week5", "both"])
    #expect(snapshot.meetings(inWeek: 5).first?.weekday == 3)
    #expect(snapshot.meetings(inWeek: 8).map(\.id) == ["later"])
}

@Test func weeklyFallbackNeverAppearsAsACompleteEarlierWeek() {
    let meeting = CourseMeeting(id: "current", name: "本周课程", details: "", weekday: 1, firstPeriod: 1, lastPeriod: 2)
    let snapshot = TeachingSnapshot(semester: Semester(year: "2026-2027", term: "1", name: "秋"), week: 8, meetings: [meeting], exams: [])
    #expect(snapshot.meetings(inWeek: 8).count == 1)
    #expect(snapshot.meetings(inWeek: 4).isEmpty)
}
