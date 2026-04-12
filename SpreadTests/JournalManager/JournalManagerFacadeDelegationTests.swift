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

    @Test func reloadUsesInjectedConventionalBuilder() async throws {
        let spread = DataModel.Spread(period: .day, date: Self.today, calendar: Self.calendar)
        let expected = SpreadDataModel(spread: spread)
        let tracker = BuilderTracker()
        let builder = TrackingJournalDataModelBuilder(
            tracker: tracker,
            model: [.day: [Period.day.normalizeDate(Self.today, calendar: Self.calendar): expected]]
        )

        let manager = JournalManager(
            calendar: Self.calendar,
            today: Self.today,
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
            calendar: Self.calendar,
            today: Self.today,
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
            calendar: Self.calendar,
            today: Self.today,
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

    func buildDataModel(
        spreads: [DataModel.Spread],
        tasks: [DataModel.Task],
        notes: [DataModel.Note],
        events: [DataModel.Event]
    ) -> JournalDataModel {
        tracker.buildCallCount += 1
        return model
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
    ) async throws -> [DataModel.Task] {
        tracker.moveCallCount += 1
        return resultTasks
    }

    func migrateTasksBatch(
        _ tasks: [DataModel.Task],
        from source: DataModel.Spread,
        to destination: DataModel.Spread,
        calendar: Calendar
    ) async throws -> TaskBatchMigrationResult {
        TaskBatchMigrationResult(tasks: resultTasks, migratedAny: true)
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
