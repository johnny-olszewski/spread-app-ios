import Foundation
import Testing
@testable import Spread

@Suite("EntryListDisplaySupportTests")
struct EntryListDisplaySupportTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    /// Multiday cards should render the full current entry set for each covered date.
    /// Setup: a multiday spread data model contains one task and one note on dates inside the range.
    /// Expected: the displayed entry list includes both entry types rather than dropping notes.
    @Test("Multiday display entries include notes and tasks")
    func multidayDisplayEntriesIncludeNotesAndTasks() {
        let startDate = Self.makeDate(year: 2026, month: 4, day: 6)
        let endDate = Self.makeDate(year: 2026, month: 4, day: 12)
        let spread = DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)

        let task = DataModel.Task(title: "Range Task", date: Self.makeDate(year: 2026, month: 4, day: 7), period: .day)
        let note = DataModel.Note(title: "Range Note", date: Self.makeDate(year: 2026, month: 4, day: 8), period: .day)

        let entries = EntryListDisplaySupport.displayedEntries(
            for: SpreadDataModel(spread: spread, tasks: [task], notes: [note], events: []),
            calendar: Self.calendar
        )

        #expect(entries.count == 2)
        #expect(Set(entries.map { $0.title }) == Set(["Range Task", "Range Note"]))
    }

    /// All notes — regardless of migration status — are returned by displayedNotes.
    /// Setup: a day spread data model contains one active note and one migrated note.
    /// Expected: displayedNotes returns both notes without filtering.
    @Test("displayedNotes returns all notes regardless of migration status")
    func displayedNotesReturnsAllNotes() {
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 13)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)

        let activeNote = DataModel.Note(
            title: "Active Note",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .active)]
        )
        let migratedNote = DataModel.Note(
            title: "Migrated Note",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .migrated)]
        )
        let spreadDataModel = SpreadDataModel(
            spread: spread,
            tasks: [],
            notes: [activeNote, migratedNote],
            events: []
        )

        let notes = EntryListDisplaySupport.displayedNotes(for: spreadDataModel)

        #expect(notes.count == 2)
        #expect(Set(notes.map { $0.title }) == Set(["Active Note", "Migrated Note"]))
    }
}
