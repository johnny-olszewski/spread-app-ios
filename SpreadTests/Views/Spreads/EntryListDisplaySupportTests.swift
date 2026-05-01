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
            configuration: .init(showsMigrationHistory: false),
            calendar: Self.calendar
        )

        #expect(entries.count == 2)
        #expect(Set(entries.map { $0.title }) == Set(["Range Task", "Range Note"]))
    }

    /// Current-assignment-only day surfaces rely on the model seam and should disable migrated-note section splitting.
    /// Setup: a day spread data model contains one active note and one migrated-history note.
    /// Expected: history-enabled mode splits active and migrated notes, while history-disabled mode returns the raw current model and no migrated subsection.
    @Test("Migration history toggle controls note section splitting")
    func migrationHistoryToggleControlsNoteSectionSplitting() {
        let dayDate = Self.makeDate(year: 2026, month: 4, day: 13)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)

        let activeNote = DataModel.Note(
            title: "Active Note",
            date: dayDate,
            period: .day,
            assignments: [NoteAssignment(period: .day, date: dayDate, status: .active)]
        )
        let migratedNote = DataModel.Note(
            title: "Migrated Note",
            date: dayDate,
            period: .day,
            assignments: [NoteAssignment(period: .day, date: dayDate, status: .migrated)]
        )
        let spreadDataModel = SpreadDataModel(
            spread: spread,
            tasks: [],
            notes: [activeNote, migratedNote],
            events: []
        )

        let historyEnabledNotes = EntryListDisplaySupport.displayedNotes(
            for: spreadDataModel,
            configuration: .init(),
            calendar: Self.calendar
        )
        let historyEnabledMigratedNotes = EntryListDisplaySupport.migratedNotes(
            for: spreadDataModel,
            configuration: .init(),
            calendar: Self.calendar
        )

        #expect(historyEnabledNotes.map { $0.title } == ["Active Note"])
        #expect(historyEnabledMigratedNotes.map { $0.title } == ["Migrated Note"])

        let historyDisabledNotes = EntryListDisplaySupport.displayedNotes(
            for: spreadDataModel,
            configuration: .init(showsMigrationHistory: false),
            calendar: Self.calendar
        )
        let historyDisabledMigratedNotes = EntryListDisplaySupport.migratedNotes(
            for: spreadDataModel,
            configuration: .init(showsMigrationHistory: false),
            calendar: Self.calendar
        )

        #expect(historyDisabledNotes.map { $0.title } == ["Active Note", "Migrated Note"])
        #expect(historyDisabledMigratedNotes.isEmpty)
    }
}
