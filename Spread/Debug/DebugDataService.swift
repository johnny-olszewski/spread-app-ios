#if DEBUG
import Foundation

/// Service for loading and clearing debug mock data sets.
///
/// Used by the Debug menu to overwrite existing data with predefined test scenarios.
/// Loading a data set clears all existing data first, then loads the new data.
@MainActor
final class DebugDataService {

    // MARK: - Properties

    private let taskRepository: any TaskRepository
    private let spreadRepository: any SpreadRepository
    private let eventRepository: any EventRepository
    private let noteRepository: any NoteRepository
    private let onReload: (() -> Void)?

    // MARK: - Initialization

    /// Creates a debug data service with the given repositories.
    ///
    /// - Parameters:
    ///   - taskRepository: Repository for task operations.
    ///   - spreadRepository: Repository for spread operations.
    ///   - eventRepository: Repository for event operations.
    ///   - noteRepository: Repository for note operations.
    ///   - onReload: Optional callback invoked after data is loaded.
    init(
        taskRepository: any TaskRepository,
        spreadRepository: any SpreadRepository,
        eventRepository: any EventRepository,
        noteRepository: any NoteRepository,
        onReload: (() -> Void)? = nil
    ) {
        self.taskRepository = taskRepository
        self.spreadRepository = spreadRepository
        self.eventRepository = eventRepository
        self.noteRepository = noteRepository
        self.onReload = onReload
    }

    // MARK: - Public Methods

    /// Loads a mock data set, replacing all existing data.
    ///
    /// This operation:
    /// 1. Clears all existing spreads, tasks, events, and notes
    /// 2. Loads the generated data from the data set
    /// 3. Invokes the reload callback (if set)
    ///
    /// - Parameters:
    ///   - dataSet: The mock data set to load.
    ///   - calendar: The calendar to use for data generation.
    ///   - today: The reference date for data generation.
    /// - Throws: Repository errors if persistence fails.
    func loadDataSet(
        _ dataSet: MockDataSet,
        calendar: Calendar,
        today: Date
    ) async throws {
        // Clear existing data
        try await clearAllData()

        // Generate new data
        let generatedData = dataSet.generateData(calendar: calendar, today: today)

        // Save spreads
        for spread in generatedData.spreads {
            try await spreadRepository.save(spread)
        }

        // Save tasks
        for task in generatedData.tasks {
            try await taskRepository.save(task)
        }

        // Save events
        for event in generatedData.events {
            try await eventRepository.save(event)
        }

        // Save notes
        for note in generatedData.notes {
            try await noteRepository.save(note)
        }

        // Trigger reload
        onReload?()
    }

    /// Clears all data from all repositories.
    ///
    /// Removes all spreads, tasks, events, and notes.
    ///
    /// - Throws: Repository errors if deletion fails.
    func clearAllData() async throws {
        // Clear tasks
        let tasks = await taskRepository.getTasks()
        for task in tasks {
            try await taskRepository.delete(task)
        }

        // Clear spreads
        let spreads = await spreadRepository.getSpreads()
        for spread in spreads {
            try await spreadRepository.delete(spread)
        }

        // Clear events
        let events = await eventRepository.getEvents()
        for event in events {
            try await eventRepository.delete(event)
        }

        // Clear notes
        let notes = await noteRepository.getNotes()
        for note in notes {
            try await noteRepository.delete(note)
        }
    }
}
#endif
