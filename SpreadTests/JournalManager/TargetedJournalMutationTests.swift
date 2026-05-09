import Foundation
import Testing
@testable import Spread

@Suite(.serialized) @MainActor
struct TargetedJournalMutationTests {
    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static var today: Date {
        calendar.date(from: DateComponents(year: 2026, month: 1, day: 15))!
    }

    private static var appClock: AppClock {
        AppClock.fixed(
            now: today,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale ?? Locale(identifier: "en_US_POSIX")
        )
    }

    @Test func updateTaskTitleUsesScopedRefreshWithoutReloadingTaskRepository() async throws {
        let dayDate = Self.today
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Original",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let taskRepository = CountingTaskRepository(tasks: [task])
        let builderTracker = DataModelBuilderTracker()
        let builder = TrackingConventionalBuilder(calendar: Self.calendar, tracker: builderTracker)
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: taskRepository,
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            conventionalDataModelBuilder: builder
        )

        await manager.reload()
        let getTasksCallsAfterReload = taskRepository.getTasksCallCount
        let fullBuildsAfterReload = builderTracker.fullBuildCallCount

        try await manager.updateTaskTitle(task, newTitle: "Updated")

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(taskRepository.getTasksCallCount == getTasksCallsAfterReload)
        #expect(builderTracker.fullBuildCallCount == fullBuildsAfterReload)
        #expect(builderTracker.targetedBuildKeys == [key])
        #expect(manager.dataModel[key: key]?.tasks.first?.title == "Updated")
    }

    @Test func updateNoteTitleUsesScopedRefreshWithoutReloadingNoteRepository() async throws {
        let dayDate = Self.today
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let note = DataModel.Note(
            title: "Original",
            content: "Body",
            date: dayDate,
            period: .day,
            assignments: [NoteAssignment(period: .day, date: dayDate, status: .active)]
        )
        let noteRepository = CountingNoteRepository(notes: [note])
        let builderTracker = DataModelBuilderTracker()
        let builder = TrackingConventionalBuilder(calendar: Self.calendar, tracker: builderTracker)
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(),
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: noteRepository,
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            conventionalDataModelBuilder: builder
        )

        await manager.reload()
        let getNotesCallsAfterReload = noteRepository.getNotesCallCount
        let fullBuildsAfterReload = builderTracker.fullBuildCallCount

        try await manager.updateNoteTitle(note, newTitle: "Updated", newContent: "Changed")

        let key = SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)
        #expect(noteRepository.getNotesCallCount == getNotesCallsAfterReload)
        #expect(builderTracker.fullBuildCallCount == fullBuildsAfterReload)
        #expect(builderTracker.targetedBuildKeys == [key])
        #expect(manager.dataModel[key: key]?.notes.first?.title == "Updated")
    }

    @Test func updateTaskDateAndPeriodRebuildsOnlySourceAndDestinationSpreads() async throws {
        let dayDate = Self.today
        let monthDate = Self.calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        let daySpread = DataModel.Spread(period: .day, date: dayDate, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: monthDate, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Move me",
            date: dayDate,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: dayDate, status: .open)]
        )
        let builderTracker = DataModelBuilderTracker()
        let builder = TrackingConventionalBuilder(calendar: Self.calendar, tracker: builderTracker)
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread, monthSpread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            conventionalDataModelBuilder: builder
        )
        await manager.reload()

        let fullBuildsAfterLoad = builderTracker.fullBuildCallCount
        try await manager.updateTaskDateAndPeriod(task, newDate: monthDate, newPeriod: Period.month)

        let expectedKeys = Set([
            SpreadDataModelKey(spread: daySpread, calendar: Self.calendar),
            SpreadDataModelKey(spread: monthSpread, calendar: Self.calendar)
        ])
        #expect(builderTracker.fullBuildCallCount == fullBuildsAfterLoad)
        #expect(Set(builderTracker.targetedBuildKeys) == expectedKeys)
        #expect(manager.dataModel[key: SpreadDataModelKey(spread: daySpread, calendar: Self.calendar)]?.tasks.isEmpty == true)
        #expect(manager.dataModel[key: SpreadDataModelKey(spread: monthSpread, calendar: Self.calendar)]?.tasks.map { $0.id } == [task.id])
    }

    @Test func deleteSpreadUsesStructuralFallback() async throws {
        let daySpread = DataModel.Spread(period: .day, date: Self.today, calendar: Self.calendar)
        let monthSpread = DataModel.Spread(period: .month, date: Self.today, calendar: Self.calendar)
        let task = DataModel.Task(
            title: "Task",
            date: Self.today,
            period: .day,
            status: .open,
            assignments: [TaskAssignment(period: .day, date: Self.today, status: .open)]
        )
        let builderTracker = DataModelBuilderTracker()
        let builder = TrackingConventionalBuilder(calendar: Self.calendar, tracker: builderTracker)
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [daySpread, monthSpread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            conventionalDataModelBuilder: builder
        )
        await manager.reload()

        let fullBuildsAfterLoad = builderTracker.fullBuildCallCount
        try await manager.deleteSpread(daySpread)

        #expect(builderTracker.fullBuildCallCount == fullBuildsAfterLoad + 1)
    }
}

@MainActor
private final class CountingTaskRepository: TaskRepository {
    private var stored: [UUID: DataModel.Task]
    private(set) var getTasksCallCount = 0

    init(tasks: [DataModel.Task]) {
        self.stored = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    func getTasks() async -> [DataModel.Task] {
        getTasksCallCount += 1
        return stored.values.sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ task: DataModel.Task) async throws {
        stored[task.id] = task
    }

    func delete(_ task: DataModel.Task) async throws {
        stored[task.id] = nil
    }
}

@MainActor
private final class CountingNoteRepository: NoteRepository {
    private var stored: [UUID: DataModel.Note]
    private(set) var getNotesCallCount = 0

    init(notes: [DataModel.Note]) {
        self.stored = Dictionary(uniqueKeysWithValues: notes.map { ($0.id, $0) })
    }

    func getNotes() async -> [DataModel.Note] {
        getNotesCallCount += 1
        return stored.values.sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ note: DataModel.Note) async throws {
        stored[note.id] = note
    }

    func delete(_ note: DataModel.Note) async throws {
        stored[note.id] = nil
    }
}

@MainActor
private final class DataModelBuilderTracker {
    private(set) var fullBuildCallCount = 0
    private(set) var targetedBuildKeys: [SpreadDataModelKey] = []

    func recordFullBuild() {
        fullBuildCallCount += 1
    }

    func recordTargetedBuild(key: SpreadDataModelKey) {
        targetedBuildKeys.append(key)
    }
}

@MainActor
private struct TrackingConventionalBuilder: JournalDataModelBuilder {
    let calendar: Calendar
    let tracker: DataModelBuilderTracker

    private var base: ConventionalJournalDataModelBuilder {
        ConventionalJournalDataModelBuilder(calendar: calendar)
    }

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        tracker.recordFullBuild()
        return base.buildDataModel(spreads: spreads, tasks: tasks, notes: notes, events: events)
    }

    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel? {
        tracker.recordTargetedBuild(key: key)
        return base.buildSpreadDataModel(for: key, spreads: spreads, tasks: tasks, notes: notes, events: events)
    }

    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        base.spreadKeys(for: task, spreads: spreads)
    }

    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        base.spreadKeys(for: note, spreads: spreads)
    }

    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey? {
        base.spreadKey(for: spread, spreads: spreads, tasks: tasks, notes: notes, events: events)
    }
}
