import Foundation
import Testing
@testable import Spread

/// Parity tests covering SPRD-250's remaining scenario groups: spread create (with the
/// new-explicit-spread auto-migration reconciliation pass) and delete, single/batch task
/// migration, note migration, Inbox membership, overdue evaluation, and multiday assignment.
///
/// Shares `TaskNoteFacadeParityTests`' dual-fixture pattern: two independent systems built
/// from same-ID-but-separate-instance fixtures, since `DataModel.Task`/`Note`/`Spread` are
/// classes and sharing one instance across both systems would make any divergence invisible.
@Suite(.serialized) @MainActor
struct SpreadAndMigrationFacadeParityTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    private static func makeSpreadPair(
        id: UUID = UUID(),
        period: Period,
        date: Date
    ) -> (legacy: DataModel.Spread, new: DataModel.Spread) {
        (
            DataModel.Spread(id: id, period: period, date: date, calendar: calendar),
            DataModel.Spread(id: id, period: period, date: date, calendar: calendar)
        )
    }

    private static func makeTaskPair(
        id: UUID = UUID(),
        title: String,
        date: Date?,
        period: Period?,
        status: EntryStatus = .open,
        assignments: [Assignment] = []
    ) -> (legacy: DataModel.Task, new: DataModel.Task) {
        (
            DataModel.Task(id: id, title: title, date: date, period: period, status: status, assignments: assignments),
            DataModel.Task(id: id, title: title, date: date, period: period, status: status, assignments: assignments)
        )
    }

    private static func makeNotePair(
        id: UUID = UUID(),
        title: String,
        date: Date?,
        period: Period,
        assignments: [Assignment] = []
    ) -> (legacy: DataModel.Note, new: DataModel.Note) {
        (
            DataModel.Note(id: id, title: title, date: date, period: period, assignments: assignments),
            DataModel.Note(id: id, title: title, date: date, period: period, assignments: assignments)
        )
    }

    private static func makeSystems(
        spreadPairs: [(legacy: DataModel.Spread, new: DataModel.Spread)] = [],
        taskPairs: [(legacy: DataModel.Task, new: DataModel.Task)] = [],
        notePairs: [(legacy: DataModel.Note, new: DataModel.Note)] = []
    ) async -> (legacy: JournalManager, newStore: JournalDataStore, actions: NewFacadeTestActions) {
        let legacy = JournalManager(
            appClock: .fixed(now: .now, calendar: calendar, timeZone: calendar.timeZone, locale: Locale(identifier: "en_US_POSIX")),
            taskRepository: InMemoryTaskRepository(tasks: taskPairs.map(\.legacy)),
            spreadRepository: InMemorySpreadRepository(spreads: spreadPairs.map(\.legacy)),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(notes: notePairs.map(\.legacy)),
            creationPolicy: StandardCreationPolicy(today: .now, firstWeekday: .systemDefault)
        )
        await legacy.reload()

        let newTaskRepository = TestChangeAwareTaskRepository(tasks: taskPairs.map(\.new))
        let newNoteRepository = TestChangeAwareNoteRepository(notes: notePairs.map(\.new))
        let newSpreadRepository = InMemorySpreadRepository(spreads: spreadPairs.map(\.new))
        let newStore = JournalDataStore(
            calendar: calendar,
            taskRepository: newTaskRepository,
            noteRepository: newNoteRepository,
            spreadRepository: newSpreadRepository,
            eventRepository: InMemoryEventRepository()
        )
        await newStore.load()

        let actions = NewFacadeTestActions(
            store: newStore,
            calendar: calendar,
            ruleEngine: JournalRuleEngine(calendar: calendar),
            taskRepository: newTaskRepository,
            noteRepository: newNoteRepository,
            spreadRepository: newSpreadRepository
        )

        return (legacy, newStore, actions)
    }

    // MARK: - Spread Create (with auto-migration reconciliation)

    /// Setup: an Inbox-origin task whose preferred date matches a not-yet-created day spread.
    /// Expected: creating that spread auto-migrates the task into it on both systems.
    @Test func testCreateSpreadAutoMigratesMatchingInboxTask() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let taskPair = Self.makeTaskPair(title: "Waiting", date: dayDate, period: .day)
        let (legacy, newStore, actions) = await Self.makeSystems(taskPairs: [taskPair])

        let legacySummary = try await legacy.createSpread(period: .day, date: dayDate)
        let newSpread = try await actions.createSpread(period: .day, date: dayDate)

        #expect(legacySummary.autoMigrationSummary != nil)
        #expect(taskPair.legacy.assignments.map(\.status) == taskPair.new.assignments.map(\.status))

        let key = SpreadDataModelKey(spread: newSpread, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.tasks.count == newStore.dataModel[key: key]?.tasks.count)
    }

    /// Setup: a day spread is created with no existing tasks/notes that would match it.
    /// Expected: both systems simply add the spread with no auto-migration side effects.
    @Test func testCreateSpreadWithNoEligibleEntriesMatchesOnBothSystems() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let (legacy, newStore, actions) = await Self.makeSystems()

        let legacySummary = try await legacy.createSpread(period: .day, date: dayDate)
        try await actions.createSpread(period: .day, date: dayDate)

        #expect(legacySummary.autoMigrationSummary == nil)
        #expect(legacy.spreads.count == newStore.spreads.count)
    }

    // MARK: - Spread Delete (day -> month parent reassignment)

    /// Setup: a task is assigned to a day spread whose parent month spread also exists.
    /// Deleting the day spread should reassign the task to the month spread on both systems.
    @Test func testDeleteSpreadReassignsToParentSpread() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: dayDate)
        let monthSpreadPair = Self.makeSpreadPair(period: .month, date: dayDate)
        let taskPair = Self.makeTaskPair(
            title: "Reassign me",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [daySpreadPair, monthSpreadPair],
            taskPairs: [taskPair]
        )

        try await legacy.deleteSpread(daySpreadPair.legacy)
        try await actions.deleteSpreadWithReassignment(daySpreadPair.new)

        #expect(taskPair.legacy.assignments.map(\.status) == taskPair.new.assignments.map(\.status))
        #expect(taskPair.legacy.assignments.map(\.period) == taskPair.new.assignments.map(\.period))

        let monthKey = SpreadDataModelKey(spread: monthSpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: monthKey]?.tasks.count == newStore.dataModel[key: monthKey]?.tasks.count)
        #expect(legacy.spreads.count == newStore.spreads.count)
    }

    /// Setup: a task is assigned to a day spread with no existing parent spread.
    /// Expected: deleting the day spread migrates the task to history with no replacement
    /// assignment — it falls back to Inbox on both systems.
    @Test func testDeleteSpreadWithNoParentFallsBackToInboxOnBothSystems() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: dayDate)
        let taskPair = Self.makeTaskPair(
            title: "To Inbox",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [daySpreadPair], taskPairs: [taskPair])

        try await legacy.deleteSpread(daySpreadPair.legacy)
        try await actions.deleteSpreadWithReassignment(daySpreadPair.new)

        #expect(taskPair.legacy.assignments.allSatisfy { $0.status == .migrated })
        #expect(taskPair.new.assignments.allSatisfy { $0.status == .migrated })
        #expect(legacy.spreads.isEmpty)
        #expect(newStore.spreads.isEmpty)
    }

    // MARK: - Migration (single + batch)

    /// Setup: a task currently on a year spread is migrated to a day spread on both systems.
    /// Expected: identical resulting assignments (year migrated, day active/open).
    @Test func testMigrateTaskMatchesOnBothSystems() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let yearSpreadPair = Self.makeSpreadPair(period: .year, date: taskDate)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: taskDate)
        let taskPair = Self.makeTaskPair(
            title: "Migrate me",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .year, date: taskDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [yearSpreadPair, daySpreadPair],
            taskPairs: [taskPair]
        )

        try await legacy.migrateTask(taskPair.legacy, from: yearSpreadPair.legacy, to: daySpreadPair.legacy)
        try await actions.migrateTask(taskPair.new, from: yearSpreadPair.new, to: daySpreadPair.new)

        #expect(taskPair.legacy.assignments.map(\.status) == taskPair.new.assignments.map(\.status))
        #expect(taskPair.legacy.assignments.map(\.period) == taskPair.new.assignments.map(\.period))

        let dayKey = SpreadDataModelKey(spread: daySpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: dayKey]?.tasks.count == newStore.dataModel[key: dayKey]?.tasks.count)
    }

    /// Setup: two tasks on a month spread (one cancelled) are batch-migrated to a day spread.
    /// Expected: the cancelled task is skipped on both systems; the other migrates identically.
    @Test func testMigrateTasksBatchSkipsCancelledOnBothSystems() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let monthSpreadPair = Self.makeSpreadPair(period: .month, date: taskDate)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: taskDate)
        let activeTaskPair = Self.makeTaskPair(
            title: "Active",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .month, date: taskDate, status: .open)]
        )
        let cancelledTaskPair = Self.makeTaskPair(
            title: "Cancelled",
            date: taskDate,
            period: .day,
            status: .cancelled,
            assignments: [Assignment(period: .month, date: taskDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [monthSpreadPair, daySpreadPair],
            taskPairs: [activeTaskPair, cancelledTaskPair]
        )

        try await legacy.migrateTasksBatch([activeTaskPair.legacy, cancelledTaskPair.legacy], from: monthSpreadPair.legacy, to: daySpreadPair.legacy)
        try await actions.migrateTasksBatch([activeTaskPair.new, cancelledTaskPair.new], from: monthSpreadPair.new, to: daySpreadPair.new)

        #expect(activeTaskPair.legacy.assignments.map(\.status) == activeTaskPair.new.assignments.map(\.status))
        #expect(cancelledTaskPair.legacy.assignments.map(\.status) == cancelledTaskPair.new.assignments.map(\.status))

        let dayKey = SpreadDataModelKey(spread: daySpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: dayKey]?.tasks.count == newStore.dataModel[key: dayKey]?.tasks.count)
    }

    /// Setup: a note currently on a year spread is migrated to a day spread on both systems.
    /// Expected: identical resulting assignments (year migrated, day active).
    @Test func testMigrateNoteMatchesOnBothSystems() async throws {
        let noteDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let yearSpreadPair = Self.makeSpreadPair(period: .year, date: noteDate)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: noteDate)
        let notePair = Self.makeNotePair(
            title: "Migrate me",
            date: noteDate,
            period: .day,
            assignments: [Assignment(period: .year, date: noteDate, status: .active)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [yearSpreadPair, daySpreadPair],
            notePairs: [notePair]
        )

        try await legacy.migrateNote(notePair.legacy, from: yearSpreadPair.legacy, to: daySpreadPair.legacy)
        try await actions.migrateNote(notePair.new, from: yearSpreadPair.new, to: daySpreadPair.new)

        #expect(notePair.legacy.assignments.map(\.status) == notePair.new.assignments.map(\.status))

        let dayKey = SpreadDataModelKey(spread: daySpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: dayKey]?.notes.count == newStore.dataModel[key: dayKey]?.notes.count)
    }

    // MARK: - Inbox Membership

    /// Setup: an unassigned open task and an unassigned note exist on both systems.
    /// Expected: full parity for the task (both include it in Inbox); a confirmed,
    /// already-documented divergence for the note (legacy includes it, the new
    /// `JournalRuleEngine`-based facade excludes it via `Note.isInboxEligible == false`,
    /// per SPRD-248's own parity notes). This locks in the divergence rather than letting
    /// a naive full-equality assertion fail here.
    @Test func testInboxMembershipMatchesForTasksAndConfirmedDivergesForNotes() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let taskPair = Self.makeTaskPair(title: "Inbox task", date: dayDate, period: .day)
        let notePair = Self.makeNotePair(title: "Inbox note", date: dayDate, period: .day)
        let (legacy, newStore, _) = await Self.makeSystems(taskPairs: [taskPair], notePairs: [notePair])

        let legacyInbox = legacy.inboxEntries
        let newInbox = JournalRuleEngine(calendar: Self.calendar).inboxEntries(
            entries: newStore.tasks + newStore.notes,
            spreads: newStore.spreads
        )

        #expect(legacyInbox.contains { $0.id == taskPair.legacy.id })
        #expect(newInbox.contains { $0.id == taskPair.new.id })
        #expect(legacyInbox.contains { $0.id == notePair.legacy.id })
        #expect(!newInbox.contains { $0.id == notePair.new.id })
    }

    // MARK: - Overdue Evaluation

    /// Setup: an unassigned task with a past preferred date exists on both systems.
    /// Expected: both report it as overdue with an Inbox source.
    @Test func testOverdueTaskItemsMatchOnBothSystems() async throws {
        let pastDate = Self.makeDate(year: 2020, month: 1, day: 1)
        let taskPair = Self.makeTaskPair(title: "Overdue", date: pastDate, period: .day)
        let (legacy, newStore, _) = await Self.makeSystems(taskPairs: [taskPair])

        let legacyOverdue = legacy.overdueTaskItems
        let newOverdue = JournalRuleEngine(calendar: Self.calendar, today: .now).overdueTaskItems(
            tasks: newStore.tasks,
            spreads: newStore.spreads
        )

        #expect(legacyOverdue.map(\.task.id) == [taskPair.legacy.id])
        #expect(newOverdue.map(\.task.id) == [taskPair.new.id])
        #expect(legacyOverdue.first?.sourceKey.id == newOverdue.first?.sourceKey.id)
    }

    // MARK: - Multiday Assignment

    /// Setup: a task and note are both created with an explicit preferred multiday spread ID.
    /// Expected: both systems place them on the multiday spread identically.
    @Test func testCreateTaskAndNoteWithMultidaySpreadMatchOnBothSystems() async throws {
        let startDate = Self.makeDate(year: 2026, month: 1, day: 10)
        let endDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let multidaySpreadPair = (
            legacy: DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar),
            new: DataModel.Spread(startDate: startDate, endDate: endDate, calendar: Self.calendar)
        )
        // Re-key the "new" copy to share the same ID as the legacy copy for cross-system comparison.
        let sharedID = multidaySpreadPair.legacy.id
        let newMultidaySpread = DataModel.Spread(
            id: sharedID,
            startDate: startDate,
            endDate: endDate,
            calendar: Self.calendar
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [(legacy: multidaySpreadPair.legacy, new: newMultidaySpread)]
        )

        let taskDate = Self.makeDate(year: 2026, month: 1, day: 11)
        let legacyTask = try await legacy.addTask(
            title: "Multiday task",
            date: taskDate,
            period: .multiday,
            preferredSpreadID: sharedID,
            body: nil,
            priority: .none,
            dueDate: nil
        )
        let newTask = try await actions.createTask(
            title: "Multiday task",
            date: taskDate,
            period: .multiday,
            preferredSpreadID: sharedID
        )

        #expect(legacyTask.assignments.map(\.spreadID) == newTask.assignments.map(\.spreadID))
        #expect(legacyTask.assignments.map(\.period) == newTask.assignments.map(\.period))

        let legacyNote = try await legacy.addNote(title: "Multiday note", date: taskDate, period: .multiday, preferredSpreadID: sharedID)
        let newNote = try await actions.createNote(title: "Multiday note", content: "", date: taskDate, period: .multiday, preferredSpreadID: sharedID)

        #expect(legacyNote.assignments.map(\.spreadID) == newNote.assignments.map(\.spreadID))
        #expect(legacyNote.assignments.map(\.period) == newNote.assignments.map(\.period))

        let key = SpreadDataModelKey(spread: multidaySpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.tasks.count == newStore.dataModel[key: key]?.tasks.count)
        #expect(legacy.dataModel[key: key]?.notes.count == newStore.dataModel[key: key]?.notes.count)
    }
}
