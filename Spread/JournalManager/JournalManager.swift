import struct Foundation.Calendar
import struct Foundation.Date
import Observation

/// Central coordinator for journal data and operations.
///
/// JournalManager owns the in-memory data model, handles data loading from
/// repositories, and provides access to spreads and entries. It coordinates
/// between the UI layer and persistence layer.
///
/// Use `makeForTesting` factory method to create instances with mock repositories.
@Observable
@MainActor
final class JournalManager {

    // MARK: - Properties

    /// The calendar used for date calculations.
    let calendar: Calendar

    /// The current date for determining present/future logic.
    let today: Date

    /// Repository for task persistence.
    let taskRepository: any TaskRepository

    /// Repository for spread persistence.
    let spreadRepository: any SpreadRepository

    /// Repository for event persistence.
    let eventRepository: any EventRepository

    /// Repository for note persistence.
    let noteRepository: any NoteRepository

    /// The current BuJo mode (conventional or traditional).
    var bujoMode: BujoMode

    /// Policy for validating spread creation.
    let creationPolicy: SpreadCreationPolicy

    /// Version counter that increments on data mutations.
    ///
    /// SwiftUI views can observe this to trigger refreshes when data changes.
    private(set) var dataVersion: Int = 0

    /// All spreads loaded from the repository.
    private(set) var spreads: [DataModel.Spread] = []

    /// All tasks loaded from the repository.
    private(set) var tasks: [DataModel.Task] = []

    /// All events loaded from the repository.
    private(set) var events: [DataModel.Event] = []

    /// All notes loaded from the repository.
    private(set) var notes: [DataModel.Note] = []

    /// The journal data model organized by period and date.
    ///
    /// Provides nested dictionary access: `dataModel[.month][normalizedDate]`
    /// returns the `SpreadDataModel` for that month spread.
    private(set) var dataModel: JournalDataModel = [:]

    /// Service for finding best spreads for entry assignment.
    private var spreadService: ConventionalSpreadService {
        ConventionalSpreadService(calendar: calendar)
    }

    // MARK: - Inbox

    /// Entries that have no matching spread assignment.
    ///
    /// Includes tasks and notes that either have no assignments or have no
    /// assignment matching any existing spread. Events are excluded (they use
    /// computed visibility). Cancelled tasks are excluded.
    var inboxEntries: [any Entry] {
        var entries: [any Entry] = []

        // Add unassigned tasks (excluding cancelled)
        for task in tasks where task.status != .cancelled {
            if task.assignments.isEmpty || !hasMatchingAssignment(for: task) {
                entries.append(task)
            }
        }

        // Add unassigned notes
        for note in notes {
            if note.assignments.isEmpty || !hasMatchingAssignment(for: note) {
                entries.append(note)
            }
        }

        return entries
    }

    /// The number of entries in the Inbox.
    ///
    /// Used for badge display. Returns 0 when no unassigned entries exist.
    var inboxCount: Int {
        inboxEntries.count
    }

    // MARK: - Initialization

    /// Creates a new JournalManager.
    ///
    /// Loads data from repositories asynchronously. Use `makeForTesting` for tests.
    ///
    /// - Parameters:
    ///   - calendar: The calendar for date calculations.
    ///   - today: The current date.
    ///   - taskRepository: Repository for tasks.
    ///   - spreadRepository: Repository for spreads.
    ///   - eventRepository: Repository for events.
    ///   - noteRepository: Repository for notes.
    ///   - bujoMode: The initial BuJo mode.
    ///   - creationPolicy: Policy for validating spread creation.
    private init(
        calendar: Calendar,
        today: Date,
        taskRepository: any TaskRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository,
        noteRepository: any NoteRepository,
        bujoMode: BujoMode,
        creationPolicy: SpreadCreationPolicy
    ) {
        self.calendar = calendar
        self.today = today
        self.taskRepository = taskRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.noteRepository = noteRepository
        self.bujoMode = bujoMode
        self.creationPolicy = creationPolicy
    }

    // MARK: - Factory Methods

    /// Creates a JournalManager for testing with mock repositories.
    ///
    /// - Parameters:
    ///   - calendar: The calendar for date calculations (defaults to gregorian UTC).
    ///   - today: The current date (defaults to now).
    ///   - taskRepository: Repository for tasks (defaults to empty in-memory).
    ///   - spreadRepository: Repository for spreads (defaults to empty in-memory).
    ///   - eventRepository: Repository for events (defaults to empty in-memory).
    ///   - noteRepository: Repository for notes (defaults to empty in-memory).
    ///   - bujoMode: The initial BuJo mode (defaults to conventional).
    ///   - creationPolicy: Policy for spread creation (defaults to standard policy).
    /// - Returns: A configured JournalManager with data loaded.
    static func makeForTesting(
        calendar: Calendar? = nil,
        today: Date? = nil,
        taskRepository: (any TaskRepository)? = nil,
        spreadRepository: (any SpreadRepository)? = nil,
        eventRepository: (any EventRepository)? = nil,
        noteRepository: (any NoteRepository)? = nil,
        bujoMode: BujoMode = .conventional,
        creationPolicy: SpreadCreationPolicy? = nil
    ) async throws -> JournalManager {
        var testCalendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }

        let resolvedToday = today ?? .now
        let defaultPolicy = StandardCreationPolicy(today: resolvedToday, firstWeekday: .sunday)

        let manager = JournalManager(
            calendar: calendar ?? testCalendar,
            today: resolvedToday,
            taskRepository: taskRepository ?? InMemoryTaskRepository(),
            spreadRepository: spreadRepository ?? InMemorySpreadRepository(),
            eventRepository: eventRepository ?? InMemoryEventRepository(),
            noteRepository: noteRepository ?? InMemoryNoteRepository(),
            bujoMode: bujoMode,
            creationPolicy: creationPolicy ?? defaultPolicy
        )
        await manager.loadData()
        return manager
    }

    // MARK: - Data Loading

    /// Loads all data from repositories.
    ///
    /// Called during initialization and can be called to refresh data.
    private func loadData() async {
        spreads = await spreadRepository.getSpreads()
        tasks = await taskRepository.getTasks()
        events = await eventRepository.getEvents()
        notes = await noteRepository.getNotes()

        buildDataModel()
    }

    /// Reloads data from repositories.
    ///
    /// Increments `dataVersion` to trigger UI updates.
    func reload() async {
        await loadData()
        dataVersion += 1
    }

    // MARK: - Data Model Building

    /// Builds the journal data model from loaded data.
    ///
    /// Organizes spreads by period and date, then associates entries
    /// with their corresponding spreads.
    private func buildDataModel() {
        var model: JournalDataModel = [:]

        // Organize spreads by period and normalized date
        for spread in spreads {
            let normalizedDate = spread.period.normalizeDate(spread.date, calendar: calendar)

            if model[spread.period] == nil {
                model[spread.period] = [:]
            }

            var spreadData = SpreadDataModel(spread: spread)

            // Associate tasks with this spread
            spreadData.tasks = tasksForSpread(spread)

            // Associate notes with this spread
            spreadData.notes = notesForSpread(spread)

            // Associate events based on date overlap
            spreadData.events = events.filter { event in
                eventAppearsOnSpread(event, spread: spread)
            }

            model[spread.period]?[normalizedDate] = spreadData
        }

        dataModel = model
    }

    // MARK: - Entry Association Helpers

    /// Returns tasks that should appear on the given spread.
    private func tasksForSpread(_ spread: DataModel.Spread) -> [DataModel.Task] {
        if spread.period == .multiday {
            return tasks.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return tasks.filter { hasAssignment($0, for: spread) }
    }

    /// Returns notes that should appear on the given spread.
    private func notesForSpread(_ spread: DataModel.Spread) -> [DataModel.Note] {
        if spread.period == .multiday {
            return notes.filter { entryDateFallsWithinMultidayRange($0.date, spread: spread) }
        }
        return notes.filter { hasAssignment($0, for: spread) }
    }

    /// Checks whether a preferred date falls within a multiday spread's range.
    private func entryDateFallsWithinMultidayRange(_ date: Date, spread: DataModel.Spread) -> Bool {
        guard spread.period == .multiday,
              let startDate = spread.startDate,
              let endDate = spread.endDate else {
            return false
        }

        let normalizedDate = date.startOfDay(calendar: calendar)
        return normalizedDate >= startDate && normalizedDate <= endDate
    }

    /// Checks if a task has an assignment matching the given spread.
    private func hasAssignment(_ task: DataModel.Task, for spread: DataModel.Spread) -> Bool {
        task.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if a note has an assignment matching the given spread.
    private func hasAssignment(_ note: DataModel.Note, for spread: DataModel.Spread) -> Bool {
        note.assignments.contains { assignment in
            assignment.matches(period: spread.period, date: spread.date, calendar: calendar)
        }
    }

    /// Checks if an event should appear on the given spread.
    private func eventAppearsOnSpread(_ event: DataModel.Event, spread: DataModel.Spread) -> Bool {
        if spread.period == .multiday {
            // For multiday spreads, check if event overlaps with the custom range
            guard let startDate = spread.startDate, let endDate = spread.endDate else {
                return false
            }
            let eventStart = event.startDate.startOfDay(calendar: calendar)
            let eventEnd = event.endDate.startOfDay(calendar: calendar)
            return eventStart <= endDate && eventEnd >= startDate
        }

        return event.appearsOn(period: spread.period, date: spread.date, calendar: calendar)
    }

    // MARK: - Inbox Helpers

    /// Checks if a task has an assignment matching any existing spread.
    ///
    /// Returns `true` if at least one assignment matches a spread, meaning it
    /// should not appear in the Inbox.
    private func hasMatchingAssignment(for task: DataModel.Task) -> Bool {
        spreads.contains { hasAssignment(task, for: $0) }
    }

    /// Checks if a note has an assignment matching any existing spread.
    ///
    /// Returns `true` if at least one assignment matches a spread, meaning it
    /// should not appear in the Inbox.
    private func hasMatchingAssignment(for note: DataModel.Note) -> Bool {
        spreads.contains { hasAssignment(note, for: $0) }
    }

    // MARK: - Spread Management

    /// Creates a new spread and auto-resolves matching inbox entries.
    ///
    /// After creating the spread, queries inbox entries that match the new
    /// spread's period and date, creates initial assignments for them, and
    /// persists changes to repositories.
    ///
    /// - Parameters:
    ///   - period: The period for the new spread.
    ///   - date: The date for the new spread.
    /// - Throws: Repository errors if persistence fails.
    func addSpread(period: Period, date: Date) async throws {
        // Create the new spread
        let spread = DataModel.Spread(period: period, date: date, calendar: calendar)

        // Capture inbox entries BEFORE adding spread to the list
        // (matching assignments could appear once the spread exists)
        let entriesToResolve = inboxEntriesToResolve(for: spread)

        // Save spread and add to local list
        try await spreadRepository.save(spread)
        spreads.append(spread)

        // Auto-resolve captured inbox entries
        try await assignEntriesToSpread(entriesToResolve, spread: spread)

        // Reload all data to ensure state is synchronized
        tasks = await taskRepository.getTasks()
        notes = await noteRepository.getNotes()

        // Rebuild data model and trigger UI update
        buildDataModel()
        dataVersion += 1
    }

    /// Finds inbox entries that would be resolved by the given spread.
    ///
    /// Checks which inbox entries would have this spread as their best match
    /// if it were added to the spread list.
    ///
    /// - Parameter spread: The spread to check against.
    /// - Returns: Array of entries that would be resolved by this spread.
    private func inboxEntriesToResolve(for spread: DataModel.Spread) -> [any Entry] {
        // Temporarily add spread to check which entries it would resolve
        let spreadsWithNew = spreads + [spread]

        var entriesToResolve: [any Entry] = []

        for entry in inboxEntries {
            if let task = entry as? DataModel.Task {
                if let bestSpread = spreadService.findBestSpread(for: task, in: spreadsWithNew),
                   bestSpread.id == spread.id {
                    entriesToResolve.append(task)
                }
            } else if let note = entry as? DataModel.Note {
                if let bestSpread = spreadService.findBestSpread(for: note, in: spreadsWithNew),
                   bestSpread.id == spread.id {
                    entriesToResolve.append(note)
                }
            }
        }

        return entriesToResolve
    }

    /// Assigns entries to the given spread.
    ///
    /// Creates initial assignments for tasks and notes.
    ///
    /// - Parameters:
    ///   - entries: The entries to assign.
    ///   - spread: The spread to assign them to.
    private func assignEntriesToSpread(_ entries: [any Entry], spread: DataModel.Spread) async throws {
        for entry in entries {
            if let task = entry as? DataModel.Task {
                try await assignTaskToSpread(task, spread: spread)
            } else if let note = entry as? DataModel.Note {
                try await assignNoteToSpread(note, spread: spread)
            }
        }
    }

    /// Creates an assignment for a task on the given spread.
    private func assignTaskToSpread(_ task: DataModel.Task, spread: DataModel.Spread) async throws {
        let assignment = TaskAssignment(
            period: spread.period,
            date: spread.date,
            status: .open
        )
        task.assignments.append(assignment)
        try await taskRepository.save(task)
    }

    /// Creates an assignment for a note on the given spread.
    private func assignNoteToSpread(_ note: DataModel.Note, spread: DataModel.Spread) async throws {
        let assignment = NoteAssignment(
            period: spread.period,
            date: spread.date,
            status: .active
        )
        note.assignments.append(assignment)
        try await noteRepository.save(note)
    }
}
