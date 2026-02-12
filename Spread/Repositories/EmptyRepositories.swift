import Foundation

/// Empty task repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyTaskRepository: TaskRepository {
    func getTasks() async -> [DataModel.Task] { [] }
    func save(_ task: DataModel.Task) async throws {}
    func delete(_ task: DataModel.Task) async throws {}
}

/// Empty spread repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptySpreadRepository: SpreadRepository {
    func getSpreads() async -> [DataModel.Spread] { [] }
    func save(_ spread: DataModel.Spread) async throws {}
    func delete(_ spread: DataModel.Spread) async throws {}
}

/// Empty event repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyEventRepository: EventRepository {
    func getEvents() async -> [DataModel.Event] { [] }
    func getEvents(from startDate: Date, to endDate: Date) async -> [DataModel.Event] { [] }
    func save(_ event: DataModel.Event) async throws {}
    func delete(_ event: DataModel.Event) async throws {}
}

/// Empty note repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyNoteRepository: NoteRepository {
    func getNotes() async -> [DataModel.Note] { [] }
    func save(_ note: DataModel.Note) async throws {}
    func delete(_ note: DataModel.Note) async throws {}
}

/// Empty collection repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyCollectionRepository: CollectionRepository {
    func getCollections() async -> [DataModel.Collection] { [] }
    func save(_ collection: DataModel.Collection) async throws {}
    func delete(_ collection: DataModel.Collection) async throws {}
}
