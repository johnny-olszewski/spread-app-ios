import Foundation
import Testing
@testable import Spread

@Suite(.serialized) @MainActor
struct JournalManagerFacadeDelegationTests {
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

    @Test func reloadUsesInjectedConventionalBuilder() async throws {
        let spread = DataModel.Spread(period: .day, date: Self.today, calendar: Self.calendar)
        let expected = SpreadDataModel(spread: spread)
        let tracker = BuilderTracker()
        let builder = TrackingJournalDataModelBuilder(
            tracker: tracker,
            model: [.day: [Period.day.normalizeDate(Self.today, calendar: Self.calendar): expected]]
        )

        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(),
            spreadRepository: InMemorySpreadRepository(spreads: [spread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            conventionalDataModelBuilder: builder
        )

        await manager.reload()

        #expect(tracker.buildCallCount == 1)
        #expect(manager.dataModel[.day]?[Period.day.normalizeDate(Self.today, calendar: Self.calendar)]?.spread.id == spread.id)
    }

    @Test func moveTaskUsesInjectedMigrationCoordinatorAndRefreshesVersion() async throws {
        let spread = DataModel.Spread(period: .day, date: Self.today, calendar: Self.calendar)
        let task = DataModel.Task(title: "task", date: Self.today, period: .day, status: .open)
        let migrationTracker = MigrationTracker()
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(tasks: [task]),
            spreadRepository: InMemorySpreadRepository(spreads: [spread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            taskMigrationCoordinator: TrackingTaskMigrationCoordinator(
                tracker: migrationTracker,
                resultTasks: [task]
            )
        )

        await manager.reload()
        let initialVersion = manager.dataVersion

        try await manager.moveTask(task, from: .init(kind: .inbox), to: spread)

        #expect(migrationTracker.moveCallCount == 1)
        #expect(manager.dataVersion == initialVersion + 1)
    }

    @Test func deleteSpreadUsesInjectedDeletionCoordinatorAndRefreshesState() async throws {
        let spread = DataModel.Spread(period: .day, date: Self.today, calendar: Self.calendar)
        let replacementSpread = DataModel.Spread(period: .month, date: Self.today, calendar: Self.calendar)
        let deletionTracker = DeletionTracker()
        let manager = JournalManager(
            appClock: Self.appClock,
            taskRepository: InMemoryTaskRepository(),
            spreadRepository: InMemorySpreadRepository(spreads: [spread]),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            bujoMode: .conventional,
            creationPolicy: StandardCreationPolicy(today: Self.today, firstWeekday: .systemDefault),
            spreadDeletionCoordinator: TrackingSpreadDeletionCoordinator(
                tracker: deletionTracker,
                result: SpreadDeletionResult(
                    plan: SpreadDeletionPlan(spread: spread, parentSpread: replacementSpread, taskPlans: [], notePlans: []),
                    spreads: [replacementSpread],
                    tasks: [],
                    notes: []
                )
            )
        )

        await manager.reload()
        let initialVersion = manager.dataVersion

        try await manager.deleteSpread(spread)

        #expect(deletionTracker.deleteCallCount == 1)
        #expect(manager.spreads.map(\.id) == [replacementSpread.id])
        #expect(manager.dataVersion == initialVersion + 1)
    }
}

@MainActor
private final class BuilderTracker {
    var buildCallCount = 0
}

@MainActor
private struct TrackingJournalDataModelBuilder: JournalDataModelBuilder {
    let tracker: BuilderTracker
    let model: JournalDataModel
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        tracker.buildCallCount += 1
        return model
    }

    func buildSpreadDataModel(
        for key: SpreadDataModelKey,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModel? {
        model[key: key]
    }

    func spreadKeys(
        for task: DataModel.Task,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        Set(task.assignments.map { SpreadDataModelKey(period: $0.period, date: $0.date, calendar: calendar) })
    }

    func spreadKeys(
        for note: DataModel.Note,
        spreads: [DataModel.Spread]
    ) -> Set<SpreadDataModelKey> {
        Set(note.assignments.map { SpreadDataModelKey(period: $0.period, date: $0.date, calendar: calendar) })
    }

    func spreadKey(
        for spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> SpreadDataModelKey? {
        SpreadDataModelKey(spread: spread, calendar: calendar)
    }
}

@MainActor
private final class MigrationTracker {
    var moveCallCount = 0
}

@MainActor
private struct TrackingTaskMigrationCoordinator: TaskMigrationCoordinator {
    let tracker: MigrationTracker
    let resultTasks: [DataModel.Task]

    func moveTask(
        _ task: DataModel.Task,
        from sourceKey: TaskReviewSourceKey,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskListMutationResult {
        tracker.moveCallCount += 1
        return TaskListMutationResult(
            task: task,
            tasks: resultTasks,
            mutation: JournalMutationResult(kind: .taskChanged(id: task.id), scope: .structural)
        )
    }

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult {
        TaskBatchMigrationResult(tasks: resultTasks, migratedTasks: resultTasks, migratedAny: true)
    }
}

@MainActor
private final class DeletionTracker {
    var deleteCallCount = 0
}

@MainActor
private struct TrackingSpreadDeletionCoordinator: SpreadDeletionCoordinator {
    let tracker: DeletionTracker
    let result: SpreadDeletionResult

    func deleteSpread(
        _ spread: DataModel.Spread,
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note]
    ) async throws -> SpreadDeletionResult {
        tracker.deleteCallCount += 1
        return result
    }
}
