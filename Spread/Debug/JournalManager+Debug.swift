#if DEBUG
import struct Foundation.Calendar
import struct Foundation.Date

/// Debug-only extension for JournalManager.
///
/// Provides methods for loading and clearing mock data sets, used by the Debug menu.
/// These methods route through JournalManager to ensure UI state stays synchronized.
extension JournalManager {

    // MARK: - Mock Data Loading

    /// Loads a mock data set, replacing all existing data.
    ///
    /// This operation:
    /// 1. Clears all existing spreads, tasks, events, and notes
    /// 2. Generates and saves the new mock data
    /// 3. Reloads the in-memory state to match repositories
    /// 4. Triggers a UI refresh
    ///
    /// - Parameter dataSet: The mock data set to load.
    /// - Throws: Repository errors if persistence fails.
    func loadMockDataSet(_ dataSet: MockDataSet) async throws {
        // Clear existing data first
        try await clearAllDataFromRepositories()
        await reload()

        // Generate the mock data
        let generatedData = dataSet.generateData(calendar: calendar, today: today)

        // Create spreads first (entries need spreads for assignments)
        for spread in generatedData.spreads {
            try await addMockSpread(spread)
        }

        // Create tasks and notes using shared JournalManager logic
        for task in generatedData.tasks {
            try await addTask(
                title: task.title,
                date: task.date,
                period: task.period,
                status: task.status,
                reloadAfter: false
            )
        }

        for event in generatedData.events {
            try await addEvent(
                title: event.title,
                timing: event.timing,
                startDate: event.startDate,
                endDate: event.endDate,
                startTime: event.startTime,
                endTime: event.endTime,
                reloadAfter: false
            )
        }

        for note in generatedData.notes {
            try await addNote(
                title: note.title,
                content: note.content,
                date: note.date,
                period: note.period,
                reloadAfter: false
            )
        }

        // Reload in-memory state from repositories to ensure UI sync
        await reload()
    }

    // MARK: - Entry Creation

    /// Adds a new task with automatic assignment to the best matching spread.
    ///
    /// If a spread exists that matches the task's preferred period and date,
    /// the task will be assigned to it. Otherwise, it goes to the Inbox.
    ///
    /// - Parameters:
    ///   - title: The task title.
    ///   - date: The preferred date for the task.
    ///   - period: The preferred period for the task.
    ///   - status: The initial task status (defaults to `.open`).
    /// - Returns: The created task.
    /// - Throws: Repository errors if persistence fails.
    @discardableResult
    func addTask(
        title: String,
        date: Date,
        period: Period,
        status: DataModel.Task.Status = .open,
        reloadAfter: Bool = true
    ) async throws -> DataModel.Task {
        let task = DataModel.Task(
            title: title,
            date: date,
            period: period,
            status: status,
            assignments: []
        )

        // Find best spread for assignment
        let spreadService = ConventionalSpreadService(calendar: calendar)
        if let bestSpread = spreadService.findBestSpread(for: task, in: spreads) {
            let normalizedDate = bestSpread.period.normalizeDate(bestSpread.date, calendar: calendar)
            let assignment = TaskAssignment(
                period: bestSpread.period,
                date: normalizedDate,
                status: status == .complete ? .complete : .open
            )
            task.assignments.append(assignment)
        }

        // Persist and reload state
        try await taskRepository.save(task)
        if reloadAfter {
            await reload()
        }

        return task
    }

    /// Adds a new event.
    ///
    /// Events have computed visibility based on date range overlap with spreads,
    /// so no assignment is created.
    ///
    /// - Parameters:
    ///   - title: The event title.
    ///   - timing: The event timing mode.
    ///   - startDate: The event start date.
    ///   - endDate: The event end date.
    ///   - startTime: Optional start time (for timed events).
    ///   - endTime: Optional end time (for timed events).
    /// - Returns: The created event.
    /// - Throws: Repository errors if persistence fails.
    @discardableResult
    func addEvent(
        title: String,
        timing: EventTiming,
        startDate: Date,
        endDate: Date,
        startTime: Date? = nil,
        endTime: Date? = nil,
        reloadAfter: Bool = true
    ) async throws -> DataModel.Event {
        let event = DataModel.Event(
            title: title,
            timing: timing,
            startDate: startDate,
            endDate: endDate,
            startTime: startTime,
            endTime: endTime
        )

        // Persist and reload state
        try await eventRepository.save(event)
        if reloadAfter {
            await reload()
        }

        return event
    }

    /// Adds a new note with automatic assignment to the best matching spread.
    ///
    /// If a spread exists that matches the note's preferred period and date,
    /// the note will be assigned to it. Otherwise, it goes to the Inbox.
    ///
    /// - Parameters:
    ///   - title: The note title.
    ///   - content: The note content (defaults to empty).
    ///   - date: The preferred date for the note.
    ///   - period: The preferred period for the note.
    /// - Returns: The created note.
    /// - Throws: Repository errors if persistence fails.
    @discardableResult
    func addNote(
        title: String,
        content: String = "",
        date: Date,
        period: Period,
        reloadAfter: Bool = true
    ) async throws -> DataModel.Note {
        let note = DataModel.Note(
            title: title,
            content: content,
            date: date,
            period: period,
            assignments: []
        )

        // Find best spread for assignment
        let spreadService = ConventionalSpreadService(calendar: calendar)
        if let bestSpread = spreadService.findBestSpread(for: note, in: spreads) {
            let normalizedDate = bestSpread.period.normalizeDate(bestSpread.date, calendar: calendar)
            let assignment = NoteAssignment(
                period: bestSpread.period,
                date: normalizedDate,
                status: .active
            )
            note.assignments.append(assignment)
        }

        // Persist and reload state
        try await noteRepository.save(note)
        if reloadAfter {
            await reload()
        }

        return note
    }

    // MARK: - Private Helpers

    private func addMockSpread(_ spread: DataModel.Spread) async throws {
        if spread.period == .multiday {
            guard let startDate = spread.startDate, let endDate = spread.endDate else {
                return
            }
            _ = try await addMultidaySpread(startDate: startDate, endDate: endDate)
            return
        }

        _ = try await addSpread(period: spread.period, date: spread.date)
    }
}
#endif
