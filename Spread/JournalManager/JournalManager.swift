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
    private init(
        calendar: Calendar,
        today: Date,
        taskRepository: any TaskRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository,
        noteRepository: any NoteRepository,
        bujoMode: BujoMode
    ) {
        self.calendar = calendar
        self.today = today
        self.taskRepository = taskRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.noteRepository = noteRepository
        self.bujoMode = bujoMode
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
    /// - Returns: A configured JournalManager with data loaded.
    static func makeForTesting(
        calendar: Calendar? = nil,
        today: Date? = nil,
        taskRepository: (any TaskRepository)? = nil,
        spreadRepository: (any SpreadRepository)? = nil,
        eventRepository: (any EventRepository)? = nil,
        noteRepository: (any NoteRepository)? = nil,
        bujoMode: BujoMode = .conventional
    ) async throws -> JournalManager {
        var testCalendar: Calendar {
            var cal = Calendar(identifier: .gregorian)
            cal.timeZone = .init(identifier: "UTC")!
            return cal
        }

        let manager = JournalManager(
            calendar: calendar ?? testCalendar,
            today: today ?? .now,
            taskRepository: taskRepository ?? InMemoryTaskRepository(),
            spreadRepository: spreadRepository ?? InMemorySpreadRepository(),
            eventRepository: eventRepository ?? InMemoryEventRepository(),
            noteRepository: noteRepository ?? InMemoryNoteRepository(),
            bujoMode: bujoMode
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
            spreadData.tasks = tasks.filter { task in
                hasAssignment(task, for: spread)
            }

            // Associate notes with this spread
            spreadData.notes = notes.filter { note in
                hasAssignment(note, for: spread)
            }

            // Associate events based on date overlap
            spreadData.events = events.filter { event in
                eventAppearsOnSpread(event, spread: spread)
            }

            model[spread.period]?[normalizedDate] = spreadData
        }

        dataModel = model
    }

    // MARK: - Entry Association Helpers

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
}
