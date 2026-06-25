import Foundation
import Testing
@testable import Spread

/// Parity tests proving `JournalDataStore` (SPRD-249), driven through `NewFacadeTestActions`'
/// reconcile-then-persist-then-upsert sequences, produces identical observable results to the
/// legacy `JournalManager` for task/note CRUD — the first scenario group from SPRD-250's AC.
///
/// Each test builds two independent systems from equivalent (same-ID, separate-instance)
/// fixtures, performs the same logical operation on both, then compares `tasks`/`notes`/
/// `dataModel` contents. Separate instances matter: `DataModel.Task`/`Note`/`Spread` are
/// classes, so sharing one instance across both systems would make any divergence invisible
/// (mutating it via one system's path would silently "fix" the other system's copy too).
@Suite(.serialized) @MainActor
struct TaskNoteFacadeParityTests {
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
        content: String = "",
        date: Date?,
        period: Period,
        assignments: [Assignment] = []
    ) -> (legacy: DataModel.Note, new: DataModel.Note) {
        (
            DataModel.Note(id: id, title: title, content: content, date: date, period: period, assignments: assignments),
            DataModel.Note(id: id, title: title, content: content, date: date, period: period, assignments: assignments)
        )
    }

    /// Builds both systems from equivalent fixtures: the legacy `JournalManager` (wired to
    /// `InMemory*Repository`) and the new `JournalDataStore` + `NewFacadeTestActions` (wired
    /// to `TestChangeAware*Repository`).
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

    // MARK: - Task CRUD

    /// Setup: a day spread exists; a task is created with a matching preferred date on both systems.
    /// Expected: both systems place the task on the same spread with an identical assignment.
    @Test func testCreateTaskWithMatchingSpreadProducesIdenticalAssignment() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spreadPair = Self.makeSpreadPair(period: .day, date: dayDate)
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [spreadPair])

        let legacyTask = try await legacy.addTask(title: "Task", date: dayDate, period: .day, body: nil, priority: .none, dueDate: nil)
        let newTask = try await actions.createTask(title: "Task", date: dayDate, period: .day)

        #expect(legacyTask.assignments.map(\.period) == newTask.assignments.map(\.period))
        #expect(legacyTask.assignments.map(\.date) == newTask.assignments.map(\.date))
        #expect(legacy.tasks.count == newStore.tasks.count)

        let key = SpreadDataModelKey(spread: spreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.tasks.count == newStore.dataModel[key: key]?.tasks.count)
    }

    /// Setup: a task is created with no preferred date on both systems.
    /// Expected: both systems leave it unassigned (Inbox) with no assignments.
    @Test func testCreateTaskWithNoDateLeavesBothInInbox() async throws {
        let (legacy, newStore, actions) = await Self.makeSystems()

        let legacyTask = try await legacy.addTask(title: "Inbox task", date: nil, period: nil, body: nil, priority: .none, dueDate: nil)
        let newTask = try await actions.createTask(title: "Inbox task", date: nil, period: nil)

        #expect(legacyTask.assignments.isEmpty)
        #expect(newTask.assignments.isEmpty)
        #expect(legacy.tasks.count == newStore.tasks.count)
    }

    /// Setup: an existing task's title is updated on both systems.
    /// Expected: both reflect the new title with no change to assignments.
    @Test func testUpdateTaskTitleMatchesOnBothSystems() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let taskPair = Self.makeTaskPair(
            title: "Original",
            date: dayDate,
            period: .day,
            assignments: [Assignment(period: .day, date: dayDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(taskPairs: [taskPair])

        try await legacy.updateTaskTitle(taskPair.legacy, newTitle: "Updated")
        try await actions.updateTaskTitle(taskPair.new, newTitle: "Updated")

        #expect(legacy.tasks.first?.title == newStore.tasks.first?.title)
        #expect(legacy.tasks.first?.assignments == newStore.tasks.first?.assignments)
    }

    /// Setup: a task moves from a day spread to a month spread (both spreads exist) on both systems.
    /// Expected: both systems migrate the day assignment to history and create an active month assignment.
    @Test func testUpdateTaskDateAndPeriodProducesIdenticalReconciliation() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let daySpreadPair = Self.makeSpreadPair(period: .day, date: taskDate)
        let monthSpreadPair = Self.makeSpreadPair(period: .month, date: taskDate)
        let taskPair = Self.makeTaskPair(
            title: "Movable",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(
            spreadPairs: [daySpreadPair, monthSpreadPair],
            taskPairs: [taskPair]
        )

        try await legacy.updateTaskDateAndPeriod(taskPair.legacy, newDate: taskDate, newPeriod: .month)
        try await actions.updateTaskDateAndPeriod(taskPair.new, newDate: taskDate, newPeriod: .month)

        #expect(taskPair.legacy.assignments.map(\.status) == taskPair.new.assignments.map(\.status))
        #expect(taskPair.legacy.assignments.map(\.period) == taskPair.new.assignments.map(\.period))

        let monthKey = SpreadDataModelKey(spread: monthSpreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: monthKey]?.tasks.count == newStore.dataModel[key: monthKey]?.tasks.count)
    }

    /// Setup: a task with an active spread assignment has its preferred assignment cleared
    /// on both systems.
    /// Expected: both migrate the active assignment to history, leaving the task in Inbox.
    @Test func testClearTaskPreferredAssignmentMatchesOnBothSystems() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spreadPair = Self.makeSpreadPair(period: .day, date: taskDate)
        let taskPair = Self.makeTaskPair(
            title: "Clearable",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [spreadPair], taskPairs: [taskPair])

        try await legacy.clearTaskPreferredAssignment(taskPair.legacy)
        try await actions.clearTaskPreferredAssignment(taskPair.new)

        #expect(taskPair.legacy.date == nil)
        #expect(taskPair.new.date == nil)
        #expect(taskPair.legacy.assignments.map(\.status) == taskPair.new.assignments.map(\.status))

        let key = SpreadDataModelKey(spread: spreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.tasks.isEmpty == newStore.dataModel[key: key]?.tasks.isEmpty)
    }

    /// Setup: an assigned task is deleted on both systems.
    /// Expected: both remove it from `tasks` and from its spread's `dataModel` entry.
    @Test func testDeleteTaskMatchesOnBothSystems() async throws {
        let taskDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spreadPair = Self.makeSpreadPair(period: .day, date: taskDate)
        let taskPair = Self.makeTaskPair(
            title: "Removable",
            date: taskDate,
            period: .day,
            assignments: [Assignment(period: .day, date: taskDate, status: .open)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [spreadPair], taskPairs: [taskPair])

        try await legacy.deleteTask(taskPair.legacy)
        try await actions.deleteTask(taskPair.new)

        #expect(legacy.tasks.isEmpty)
        #expect(newStore.tasks.isEmpty)

        let key = SpreadDataModelKey(spread: spreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.tasks.isEmpty == true)
        #expect(newStore.dataModel[key: key]?.tasks.isEmpty == true)
    }

    // MARK: - Note CRUD

    /// Setup: a day spread exists; a note is created with a matching date on both systems.
    /// Expected: both systems place the note on the same spread with an identical assignment.
    @Test func testCreateNoteWithMatchingSpreadProducesIdenticalAssignment() async throws {
        let dayDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spreadPair = Self.makeSpreadPair(period: .day, date: dayDate)
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [spreadPair])

        let legacyNote = try await legacy.addNote(title: "Note", content: "Body", date: dayDate, period: .day)
        let newNote = try await actions.createNote(title: "Note", content: "Body", date: dayDate, period: .day)

        #expect(legacyNote.assignments.map(\.status) == newNote.assignments.map(\.status))
        #expect(legacy.notes.count == newStore.notes.count)

        let key = SpreadDataModelKey(spread: spreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.notes.count == newStore.dataModel[key: key]?.notes.count)
    }

    /// Setup: an existing note's title/content is updated on both systems.
    /// Expected: both reflect the new content with no change to assignments.
    @Test func testUpdateNoteTitleMatchesOnBothSystems() async throws {
        let noteDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let notePair = Self.makeNotePair(
            title: "Original",
            date: noteDate,
            period: .day,
            assignments: [Assignment(period: .day, date: noteDate, status: .active)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(notePairs: [notePair])

        try await legacy.updateNoteTitle(notePair.legacy, newTitle: "Updated", newContent: "New body")
        try await actions.updateNoteTitle(notePair.new, newTitle: "Updated", newContent: "New body")

        #expect(legacy.notes.first?.title == newStore.notes.first?.title)
        #expect(legacy.notes.first?.content == newStore.notes.first?.content)
    }

    /// Setup: an assigned note is deleted on both systems.
    /// Expected: both remove it from `notes` and from its spread's `dataModel` entry.
    @Test func testDeleteNoteMatchesOnBothSystems() async throws {
        let noteDate = Self.makeDate(year: 2026, month: 1, day: 12)
        let spreadPair = Self.makeSpreadPair(period: .day, date: noteDate)
        let notePair = Self.makeNotePair(
            title: "Removable",
            date: noteDate,
            period: .day,
            assignments: [Assignment(period: .day, date: noteDate, status: .active)]
        )
        let (legacy, newStore, actions) = await Self.makeSystems(spreadPairs: [spreadPair], notePairs: [notePair])

        try await legacy.deleteNote(notePair.legacy)
        try await actions.deleteNote(notePair.new)

        #expect(legacy.notes.isEmpty)
        #expect(newStore.notes.isEmpty)

        let key = SpreadDataModelKey(spread: spreadPair.legacy, calendar: Self.calendar)
        #expect(legacy.dataModel[key: key]?.notes.isEmpty == true)
        #expect(newStore.dataModel[key: key]?.notes.isEmpty == true)
    }
}
