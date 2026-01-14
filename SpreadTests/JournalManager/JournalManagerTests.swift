import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.UUID
import Testing
@testable import Spread

struct JournalManagerTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private static var testDate: Date {
        testCalendar.date(from: .init(year: 2026, month: 1, day: 15))!
    }

    // MARK: - Initialization Tests

    @Test @MainActor func testInitializesWithMockRepositories() async throws {
        let manager = try await JournalManager.makeForTesting()

        #expect(manager.calendar.identifier == .gregorian)
    }

    @Test @MainActor func testInitializesWithCustomCalendar() async throws {
        var calendar = Calendar(identifier: .japanese)
        calendar.timeZone = .init(identifier: "UTC")!

        let manager = try await JournalManager.makeForTesting(calendar: calendar)

        #expect(manager.calendar.identifier == .japanese)
    }

    @Test @MainActor func testInitializesWithCustomToday() async throws {
        let today = Self.testDate

        let manager = try await JournalManager.makeForTesting(today: today)

        #expect(manager.today == today)
    }

    @Test @MainActor func testInitializesWithDefaultBujoMode() async throws {
        let manager = try await JournalManager.makeForTesting()

        #expect(manager.bujoMode == .conventional)
    }

    @Test @MainActor func testInitializesWithCustomBujoMode() async throws {
        let manager = try await JournalManager.makeForTesting(bujoMode: .traditional)

        #expect(manager.bujoMode == .traditional)
    }

    // MARK: - Data Loading Tests

    @Test @MainActor func testLoadsSpreadsFromRepository() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            period: .month,
            date: Self.testDate,
            calendar: calendar
        )
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            spreadRepository: spreadRepo
        )

        #expect(manager.spreads.count == 1)
        #expect(manager.spreads.first?.id == spread.id)
    }

    @Test @MainActor func testLoadsTasksFromRepository() async throws {
        let task = DataModel.Task(title: "Test Task")
        let taskRepo = InMemoryTaskRepository(tasks: [task])

        let manager = try await JournalManager.makeForTesting(taskRepository: taskRepo)

        #expect(manager.tasks.count == 1)
        #expect(manager.tasks.first?.id == task.id)
    }

    @Test @MainActor func testLoadsEventsFromRepository() async throws {
        let event = DataModel.Event(title: "Test Event")
        let eventRepo = InMemoryEventRepository(events: [event])

        let manager = try await JournalManager.makeForTesting(eventRepository: eventRepo)

        #expect(manager.events.count == 1)
        #expect(manager.events.first?.id == event.id)
    }

    @Test @MainActor func testLoadsNotesFromRepository() async throws {
        let note = DataModel.Note(title: "Test Note")
        let noteRepo = InMemoryNoteRepository(notes: [note])

        let manager = try await JournalManager.makeForTesting(noteRepository: noteRepo)

        #expect(manager.notes.count == 1)
        #expect(manager.notes.first?.id == note.id)
    }

    // MARK: - Data Model Organization Tests

    @Test @MainActor func testBuildsDataModelWithSpreadsOrganizedByPeriodAndDate() async throws {
        let calendar = Self.testCalendar
        let yearSpread = DataModel.Spread(
            period: .year,
            date: Self.testDate,
            calendar: calendar
        )
        let monthSpread = DataModel.Spread(
            period: .month,
            date: Self.testDate,
            calendar: calendar
        )
        let spreadRepo = InMemorySpreadRepository(spreads: [yearSpread, monthSpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            spreadRepository: spreadRepo
        )

        #expect(manager.dataModel[.year] != nil)
        #expect(manager.dataModel[.month] != nil)
    }

    @Test @MainActor func testDataModelContainsSpreadDataModels() async throws {
        let calendar = Self.testCalendar
        let spread = DataModel.Spread(
            period: .month,
            date: Self.testDate,
            calendar: calendar
        )
        let spreadRepo = InMemorySpreadRepository(spreads: [spread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            spreadRepository: spreadRepo
        )

        let normalizedDate = Period.month.normalizeDate(Self.testDate, calendar: calendar)
        let spreadData = manager.dataModel[.month]?[normalizedDate]

        #expect(spreadData != nil)
        #expect(spreadData?.spread.id == spread.id)
    }

    @Test @MainActor func testMultidaySpreadAggregatesTasksByDateRange() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )
        let inRangeTask = DataModel.Task(
            title: "In Range",
            date: Self.testDate,
            period: .day
        )
        let outOfRangeDate = calendar.date(from: .init(year: 2026, month: 1, day: 25))!
        let outOfRangeTask = DataModel.Task(
            title: "Out of Range",
            date: outOfRangeDate,
            period: .day
        )
        let taskRepo = InMemoryTaskRepository(tasks: [inRangeTask, outOfRangeTask])
        let spreadRepo = InMemorySpreadRepository(spreads: [multidaySpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            taskRepository: taskRepo,
            spreadRepository: spreadRepo
        )

        let spreadData = manager.dataModel[.multiday]?[multidaySpread.date]

        #expect(spreadData?.tasks.count == 1)
        #expect(spreadData?.tasks.first?.id == inRangeTask.id)
    }

    @Test @MainActor func testMultidaySpreadAggregatesNotesByDateRange() async throws {
        let calendar = Self.testCalendar
        let startDate = calendar.date(from: .init(year: 2026, month: 1, day: 13))!
        let endDate = calendar.date(from: .init(year: 2026, month: 1, day: 19))!
        let multidaySpread = DataModel.Spread(
            startDate: startDate,
            endDate: endDate,
            calendar: calendar
        )
        let inRangeNote = DataModel.Note(
            title: "In Range",
            date: Self.testDate,
            period: .day
        )
        let outOfRangeDate = calendar.date(from: .init(year: 2026, month: 1, day: 25))!
        let outOfRangeNote = DataModel.Note(
            title: "Out of Range",
            date: outOfRangeDate,
            period: .day
        )
        let noteRepo = InMemoryNoteRepository(notes: [inRangeNote, outOfRangeNote])
        let spreadRepo = InMemorySpreadRepository(spreads: [multidaySpread])

        let manager = try await JournalManager.makeForTesting(
            calendar: calendar,
            noteRepository: noteRepo,
            spreadRepository: spreadRepo
        )

        let spreadData = manager.dataModel[.multiday]?[multidaySpread.date]

        #expect(spreadData?.notes.count == 1)
        #expect(spreadData?.notes.first?.id == inRangeNote.id)
    }

    // MARK: - Data Version Tests

    @Test @MainActor func testDataVersionStartsAtZero() async throws {
        let manager = try await JournalManager.makeForTesting()

        #expect(manager.dataVersion == 0)
    }

    @Test @MainActor func testDataVersionIncrementsOnReload() async throws {
        let manager = try await JournalManager.makeForTesting()
        let initialVersion = manager.dataVersion

        await manager.reload()

        #expect(manager.dataVersion == initialVersion + 1)
    }

    // MARK: - BujoMode Tests

    @Test @MainActor func testBujoModeCanBeChanged() async throws {
        let manager = try await JournalManager.makeForTesting(bujoMode: .conventional)

        manager.bujoMode = .traditional

        #expect(manager.bujoMode == .traditional)
    }

    // MARK: - Empty State Tests

    @Test @MainActor func testHandlesEmptyRepositories() async throws {
        let manager = try await JournalManager.makeForTesting()

        #expect(manager.spreads.isEmpty)
        #expect(manager.tasks.isEmpty)
        #expect(manager.events.isEmpty)
        #expect(manager.notes.isEmpty)
        #expect(manager.dataModel.isEmpty)
    }
}
