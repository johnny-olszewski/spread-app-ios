import Foundation
import Testing
@testable import Spread

@MainActor
struct JournalDataStoreTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func makeStore(
        spreads: [DataModel.Spread] = [],
        tasks: [DataModel.Task] = [],
        notes: [DataModel.Note] = [],
        events: [DataModel.Event] = []
    ) -> JournalDataStore {
        JournalDataStore(
            calendar: Self.calendar,
            taskRepository: TestChangeAwareTaskRepository(tasks: tasks),
            noteRepository: TestChangeAwareNoteRepository(notes: notes),
            spreadRepository: InMemorySpreadRepository(spreads: spreads),
            eventRepository: InMemoryEventRepository(events: events)
        )
    }

    /// Setup: a store with no repository data calls `load()`.
    /// Expected: all observed properties are empty and `fullLoadCount` is 1.
    @Test func testLoadWithEmptyRepositoriesProducesEmptyState() async {
        let store = Self.makeStore()

        await store.load()

        #expect(store.spreads.isEmpty)
        #expect(store.tasks.isEmpty)
        #expect(store.notes.isEmpty)
        #expect(store.events.isEmpty)
        #expect(store.dataModel.isEmpty)
        #expect(store.fullLoadCount == 1)
    }

    /// Setup: `load()` is called twice in succession.
    /// Expected: `fullLoadCount` increments once per call — cold load is not implicitly
    /// repeated or skipped.
    @Test func testLoadIncrementsFullLoadCountEachCall() async {
        let store = Self.makeStore()

        await store.load()
        await store.load()

        #expect(store.fullLoadCount == 2)
    }

    /// Setup: a day spread with a current task/note assignment and an overlapping event,
    /// loaded into the store.
    /// Expected: `dataModel`'s resolved `SpreadDataModel` for that spread's key matches
    /// `JournalRuleEngine.buildDataModel`'s output for the same fixtures exactly — proving
    /// the index-backed resolution produces identical content to a full rebuild.
    @Test func testLoadProducesDataModelMatchingFullRebuild() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let note = DataModel.Note(
            title: "Note",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .active)]
        )
        let event = DataModel.Event(title: "Event", startDate: dayDate, endDate: dayDate)

        let store = Self.makeStore(spreads: [daySpread], tasks: [task], notes: [note], events: [event])
        await store.load()

        let engine = JournalRuleEngine(calendar: Self.calendar)
        let legacyModel = engine.buildDataModel(
            spreads: [daySpread],
            tasks: [task],
            notes: [note],
            events: [event]
        )

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.dataModel[key: key]?.tasks.map(\.id) == legacyModel[key: key]?.tasks.map(\.id))
        #expect(store.dataModel[key: key]?.notes.map(\.id) == legacyModel[key: key]?.notes.map(\.id))
        #expect(store.dataModel[key: key]?.events.map(\.id) == legacyModel[key: key]?.events.map(\.id))
    }

    /// Setup: a task with only a migrated-history assignment (no current spread match),
    /// loaded alongside the spread that history points at.
    /// Expected: the spread's resolved `SpreadDataModel` does not include the task — parity
    /// with `JournalRuleEngine`'s non-migrated-only matching rule.
    @Test func testLoadExcludesMigratedHistoryFromResolvedSpreadDataModel() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let migratedTask = DataModel.Task(
            title: "Migrated",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .migrated)]
        )

        let store = Self.makeStore(spreads: [daySpread], tasks: [migratedTask])
        await store.load()

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.dataModel[key: key]?.tasks.isEmpty == true)
    }
}
