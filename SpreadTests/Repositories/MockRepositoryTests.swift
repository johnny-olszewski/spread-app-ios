import Foundation
import Testing
@testable import Spread

/// Tests for mock and in-memory repository implementations.
@MainActor
struct MockRepositoryTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - TestSpreadRepository Tests

    /// Conditions: Save a new spread to empty repository.
    /// Expected: Repository should contain exactly one spread.
    @Test func testTestSpreadRepositorySaveAddsSpread() async throws {
        let repository = TestSpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    /// Conditions: Save the same spread twice.
    /// Expected: Repository should still contain only one spread (no duplicates).
    @Test func testTestSpreadRepositorySaveIsIdempotent() async throws {
        let repository = TestSpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    /// Conditions: Save a spread, then delete it.
    /// Expected: Repository should be empty after deletion.
    @Test func testTestSpreadRepositoryDeleteRemovesSpread() async throws {
        let repository = TestSpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    /// Conditions: Delete a spread that was never saved to the repository.
    /// Expected: Repository should remain empty (no error thrown).
    @Test func testTestSpreadRepositoryDeleteNonExistentIsNoOp() async throws {
        let repository = TestSpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    /// Conditions: Initialize repository with an array of existing spreads.
    /// Expected: Repository should contain all provided spreads.
    @Test func testTestSpreadRepositoryInitializesWithSpreads() async {
        let now = Date.now
        let existingSpreads = [
            DataModel.Spread(period: .year, date: now, calendar: testCalendar),
            DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        ]
        let repository = TestSpreadRepository(spreads: existingSpreads)

        let spreads = await repository.getSpreads()

        #expect(spreads.count == 2)
    }

    /// Conditions: Save spreads with different periods and dates in random order.
    /// Expected: getSpreads should return spreads sorted by period (year > month > day), then by date descending.
    @Test func testTestSpreadRepositorySortsByPeriodThenDateDescending() async throws {
        let repository = TestSpreadRepository()
        let now = Date.now
        let daySpread1 = DataModel.Spread(period: .day, date: now, calendar: testCalendar)
        let daySpread2 = DataModel.Spread(
            period: .day,
            date: now.addingTimeInterval(-86400),
            calendar: testCalendar
        )
        let monthSpread = DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        let yearSpread = DataModel.Spread(period: .year, date: now, calendar: testCalendar)

        try await repository.save(daySpread2)
        try await repository.save(monthSpread)
        try await repository.save(daySpread1)
        try await repository.save(yearSpread)
        let spreads = await repository.getSpreads()

        // Sorted by period (year > month > day), then by date descending
        #expect(spreads[0].period == .year)
        #expect(spreads[1].period == .month)
        #expect(spreads[2].period == .day)
        #expect(spreads[3].period == .day)
        #expect(spreads[2].date > spreads[3].date)
    }

    // MARK: - MockSpreadRepository Tests

    /// Conditions: Access spreads from a newly initialized mock spread repository.
    /// Expected: Repository provides non-empty sample spreads.
    @Test func testMockSpreadRepositoryProvidesSampleSpreads() async {
        let repository = MockSpreadRepository()
        let spreads = await repository.getSpreads()

        #expect(!spreads.isEmpty)
    }

    /// Conditions: Save a new spread into a mock spread repository.
    /// Expected: Spread count increases by one.
    @Test func testMockSpreadRepositorySupportsSave() async throws {
        let repository = MockSpreadRepository()
        let initialCount = await repository.getSpreads().count
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == initialCount + 1)
    }

    /// Conditions: Delete an existing spread from a mock spread repository.
    /// Expected: Remaining spreads do not include the deleted spread.
    @Test func testMockSpreadRepositorySupportsDelete() async throws {
        let repository = MockSpreadRepository()
        let spreads = await repository.getSpreads()
        guard let spreadToDelete = spreads.first else {
            Issue.record("No spreads to delete")
            return
        }

        try await repository.delete(spreadToDelete)
        let remainingSpreads = await repository.getSpreads()

        #expect(!remainingSpreads.contains { $0.id == spreadToDelete.id })
    }

    // MARK: - TestEventRepository Tests

    /// Conditions: Save a new event to empty repository.
    /// Expected: Repository should contain exactly one event with matching title.
    @Test func testTestEventRepositorySaveAddsEvent() async throws {
        let repository = TestEventRepository()
        let event = DataModel.Event(title: "Test Event")

        try await repository.save(event)
        let events = await repository.getEvents()

        #expect(events.count == 1)
        #expect(events.first?.title == "Test Event")
    }

    /// Conditions: Initialize repository with an array of existing events.
    /// Expected: Repository should contain all provided events.
    @Test func testTestEventRepositoryInitializesWithEvents() async {
        let existingEvents = [
            DataModel.Event(title: "Event 1"),
            DataModel.Event(title: "Event 2")
        ]
        let repository = TestEventRepository(events: existingEvents)

        let events = await repository.getEvents()

        #expect(events.count == 2)
    }

    // MARK: - TestData Tests

    /// Conditions: Generate sample tasks from TestData.
    /// Expected: Tasks are non-empty and include non-empty titles.
    @Test func testTestDataGeneratesSampleTasks() {
        let tasks = TestData.sampleTasks()

        #expect(!tasks.isEmpty)
        #expect(tasks.allSatisfy { !$0.title.isEmpty })
    }

    /// Conditions: Generate sample spreads from TestData.
    /// Expected: Spreads list is non-empty.
    @Test func testTestDataGeneratesSampleSpreads() {
        let spreads = TestData.sampleSpreads()

        #expect(!spreads.isEmpty)
    }

    /// Conditions: Generate sample events from TestData.
    /// Expected: Events are non-empty and include non-empty titles.
    @Test func testTestDataGeneratesSampleEvents() {
        let events = TestData.sampleEvents()

        #expect(!events.isEmpty)
        #expect(events.allSatisfy { !$0.title.isEmpty })
    }

    /// Conditions: Generate sample notes from TestData.
    /// Expected: Notes are non-empty and include non-empty titles.
    @Test func testTestDataGeneratesSampleNotes() {
        let notes = TestData.sampleNotes()

        #expect(!notes.isEmpty)
        #expect(notes.allSatisfy { !$0.title.isEmpty })
    }

    /// Conditions: Generate sample collections from TestData.
    /// Expected: Collections are non-empty and include non-empty titles.
    @Test func testTestDataGeneratesSampleCollections() {
        let collections = TestData.sampleCollections()

        #expect(!collections.isEmpty)
        #expect(collections.allSatisfy { !$0.title.isEmpty })
    }

    /// Conditions: Generate sample tasks from TestData.
    /// Expected: Each task has a unique id.
    @Test func testTestDataTasksHaveUniqueIds() {
        let tasks = TestData.sampleTasks()
        let ids = Set(tasks.map(\.id))

        #expect(ids.count == tasks.count)
    }

    /// Conditions: Generate sample spreads from TestData.
    /// Expected: Each spread has a unique id.
    @Test func testTestDataSpreadsHaveUniqueIds() {
        let spreads = TestData.sampleSpreads()
        let ids = Set(spreads.map(\.id))

        #expect(ids.count == spreads.count)
    }

    /// Conditions: Generate sample events from TestData.
    /// Expected: Each event has a unique id.
    @Test func testTestDataEventsHaveUniqueIds() {
        let events = TestData.sampleEvents()
        let ids = Set(events.map(\.id))

        #expect(ids.count == events.count)
    }

    /// Conditions: Generate sample notes from TestData.
    /// Expected: Each note has a unique id.
    @Test func testTestDataNotesHaveUniqueIds() {
        let notes = TestData.sampleNotes()
        let ids = Set(notes.map(\.id))

        #expect(ids.count == notes.count)
    }

    /// Conditions: Generate sample collections from TestData.
    /// Expected: Each collection has a unique id.
    @Test func testTestDataCollectionsHaveUniqueIds() {
        let collections = TestData.sampleCollections()
        let ids = Set(collections.map(\.id))

        #expect(ids.count == collections.count)
    }
}
