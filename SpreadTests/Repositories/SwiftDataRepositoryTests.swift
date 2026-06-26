import Foundation
import SwiftData
import Testing
@testable import Spread

/// Integration tests for SwiftData repository implementations.
///
/// Tests CRUD operations using in-memory containers for isolation.
@MainActor
struct SwiftDataRepositoryTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - SpreadRepository Tests

    /// Conditions: Save a spread to an empty SwiftData spread repository.
    /// Expected: Fetching spreads returns one spread with the same id.
    @Test func testSpreadRepositorySaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 1)
        #expect(spreads.first?.id == spread.id)
    }

    /// Conditions: Save a spread with sync enabled.
    /// Expected: An outbox mutation is created with device ID and create operation.
    @Test func testSpreadRepositorySaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        let repository = SwiftDataSpreadRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { Date(timeIntervalSince1970: 500) }
        )

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        let mutation = try fetchMutations(from: container).first

        #expect(mutation != nil)
        #expect(mutation?.entityType == SyncEntityType.spread.rawValue)
        #expect(mutation?.operation == SyncOperation.create.rawValue)

        let record = try decodeRecord(mutation?.recordData)
        #expect(record?["device_id"] as? String == deviceId.uuidString)
    }

    /// Conditions: Save three spreads to the repository.
    /// Expected: Fetching spreads returns three spreads.
    @Test func testSpreadRepositorySaveMultipleSpreads() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let now = Date.now
        let spread1 = DataModel.Spread(period: .year, date: now, calendar: testCalendar)
        let spread2 = DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        let spread3 = DataModel.Spread(period: .day, date: now, calendar: testCalendar)

        try await repository.save(spread1)
        try await repository.save(spread2)
        try await repository.save(spread3)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 3)
    }

    /// Conditions: Save a spread, then delete it.
    /// Expected: Fetching spreads returns an empty list.
    @Test func testSpreadRepositoryDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)

        var spreads = await repository.getSpreads()
        #expect(spreads.count == 1)

        try await repository.delete(spread)

        spreads = await repository.getSpreads()
        #expect(spreads.count == 0)
    }

    /// Conditions: Save a spread, then delete it.
    /// Expected: A delete mutation is enqueued with deleted_at set.
    @Test func testSpreadRepositoryDeleteEnqueuesDeleteMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let deviceId = UUID()
        var timestamps = [
            Date(timeIntervalSince1970: 600),
            Date(timeIntervalSince1970: 700)
        ]
        let repository = SwiftDataSpreadRepository(
            modelContainer: container,
            deviceId: deviceId,
            nowProvider: { timestamps.removeFirst() }
        )

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        try await repository.save(spread)
        try await repository.delete(spread)

        let mutations = try fetchMutations(from: container)
        let deleteMutation = mutations.last(where: { $0.operation == SyncOperation.delete.rawValue })

        #expect(deleteMutation != nil)

        let record = try decodeRecord(deleteMutation?.recordData)
        let deletedAt = record?["deleted_at"] as? String
        #expect(deletedAt == SyncDateFormatting.formatTimestamp(Date(timeIntervalSince1970: 700)))
    }

    /// Conditions: Save spreads of different periods and dates in random order.
    /// Expected: Fetching spreads returns period order (year, month, day), then date descending.
    @Test func testSpreadRepositoryReturnsSortedByPeriodThenDateDescending() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repository = SwiftDataSpreadRepository(modelContainer: container)

        let now = Date.now
        // Create spreads of different periods
        let daySpread1 = DataModel.Spread(period: .day, date: now, calendar: testCalendar)
        let daySpread2 = DataModel.Spread(
            period: .day,
            date: now.addingTimeInterval(-86400),
            calendar: testCalendar
        )
        let monthSpread = DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        let yearSpread = DataModel.Spread(period: .year, date: now, calendar: testCalendar)

        // Save in random order
        try await repository.save(daySpread2)
        try await repository.save(monthSpread)
        try await repository.save(daySpread1)
        try await repository.save(yearSpread)

        let spreads = await repository.getSpreads()
        #expect(spreads.count == 4)
        // Sorted by period (year > month > day), then by date descending
        #expect(spreads[0].period == .year)
        #expect(spreads[1].period == .month)
        #expect(spreads[2].period == .day)
        #expect(spreads[3].period == .day)
        // Same period: should be sorted by date descending
        #expect(spreads[2].date > spreads[3].date)
    }

    // MARK: - Repository Isolation Tests

    /// Conditions: Save a task in a repository backed by one container and read from another.
    /// Expected: First repository has the task, second repository is empty.
    @Test func testRepositoriesUseIsolatedContainers() async throws {
        let container1 = try ModelContainerFactory.makeInMemory()
        let container2 = try ModelContainerFactory.makeInMemory()

        let taskRepo1 = SwiftDataChangeAwareTaskRepository(modelContainer: container1)
        let taskRepo2 = SwiftDataChangeAwareTaskRepository(modelContainer: container2)

        let task = DataModel.Task(title: "Container 1 Task")
        try await taskRepo1.save(task, change: EntityChange())

        let tasks1 = await taskRepo1.getTasks()
        let tasks2 = await taskRepo2.getTasks()

        #expect(tasks1.count == 1)
        #expect(tasks2.count == 0)
    }

    // MARK: - Sync Outbox Helpers

    private func fetchMutations(from container: ModelContainer) throws -> [DataModel.SyncMutation] {
        let descriptor = FetchDescriptor<DataModel.SyncMutation>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )
        return try container.mainContext.fetch(descriptor)
    }

    private func decodeRecord(_ data: Data?) throws -> [String: Any]? {
        guard let data else { return nil }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
