import Foundation
import Testing
@testable import CampusCore

struct AcademicCalendarTests {
    private func term() throws -> AcademicTerm {
        func load(_ name: String) throws -> WireValue {
            let url = try #require(Bundle.module.url(forResource: name, withExtension: "json", subdirectory: "Fixtures"))
            return try JSONDecoder().decode(WireValue.self, from: Data(contentsOf: url))
        }
        return try #require(AcademicTerm(level: load("calendar-2026-undergraduate"), general: load("calendar-2026-general"), season: "fall"))
    }
    @Test func nationalDayDoesNotProduceRegularThursdayLesson() throws {
        let term = try term()
        #expect(term.holiday(try #require(CampusClock.date("2026-10-01"))) == "国庆节")
        #expect(term.dates(weeks: [4], weekday: 4).isEmpty)
    }
    @Test func octoberMakeupMovesOddWednesdayOnce() throws {
        let term = try term()
        #expect(term.dates(weeks: [5], weekday: 3).map { CampusClock.format($0) } == ["2026-10-10"])
        #expect(term.dates(weeks: [4], weekday: 3).map { CampusClock.format($0) } == ["2026-09-30"])
    }
    @Test func midAutumnFridayMovesToSeptemberSunday() throws {
        #expect(try term().dates(weeks: [3], weekday: 5).map { CampusClock.format($0) } == ["2026-09-20"])
    }
    @Test func explicitBreakAndFinalWeekAreNotRegularClasses() throws {
        let term = try term()
        #expect(term.dates(weeks: [11], weekday: 5).isEmpty)
        #expect(term.dates(weeks: [17], weekday: 1).isEmpty)
    }
    @Test func shanghaiBoundaryAndUnknownWeeks() throws {
        let term = try term()
        #expect(term.week(try #require(CampusClock.date("2026-09-07"))) == 1)
        #expect(term.date(week: 0, weekday: 1) == nil)
        #expect(term.date(week: 1, weekday: 8) == nil)
        #expect(term.dates(weeks: [], weekday: 1).isEmpty)
    }
}
