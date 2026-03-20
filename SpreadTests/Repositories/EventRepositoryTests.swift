import Testing
import Foundation
@testable import Spread

/// Tests for event repository CRUD operations.
///
/// Validates InMemoryEventRepository against the EventRepository protocol contract.
/// SwiftData tests will be added when SwiftDataEventRepository is implemented (SPRD-57).
@Suite("Event Repository Tests")
struct EventRepositoryTests {

    // MARK: - InMemory CRUD

    /// Conditions: Save an event to an empty InMemory repository.
    /// Expected: getEvents returns one event with the correct title.
    @Test @MainActor func testInMemorySaveAndRetrieve() async throws {
        let repo = InMemoryEventRepository()
        let event = DataModel.Event(title: "Team standup")

        try await repo.save(event)
        let result = await repo.getEvents()

        #expect(result.count == 1)
        #expect(result[0].id == event.id)
        #expect(result[0].title == "Team standup")
    }

    /// Conditions: Save the same event twice.
    /// Expected: Repository contains only one event (no duplicates).
    @Test @MainActor func testInMemorySaveIsIdempotent() async throws {
        let repo = InMemoryEventRepository()
        let event = DataModel.Event(title: "Test Event")

        try await repo.save(event)
        try await repo.save(event)
        let result = await repo.getEvents()

        #expect(result.count == 1)
    }

    /// Conditions: Save an event, modify its title, save again.
    /// Expected: Repository contains one event with the updated title.
    @Test @MainActor func testInMemoryUpdate() async throws {
        let repo = InMemoryEventRepository()
        let event = DataModel.Event(title: "Original")

        try await repo.save(event)
        event.title = "Updated"
        try await repo.save(event)

        let result = await repo.getEvents()
        #expect(result.count == 1)
        #expect(result[0].title == "Updated")
    }

    /// Conditions: Save an event, then delete it.
    /// Expected: getEvents returns an empty array.
    @Test @MainActor func testInMemoryDelete() async throws {
        let repo = InMemoryEventRepository()
        let event = DataModel.Event(title: "To Delete")

        try await repo.save(event)
        try await repo.delete(event)

        let result = await repo.getEvents()
        #expect(result.isEmpty)
    }

    /// Conditions: Delete an event that was never saved.
    /// Expected: Repository remains empty (no error thrown).
    @Test @MainActor func testInMemoryDeleteNonExistentIsNoOp() async throws {
        let repo = InMemoryEventRepository()
        let event = DataModel.Event(title: "Non-existent")

        try await repo.delete(event)
        let result = await repo.getEvents()

        #expect(result.isEmpty)
    }

    /// Conditions: Create InMemory repository with pre-populated events.
    /// Expected: getEvents returns the pre-populated events.
    @Test @MainActor func testInMemoryPrePopulated() async {
        let events = [
            DataModel.Event(title: "A", createdDate: .now.addingTimeInterval(-100)),
            DataModel.Event(title: "B", createdDate: .now)
        ]
        let repo = InMemoryEventRepository(events: events)

        let result = await repo.getEvents()
        #expect(result.count == 2)
        #expect(result[0].title == "A")
        #expect(result[1].title == "B")
    }

    /// Conditions: Empty InMemory repository.
    /// Expected: getEvents returns an empty array.
    @Test @MainActor func testInMemoryEmptyRepository() async {
        let repo = InMemoryEventRepository()
        let result = await repo.getEvents()
        #expect(result.isEmpty)
    }

    /// Conditions: Save events with different createdDates in random order.
    /// Expected: getEvents returns them sorted by createdDate ascending.
    @Test @MainActor func testInMemorySortsByDateAscending() async throws {
        let repo = InMemoryEventRepository()
        let now = Date.now
        let event1 = DataModel.Event(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let event2 = DataModel.Event(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let event3 = DataModel.Event(title: "Newest", createdDate: now)

        try await repo.save(event3)
        try await repo.save(event1)
        try await repo.save(event2)
        let result = await repo.getEvents()

        #expect(result[0].title == "Oldest")
        #expect(result[1].title == "Middle")
        #expect(result[2].title == "Newest")
    }

    // MARK: - Date Range Filtering

    /// Conditions: Save events with different date ranges, query with a range that overlaps some.
    /// Expected: getEvents(from:to:) returns only overlapping events, sorted by startDate.
    @Test @MainActor func testGetEventsInDateRange() async throws {
        let repo = InMemoryEventRepository()
        let now = Date.now
        let dayInSeconds: TimeInterval = 86400

        let pastEvent = DataModel.Event(
            title: "Past",
            createdDate: now.addingTimeInterval(-dayInSeconds * 10),
            startDate: now.addingTimeInterval(-dayInSeconds * 10),
            endDate: now.addingTimeInterval(-dayInSeconds * 8)
        )
        let overlappingEvent = DataModel.Event(
            title: "Overlapping",
            createdDate: now.addingTimeInterval(-dayInSeconds * 2),
            startDate: now.addingTimeInterval(-dayInSeconds * 2),
            endDate: now.addingTimeInterval(dayInSeconds * 2)
        )
        let futureEvent = DataModel.Event(
            title: "Future",
            createdDate: now.addingTimeInterval(dayInSeconds * 5),
            startDate: now.addingTimeInterval(dayInSeconds * 5),
            endDate: now.addingTimeInterval(dayInSeconds * 7)
        )

        try await repo.save(pastEvent)
        try await repo.save(overlappingEvent)
        try await repo.save(futureEvent)

        let rangeStart = now.addingTimeInterval(-dayInSeconds)
        let rangeEnd = now.addingTimeInterval(dayInSeconds)
        let result = await repo.getEvents(from: rangeStart, to: rangeEnd)

        #expect(result.count == 1)
        #expect(result[0].title == "Overlapping")
    }

    /// Conditions: Query events with a range that matches no events.
    /// Expected: getEvents(from:to:) returns an empty array.
    @Test @MainActor func testGetEventsInDateRangeReturnsEmptyWhenNoOverlap() async throws {
        let repo = InMemoryEventRepository()
        let now = Date.now
        let dayInSeconds: TimeInterval = 86400

        let event = DataModel.Event(
            title: "Far Future",
            createdDate: now,
            startDate: now.addingTimeInterval(dayInSeconds * 100),
            endDate: now.addingTimeInterval(dayInSeconds * 101)
        )

        try await repo.save(event)

        let result = await repo.getEvents(from: now, to: now.addingTimeInterval(dayInSeconds))
        #expect(result.isEmpty)
    }

    /// Conditions: Save multiple overlapping events, query with a range.
    /// Expected: Results are sorted by startDate ascending.
    @Test @MainActor func testGetEventsInDateRangeSortedByStartDate() async throws {
        let repo = InMemoryEventRepository()
        let now = Date.now
        let dayInSeconds: TimeInterval = 86400

        let laterEvent = DataModel.Event(
            title: "Later",
            createdDate: now,
            startDate: now.addingTimeInterval(dayInSeconds),
            endDate: now.addingTimeInterval(dayInSeconds * 3)
        )
        let earlierEvent = DataModel.Event(
            title: "Earlier",
            createdDate: now,
            startDate: now,
            endDate: now.addingTimeInterval(dayInSeconds * 2)
        )

        try await repo.save(laterEvent)
        try await repo.save(earlierEvent)

        let result = await repo.getEvents(
            from: now.addingTimeInterval(-dayInSeconds),
            to: now.addingTimeInterval(dayInSeconds * 4)
        )

        #expect(result.count == 2)
        #expect(result[0].title == "Earlier")
        #expect(result[1].title == "Later")
    }
}
