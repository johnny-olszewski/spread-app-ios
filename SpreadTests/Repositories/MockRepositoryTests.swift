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

    // MARK: - InMemoryTaskRepository Tests

    /// Conditions: Save a new task to empty repository.
    /// Expected: Repository should contain exactly one task with matching title.
    @Test func testInMemoryTaskRepositorySaveAddsTask() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Test Task")
    }

    /// Conditions: Save the same task twice.
    /// Expected: Repository should still contain only one task (no duplicates).
    @Test func testInMemoryTaskRepositorySaveIsIdempotent() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
    }

    /// Conditions: Save a task, modify its title, save again.
    /// Expected: Repository should contain one task with the updated title.
    @Test func testInMemoryTaskRepositorySaveUpdatesExisting() async throws {
        let repository = InMemoryTaskRepository()
        let taskId = UUID()
        let task = DataModel.Task(id: taskId, title: "Original")

        try await repository.save(task)
        task.title = "Updated"
        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == 1)
        #expect(tasks.first?.title == "Updated")
    }

    /// Conditions: Save a task, then delete it.
    /// Expected: Repository should be empty after deletion.
    @Test func testInMemoryTaskRepositoryDeleteRemovesTask() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Test Task")

        try await repository.save(task)
        try await repository.delete(task)
        let tasks = await repository.getTasks()

        #expect(tasks.isEmpty)
    }

    /// Conditions: Delete a task that was never saved to the repository.
    /// Expected: Repository should remain empty (no error thrown).
    @Test func testInMemoryTaskRepositoryDeleteNonExistentIsNoOp() async throws {
        let repository = InMemoryTaskRepository()
        let task = DataModel.Task(title: "Non-existent")

        try await repository.delete(task)
        let tasks = await repository.getTasks()

        #expect(tasks.isEmpty)
    }

    /// Conditions: Initialize repository with an array of existing tasks.
    /// Expected: Repository should contain all provided tasks.
    @Test func testInMemoryTaskRepositoryInitializesWithTasks() async {
        let existingTasks = [
            DataModel.Task(title: "Task 1"),
            DataModel.Task(title: "Task 2")
        ]
        let repository = InMemoryTaskRepository(tasks: existingTasks)

        let tasks = await repository.getTasks()

        #expect(tasks.count == 2)
    }

    /// Conditions: Save tasks with different createdDates in random order.
    /// Expected: getTasks should return tasks sorted by createdDate ascending (oldest first).
    @Test func testInMemoryTaskRepositorySortsByDateAscending() async throws {
        let repository = InMemoryTaskRepository()
        let now = Date.now
        let task1 = DataModel.Task(title: "Oldest", createdDate: now.addingTimeInterval(-200))
        let task2 = DataModel.Task(title: "Middle", createdDate: now.addingTimeInterval(-100))
        let task3 = DataModel.Task(title: "Newest", createdDate: now)

        try await repository.save(task3)
        try await repository.save(task1)
        try await repository.save(task2)
        let tasks = await repository.getTasks()

        #expect(tasks[0].title == "Oldest")
        #expect(tasks[1].title == "Middle")
        #expect(tasks[2].title == "Newest")
    }

    // MARK: - InMemorySpreadRepository Tests

    /// Conditions: Save a new spread to empty repository.
    /// Expected: Repository should contain exactly one spread.
    @Test func testInMemorySpreadRepositorySaveAddsSpread() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    /// Conditions: Save the same spread twice.
    /// Expected: Repository should still contain only one spread (no duplicates).
    @Test func testInMemorySpreadRepositorySaveIsIdempotent() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        try await repository.save(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.count == 1)
    }

    /// Conditions: Save a spread, then delete it.
    /// Expected: Repository should be empty after deletion.
    @Test func testInMemorySpreadRepositoryDeleteRemovesSpread() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.save(spread)
        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    /// Conditions: Delete a spread that was never saved to the repository.
    /// Expected: Repository should remain empty (no error thrown).
    @Test func testInMemorySpreadRepositoryDeleteNonExistentIsNoOp() async throws {
        let repository = InMemorySpreadRepository()
        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)

        try await repository.delete(spread)
        let spreads = await repository.getSpreads()

        #expect(spreads.isEmpty)
    }

    /// Conditions: Initialize repository with an array of existing spreads.
    /// Expected: Repository should contain all provided spreads.
    @Test func testInMemorySpreadRepositoryInitializesWithSpreads() async {
        let now = Date.now
        let existingSpreads = [
            DataModel.Spread(period: .year, date: now, calendar: testCalendar),
            DataModel.Spread(period: .month, date: now, calendar: testCalendar)
        ]
        let repository = InMemorySpreadRepository(spreads: existingSpreads)

        let spreads = await repository.getSpreads()

        #expect(spreads.count == 2)
    }

    /// Conditions: Save spreads with different periods and dates in random order.
    /// Expected: getSpreads should return spreads sorted by period (year > month > day), then by date descending.
    @Test func testInMemorySpreadRepositorySortsByPeriodThenDateDescending() async throws {
        let repository = InMemorySpreadRepository()
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

    // MARK: - MockTaskRepository Tests

    /// Conditions: Access tasks from a newly initialized MockTaskRepository.
    /// Expected: Repository should contain pre-populated sample tasks.
    @Test func testMockTaskRepositoryProvidesSampleTasks() async {
        let repository = MockTaskRepository()
        let tasks = await repository.getTasks()

        #expect(!tasks.isEmpty)
    }

    /// Conditions: Save a new task into a mock task repository.
    /// Expected: Task count increases by one.
    @Test func testMockTaskRepositorySupportsSave() async throws {
        let repository = MockTaskRepository()
        let initialCount = await repository.getTasks().count
        let task = DataModel.Task(title: "New Task")

        try await repository.save(task)
        let tasks = await repository.getTasks()

        #expect(tasks.count == initialCount + 1)
    }

    /// Conditions: Delete an existing task from a mock task repository.
    /// Expected: Remaining tasks do not include the deleted task.
    @Test func testMockTaskRepositorySupportsDelete() async throws {
        let repository = MockTaskRepository()
        let tasks = await repository.getTasks()
        guard let taskToDelete = tasks.first else {
            Issue.record("No tasks to delete")
            return
        }

        try await repository.delete(taskToDelete)
        let remainingTasks = await repository.getTasks()

        #expect(!remainingTasks.contains { $0.id == taskToDelete.id })
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

    // MARK: - InMemoryNoteRepository Tests

    /// Conditions: Save a new note to empty repository.
    /// Expected: Repository should contain exactly one note with matching title.
    @Test func testInMemoryNoteRepositorySaveAddsNote() async throws {
        let repository = InMemoryNoteRepository()
        let note = DataModel.Note(title: "Test Note")

        try await repository.save(note)
        let notes = await repository.getNotes()

        #expect(notes.count == 1)
        #expect(notes.first?.title == "Test Note")
    }

    /// Conditions: Initialize repository with an array of existing notes.
    /// Expected: Repository should contain all provided notes.
    @Test func testInMemoryNoteRepositoryInitializesWithNotes() async {
        let existingNotes = [
            DataModel.Note(title: "Note 1"),
            DataModel.Note(title: "Note 2")
        ]
        let repository = InMemoryNoteRepository(notes: existingNotes)

        let notes = await repository.getNotes()

        #expect(notes.count == 2)
    }

    // MARK: - InMemoryEventRepository Tests

    /// Conditions: Save a new event to empty repository.
    /// Expected: Repository should contain exactly one event with matching title.
    @Test func testInMemoryEventRepositorySaveAddsEvent() async throws {
        let repository = InMemoryEventRepository()
        let event = DataModel.Event(title: "Test Event")

        try await repository.save(event)
        let events = await repository.getEvents()

        #expect(events.count == 1)
        #expect(events.first?.title == "Test Event")
    }

    /// Conditions: Initialize repository with an array of existing events.
    /// Expected: Repository should contain all provided events.
    @Test func testInMemoryEventRepositoryInitializesWithEvents() async {
        let existingEvents = [
            DataModel.Event(title: "Event 1"),
            DataModel.Event(title: "Event 2")
        ]
        let repository = InMemoryEventRepository(events: existingEvents)

        let events = await repository.getEvents()

        #expect(events.count == 2)
    }

    // MARK: - MockNoteRepository Tests

    /// Conditions: Access notes from a newly initialized MockNoteRepository.
    /// Expected: Repository should contain pre-populated sample notes.
    @Test func testMockNoteRepositoryProvidesSampleNotes() async {
        let repository = MockNoteRepository()
        let notes = await repository.getNotes()

        #expect(!notes.isEmpty)
    }

    /// Conditions: Save a new note into a mock note repository.
    /// Expected: Note count increases by one.
    @Test func testMockNoteRepositorySupportsSave() async throws {
        let repository = MockNoteRepository()
        let initialCount = await repository.getNotes().count
        let note = DataModel.Note(title: "New Note")

        try await repository.save(note)
        let notes = await repository.getNotes()

        #expect(notes.count == initialCount + 1)
    }

    /// Conditions: Delete an existing note from a mock note repository.
    /// Expected: Remaining notes do not include the deleted note.
    @Test func testMockNoteRepositorySupportsDelete() async throws {
        let repository = MockNoteRepository()
        let notes = await repository.getNotes()
        guard let noteToDelete = notes.first else {
            Issue.record("No notes to delete")
            return
        }

        try await repository.delete(noteToDelete)
        let remainingNotes = await repository.getNotes()

        #expect(!remainingNotes.contains { $0.id == noteToDelete.id })
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
