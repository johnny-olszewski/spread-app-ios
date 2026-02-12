import Foundation
#if DEBUG
import Testing
@testable import Spread

/// Tests for mock data set functionality.
///
/// Verifies that:
/// - MockDataSet enum has all required cases
/// - Each data set generates appropriate data
/// - Data sets are correctly described for UI
/// - DebugDataService correctly loads and clears data
@Suite("Mock Data Set Tests")
struct MockDataSetTests {

    // MARK: - MockDataSet Cases

    /// Verifies that all required data set cases exist.
    ///
    /// Setup: MockDataSet enum
    /// Expected: Cases for empty, baseline, multiday, boundary, and high-volume
    @Test("All required data set cases exist")
    func allRequiredCasesExist() {
        let allCases = MockDataSet.allCases
        #expect(allCases.contains(.empty))
        #expect(allCases.contains(.baseline))
        #expect(allCases.contains(.multiday))
        #expect(allCases.contains(.boundary))
        #expect(allCases.contains(.highVolume))
    }

    // MARK: - Display Properties

    /// Verifies that empty data set has correct display name.
    ///
    /// Setup: MockDataSet.empty
    /// Expected: Display name is "Empty"
    @Test("Empty data set has correct display name")
    func emptyDisplayName() {
        #expect(MockDataSet.empty.displayName == "Empty")
    }

    /// Verifies that baseline data set has correct display name.
    ///
    /// Setup: MockDataSet.baseline
    /// Expected: Display name is "Baseline"
    @Test("Baseline data set has correct display name")
    func baselineDisplayName() {
        #expect(MockDataSet.baseline.displayName == "Baseline")
    }

    /// Verifies that multiday data set has correct display name.
    ///
    /// Setup: MockDataSet.multiday
    /// Expected: Display name is "Multiday Ranges"
    @Test("Multiday data set has correct display name")
    func multidayDisplayName() {
        #expect(MockDataSet.multiday.displayName == "Multiday Ranges")
    }

    /// Verifies that boundary data set has correct display name.
    ///
    /// Setup: MockDataSet.boundary
    /// Expected: Display name is "Boundary Dates"
    @Test("Boundary data set has correct display name")
    func boundaryDisplayName() {
        #expect(MockDataSet.boundary.displayName == "Boundary Dates")
    }

    /// Verifies that high-volume data set has correct display name.
    ///
    /// Setup: MockDataSet.highVolume
    /// Expected: Display name is "High Volume"
    @Test("High volume data set has correct display name")
    func highVolumeDisplayName() {
        #expect(MockDataSet.highVolume.displayName == "High Volume")
    }

    /// Verifies that all data sets have descriptions.
    ///
    /// Setup: All MockDataSet cases
    /// Expected: Each case has a non-empty description
    @Test("All data sets have descriptions")
    func allDataSetsHaveDescriptions() {
        for dataSet in MockDataSet.allCases {
            #expect(!dataSet.description.isEmpty, "Data set \(dataSet) should have a description")
        }
    }

    // MARK: - Empty Data Set

    /// Verifies that empty data set generates no spreads.
    ///
    /// Setup: MockDataSet.empty, test calendar and date
    /// Expected: Empty array of spreads
    @Test("Empty data set generates no spreads")
    func emptyGeneratesNoSpreads() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.empty.generateData(calendar: calendar, today: today)
        #expect(data.spreads.isEmpty)
    }

    /// Verifies that empty data set generates no tasks.
    ///
    /// Setup: MockDataSet.empty, test calendar and date
    /// Expected: Empty array of tasks
    @Test("Empty data set generates no tasks")
    func emptyGeneratesNoTasks() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.empty.generateData(calendar: calendar, today: today)
        #expect(data.tasks.isEmpty)
    }

    /// Verifies that empty data set generates no events.
    ///
    /// Setup: MockDataSet.empty, test calendar and date
    /// Expected: Empty array of events
    @Test("Empty data set generates no events")
    func emptyGeneratesNoEvents() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.empty.generateData(calendar: calendar, today: today)
        #expect(data.events.isEmpty)
    }

    /// Verifies that empty data set generates no notes.
    ///
    /// Setup: MockDataSet.empty, test calendar and date
    /// Expected: Empty array of notes
    @Test("Empty data set generates no notes")
    func emptyGeneratesNoNotes() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.empty.generateData(calendar: calendar, today: today)
        #expect(data.notes.isEmpty)
    }

    // MARK: - Baseline Data Set

    /// Verifies that baseline data set generates year, month, and day spreads for today.
    ///
    /// Setup: MockDataSet.baseline with today = Jan 15, 2026
    /// Expected: At least one year, month, and day spread
    @Test("Baseline generates year, month, and day spreads for today")
    func baselineGeneratesSpreadsForToday() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.baseline.generateData(calendar: calendar, today: today)

        let hasYear = data.spreads.contains { $0.period == .year }
        let hasMonth = data.spreads.contains { $0.period == .month }
        let hasDay = data.spreads.contains { $0.period == .day }

        #expect(hasYear, "Baseline should include a year spread")
        #expect(hasMonth, "Baseline should include a month spread")
        #expect(hasDay, "Baseline should include a day spread")
    }

    /// Verifies that baseline data set generates sample tasks.
    ///
    /// Setup: MockDataSet.baseline
    /// Expected: At least one task
    @Test("Baseline generates sample tasks")
    func baselineGeneratesTasks() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.baseline.generateData(calendar: calendar, today: today)
        #expect(!data.tasks.isEmpty, "Baseline should generate tasks")
    }

    // MARK: - Multiday Data Set

    /// Verifies that multiday data set generates multiday spreads.
    ///
    /// Setup: MockDataSet.multiday
    /// Expected: At least one multiday spread
    @Test("Multiday generates multiday spreads")
    func multidayGeneratesMultidaySpreads() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.multiday.generateData(calendar: calendar, today: today)

        let hasMultiday = data.spreads.contains { $0.period == .multiday }
        #expect(hasMultiday, "Multiday should include multiday spreads")
    }

    /// Verifies that multiday data set includes both preset-based and custom ranges.
    ///
    /// Setup: MockDataSet.multiday
    /// Expected: At least 2 multiday spreads (preset and custom)
    @Test("Multiday includes preset-based and custom ranges")
    func multidayIncludesPresetAndCustom() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.multiday.generateData(calendar: calendar, today: today)

        let multidaySpreads = data.spreads.filter { $0.period == .multiday }
        #expect(multidaySpreads.count >= 2, "Multiday should include at least 2 multiday spreads")
    }

    // MARK: - Boundary Data Set

    /// Verifies that boundary data set includes spreads across month boundary.
    ///
    /// Setup: MockDataSet.boundary
    /// Expected: Spreads include dates at month transitions
    @Test("Boundary includes month transition dates")
    func boundaryIncludesMonthTransition() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.boundary.generateData(calendar: calendar, today: today)

        // Should have spreads in at least 2 different months
        let months = Set(data.spreads.compactMap { spread -> Int? in
            guard spread.period == .month || spread.period == .day else { return nil }
            return calendar.component(.month, from: spread.date)
        })
        #expect(months.count >= 2, "Boundary should include spreads in different months")
    }

    /// Verifies that boundary data set includes spreads across year boundary.
    ///
    /// Setup: MockDataSet.boundary
    /// Expected: Spreads include dates at year transitions
    @Test("Boundary includes year transition dates")
    func boundaryIncludesYearTransition() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.boundary.generateData(calendar: calendar, today: today)

        // Should have spreads in at least 2 different years
        let years = Set(data.spreads.map { calendar.component(.year, from: $0.date) })
        #expect(years.count >= 2, "Boundary should include spreads in different years")
    }

    // MARK: - High Volume Data Set

    /// Verifies that high-volume data set generates many spreads.
    ///
    /// Setup: MockDataSet.highVolume
    /// Expected: At least 50 spreads for performance testing
    @Test("High volume generates many spreads")
    func highVolumeGeneratesManySpreads() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.highVolume.generateData(calendar: calendar, today: today)
        #expect(data.spreads.count >= 50, "High volume should generate at least 50 spreads")
    }

    /// Verifies that high-volume data set generates many tasks.
    ///
    /// Setup: MockDataSet.highVolume
    /// Expected: At least 100 tasks for performance testing
    @Test("High volume generates many tasks")
    func highVolumeGeneratesManyTasks() {
        let calendar = makeTestCalendar()
        let today = makeTestDate(year: 2026, month: 1, day: 15, calendar: calendar)
        let data = MockDataSet.highVolume.generateData(calendar: calendar, today: today)
        #expect(data.tasks.count >= 100, "High volume should generate at least 100 tasks")
    }

    // MARK: - Helpers

    private func makeTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    private func makeTestDate(year: Int, month: Int, day: Int, calendar: Calendar) -> Date {
        calendar.date(from: .init(year: year, month: month, day: day))!
    }
}

// MARK: - Debug Data Service Tests

@Suite("Debug Data Service Tests")
struct DebugDataServiceTests {

    /// Verifies that loading empty data set clears all repositories.
    ///
    /// Setup: Repositories with existing data, load empty data set
    /// Expected: All repositories are empty after load
    @Test("Loading empty data set clears all data")
    @MainActor
    func loadingEmptyClears() async throws {
        // Setup repositories with initial data
        let taskRepo = InMemoryTaskRepository(tasks: TestData.sampleTasks())
        let spreadRepo = InMemorySpreadRepository(spreads: TestData.sampleSpreads())
        let eventRepo = InMemoryEventRepository(events: TestData.sampleEvents())
        let noteRepo = InMemoryNoteRepository(notes: TestData.sampleNotes())

        let service = DebugDataService(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            eventRepository: eventRepo,
            noteRepository: noteRepo
        )

        // Verify initial data exists
        let initialTasks = await taskRepo.getTasks()
        #expect(!initialTasks.isEmpty, "Should have initial tasks")

        // Load empty data set
        let calendar = makeTestCalendar()
        let today = Date.now
        try await service.loadDataSet(.empty, calendar: calendar, today: today)

        // Verify all data is cleared
        let tasks = await taskRepo.getTasks()
        let spreads = await spreadRepo.getSpreads()
        let events = await eventRepo.getEvents()
        let notes = await noteRepo.getNotes()

        #expect(tasks.isEmpty, "Tasks should be empty after loading empty data set")
        #expect(spreads.isEmpty, "Spreads should be empty after loading empty data set")
        #expect(events.isEmpty, "Events should be empty after loading empty data set")
        #expect(notes.isEmpty, "Notes should be empty after loading empty data set")
    }

    /// Verifies that loading baseline data set replaces existing data.
    ///
    /// Setup: Repositories with existing data, load baseline data set
    /// Expected: Data is replaced with baseline data
    @Test("Loading baseline data set replaces existing data")
    @MainActor
    func loadingBaselineReplacesData() async throws {
        // Setup repositories with some initial tasks (different from baseline)
        let initialTask = DataModel.Task(title: "Initial task that should be replaced")
        let taskRepo = InMemoryTaskRepository(tasks: [initialTask])
        let spreadRepo = InMemorySpreadRepository()
        let eventRepo = InMemoryEventRepository()
        let noteRepo = InMemoryNoteRepository()

        let service = DebugDataService(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            eventRepository: eventRepo,
            noteRepository: noteRepo
        )

        // Load baseline data set
        let calendar = makeTestCalendar()
        let today = Date.now
        try await service.loadDataSet(.baseline, calendar: calendar, today: today)

        // Verify data is replaced (not appended)
        let tasks = await taskRepo.getTasks()
        let hasInitialTask = tasks.contains { $0.title == "Initial task that should be replaced" }
        #expect(!hasInitialTask, "Initial task should be replaced, not kept")
        #expect(!tasks.isEmpty, "Should have baseline tasks")
    }

    /// Verifies that loading data set triggers reload callback.
    ///
    /// Setup: DebugDataService with reload callback
    /// Expected: Callback is invoked after loading
    @Test("Loading data set triggers reload callback")
    @MainActor
    func loadingTriggersReloadCallback() async throws {
        var reloadCalled = false

        let service = DebugDataService(
            taskRepository: InMemoryTaskRepository(),
            spreadRepository: InMemorySpreadRepository(),
            eventRepository: InMemoryEventRepository(),
            noteRepository: InMemoryNoteRepository(),
            onReload: { reloadCalled = true }
        )

        let calendar = makeTestCalendar()
        let today = Date.now
        try await service.loadDataSet(.baseline, calendar: calendar, today: today)

        #expect(reloadCalled, "Reload callback should be invoked")
    }

    /// Verifies that clear operation removes all data from repositories.
    ///
    /// Setup: Repositories with data
    /// Expected: All repositories are empty after clear
    @Test("Clear operation removes all data")
    @MainActor
    func clearRemovesAllData() async throws {
        let taskRepo = InMemoryTaskRepository(tasks: TestData.sampleTasks())
        let spreadRepo = InMemorySpreadRepository(spreads: TestData.sampleSpreads())
        let eventRepo = InMemoryEventRepository(events: TestData.sampleEvents())
        let noteRepo = InMemoryNoteRepository(notes: TestData.sampleNotes())

        let service = DebugDataService(
            taskRepository: taskRepo,
            spreadRepository: spreadRepo,
            eventRepository: eventRepo,
            noteRepository: noteRepo
        )

        try await service.clearAllData()

        let tasks = await taskRepo.getTasks()
        let spreads = await spreadRepo.getSpreads()
        let events = await eventRepo.getEvents()
        let notes = await noteRepo.getNotes()

        #expect(tasks.isEmpty)
        #expect(spreads.isEmpty)
        #expect(events.isEmpty)
        #expect(notes.isEmpty)
    }

    // MARK: - Helpers

    private func makeTestCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }
}
#endif
