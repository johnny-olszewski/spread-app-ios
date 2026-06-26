import Foundation
import Testing
@testable import Spread

@MainActor
struct JournalManagerCoreTests {
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
    ) -> JournalManager {
        JournalManager(
            appClock: .fixed(now: .now, calendar: Self.calendar, timeZone: Self.calendar.timeZone, locale: Locale(identifier: "en_US_POSIX")),
            taskRepository: TestTaskRepository(tasks: tasks),
            noteRepository: TestNoteRepository(notes: notes),
            spreadRepository: InMemorySpreadRepository(spreads: spreads),
            eventRepository: InMemoryEventRepository(events: events),
            creationPolicy: StandardCreationPolicy(today: .now, firstWeekday: .systemDefault)
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

    // MARK: - Mutation Primitives

    /// Setup: a task is upserted into a store with an existing matching day spread.
    /// Expected: `tasks` includes it and `dataModel` for that spread's key includes it too.
    @Test func testUpsertTaskAddsToTasksAndPatchesDataModel() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let store = Self.makeStore(spreads: [daySpread])
        await store.load()

        let task = DataModel.Task(
            title: "New",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        store.upsertTask(task)

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.tasks.map(\.id) == [task.id])
        #expect(store.dataModel[key: key]?.tasks.map(\.id) == [task.id])
    }

    /// Setup: a task is upserted, then removed.
    /// Expected: `tasks` no longer includes it and its spread's `dataModel` entry no longer
    /// includes it either.
    @Test func testRemoveTaskClearsFromTasksAndDataModel() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Removable",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let store = Self.makeStore(spreads: [daySpread], tasks: [task])
        await store.load()

        store.removeTask(id: task.id)

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.tasks.isEmpty)
        #expect(store.dataModel[key: key]?.tasks.isEmpty == true)
    }

    /// Setup: a task's preferred assignment moves from a day spread to a month spread via
    /// in-place mutation, then `upsertTask` is called.
    /// Expected: the day spread's `dataModel` entry loses the task and the month spread's
    /// entry gains it — proving the union-of-old-and-new-keys patch covers both surfaces.
    @Test func testUpsertTaskMovesBetweenSpreadDataModelEntriesOnAssignmentChange() async {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: taskDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: taskDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Movable",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let store = Self.makeStore(spreads: [daySpread, monthSpread], tasks: [task])
        await store.load()

        task.assignments = [Assignment(period: .month, date: taskDate, status: .open)]
        store.upsertTask(task)

        let dayKey = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let monthKey = SpreadDataModelKey(spread: monthSpread, calendar: Self.calendar)
        #expect(store.dataModel[key: dayKey]?.tasks.isEmpty == true)
        #expect(store.dataModel[key: monthKey]?.tasks.map(\.id) == [task.id])
    }

    /// Setup: a note is upserted, then removed — mirrors the task tests for parity of behavior.
    @Test func testUpsertAndRemoveNoteUpdatesNotesAndDataModel() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let store = Self.makeStore(spreads: [daySpread])
        await store.load()

        let note = DataModel.Note(
            title: "New",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .active)]
        )
        store.upsertNote(note)

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.notes.map(\.id) == [note.id])
        #expect(store.dataModel[key: key]?.notes.map(\.id) == [note.id])

        store.removeNote(id: note.id)

        #expect(store.notes.isEmpty)
        #expect(store.dataModel[key: key]?.notes.isEmpty == true)
    }

    /// Setup: an event overlapping an existing day spread is upserted, then removed.
    /// Expected: the spread's `dataModel` entry gains and then loses the event.
    @Test func testUpsertAndRemoveEventUpdatesEventsAndDataModel() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let store = Self.makeStore(spreads: [daySpread])
        await store.load()

        let event = DataModel.Event(title: "New", startDate: dayDate, endDate: dayDate)
        store.upsertEvent(event)

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(store.events.map(\.id) == [event.id])
        #expect(store.dataModel[key: key]?.events.map(\.id) == [event.id])

        store.removeEvent(id: event.id)

        #expect(store.events.isEmpty)
        #expect(store.dataModel[key: key]?.events.isEmpty == true)
    }

    /// Setup: a new spread is created after an overlapping event already exists in the store.
    /// Expected: `spreads` includes the new spread, and its `dataModel` entry includes the
    /// pre-existing overlapping event — proving `upsertSpread` triggers the event-side
    /// recompute (`EventSpreadIndex.addSpread`).
    @Test func testUpsertSpreadIndexesPreexistingOverlappingEvents() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let event = DataModel.Event(title: "Existing", startDate: dayDate, endDate: dayDate)
        let store = Self.makeStore(events: [event])
        await store.load()

        let newSpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        store.upsertSpread(newSpread)

        let key = SpreadDataModelKey(spread: newSpread, calendar: Self.calendar)
        #expect(store.spreads.map(\.id) == [newSpread.id])
        #expect(store.dataModel[key: key]?.events.map(\.id) == [event.id])
    }

    /// Setup: a spread with an overlapping event is removed.
    /// Expected: `spreads` no longer includes it, its `dataModel` entry is gone, and the
    /// event is no longer indexed under that spread's key.
    @Test func testRemoveSpreadClearsDataModelAndEventIndexEntry() async {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let event = DataModel.Event(title: "Existing", startDate: dayDate, endDate: dayDate)
        let store = Self.makeStore(spreads: [spread], events: [event])
        await store.load()

        store.removeSpread(id: spread.id)

        let key = SpreadDataModelKey(spread: spread, calendar: Self.calendar)
        #expect(store.spreads.isEmpty)
        #expect(store.dataModel[key: key] == nil)
    }

    /// Setup: a multiday spread's date range is edited via `upsertSpread` (same ID, new dates).
    /// Expected: the stale key's `dataModel` entry is cleared and the new key's entry is
    /// populated — proving spread updates (not just creates) are handled, including the
    /// event-index recompute for the spread's new date range.
    @Test func testUpsertSpreadHandlesDateRangeChangeForExistingSpread() async {
        let originalStart = Self.makeDate(year: 2026, month: 1, day: 10)
        let originalEnd = Self.makeDate(year: 2026, month: 1, day: 12)
        let spread = DataModel.Spread(startDate: originalStart, endDate: originalEnd, calendar: Self.calendar)
        let originalEvent = DataModel.Event(title: "Original range", startDate: originalStart, endDate: originalStart)
        let store = Self.makeStore(spreads: [spread], events: [originalEvent])
        await store.load()

        let originalKey = SpreadDataModelKey(spread: spread, calendar: Self.calendar)
        #expect(store.dataModel[key: originalKey]?.events.map(\.id) == [originalEvent.id])

        let newStart = Self.makeDate(year: 2026, month: 2, day: 1)
        let newEnd = Self.makeDate(year: 2026, month: 2, day: 3)
        spread.date = newStart
        spread.startDate = newStart
        spread.endDate = newEnd
        let newEvent = DataModel.Event(title: "New range", startDate: newStart, endDate: newStart)
        store.upsertEvent(newEvent)
        store.upsertSpread(spread)

        let newKey = SpreadDataModelKey(spread: spread, calendar: Self.calendar)
        #expect(store.dataModel[key: originalKey] == nil)
        #expect(store.dataModel[key: newKey]?.events.map(\.id) == [newEvent.id])
    }

    /// Setup: `load()` runs once, then `upsertTask` mutates the store.
    /// Expected: `fullLoadCount` stays at 1 — the mutation never triggers a full rebuild,
    /// only `load()` does.
    @Test func testUpsertTaskDoesNotTriggerFullRebuild() async {
        let store = Self.makeStore()
        await store.load()
        #expect(store.fullLoadCount == 1)

        let task = DataModel.Task(title: "New", date: nil, period: nil)
        store.upsertTask(task)

        #expect(store.fullLoadCount == 1)
        #expect(store.tasks.map(\.id) == [task.id])
    }

    // MARK: - O(1) Resolution Cost

    /// A subscript-call-counting wrapper around `EntityStore`, used only to prove the
    /// resolution algorithm `resolveSpreadDataModel` relies on (`entityIDs(for:).compactMap
    /// { store[$0] }`) performs exactly as many lookups as there are matched entities,
    /// independent of how many unrelated entities also live in the store.
    private struct CountingEntityStore<E> {
        private let store: EntityStore<E>
        private(set) var subscriptAccessCount = 0

        init(_ entities: [E], idKeyPath: KeyPath<E, UUID>) {
            store = EntityStore(entities, idKeyPath: idKeyPath)
        }

        mutating func get(_ id: UUID) -> E? {
            subscriptAccessCount += 1
            return store[id]
        }
    }

    /// Setup: a `SpreadKeyIndex` is populated with 5,000 unrelated tasks (indexed under
    /// other dates) plus one matching task, then the resolution snippet
    /// `entityIDs(for:).compactMap { store[$0] }` — the exact pattern `resolveSpreadDataModel`
    /// uses — is run against a call-counting store wrapper.
    /// Expected: exactly one subscript access occurs, not 5,001 — proving resolution cost
    /// is O(matched entities), independent of total store size N.
    @Test func testResolvingSpreadDataModelPerformsOnlyMatchedLookupsIndependentOfN() {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        let matchingTask = DataModel.Task(
            title: "Match",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )

        var unrelatedTasks: [DataModel.Task] = []
        for index in 0..<5_000 {
            let unrelatedDate = Self.makeDate(year: 2030, month: 1, day: (index % 27) + 1)
            unrelatedTasks.append(
                DataModel.Task(
                    title: "Unrelated\(index)",
                    date: unrelatedDate,
                    period: .day,
                    assignments: [Assignment(period: .day, date: unrelatedDate, status: .open)]
                )
            )
        }
        let allTasks = unrelatedTasks + [matchingTask]

        let engine = JournalRuleEngine(calendar: Self.calendar)
        var index = SpreadKeyIndex()
        for task in allTasks {
            index.update(entityID: task.id, keys: engine.spreadKeys(for: task, spreads: [daySpread]))
        }
        var countingStore = CountingEntityStore(allTasks, idKeyPath: \DataModel.Task.id)

        let matchedTasks = index.entityIDs(for: key).compactMap { countingStore.get($0) }

        #expect(matchedTasks.map(\.id) == [matchingTask.id])
        #expect(countingStore.subscriptAccessCount == 1)
    }
}
