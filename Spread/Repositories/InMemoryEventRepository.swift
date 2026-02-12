import Foundation

/// In-memory event repository for unit testing.
///
/// Provides a working repository implementation that stores events in memory.
/// Supports initialization with existing events for test setup.
@MainActor
final class InMemoryEventRepository: EventRepository {

    // MARK: - Properties

    private var events: [UUID: DataModel.Event]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.events = [:]
    }

    /// Creates a repository pre-populated with events.
    ///
    /// - Parameter events: Initial events to populate the repository.
    init(events: [DataModel.Event]) {
        self.events = Dictionary(uniqueKeysWithValues: events.map { ($0.id, $0) })
    }

    // MARK: - EventRepository

    func getEvents() async -> [DataModel.Event] {
        Array(events.values).sorted { $0.createdDate < $1.createdDate }
    }

    func getEvents(from startDate: Date, to endDate: Date) async -> [DataModel.Event] {
        Array(events.values)
            .filter { event in
                // Event overlaps with the date range if:
                // event.startDate <= endDate AND event.endDate >= startDate
                event.startDate <= endDate && event.endDate >= startDate
            }
            .sorted { $0.startDate < $1.startDate }
    }

    func save(_ event: DataModel.Event) async throws {
        events[event.id] = event
    }

    func delete(_ event: DataModel.Event) async throws {
        events.removeValue(forKey: event.id)
    }
}
