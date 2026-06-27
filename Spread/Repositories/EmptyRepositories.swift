import Foundation

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

/// Empty collection repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyCollectionRepository: CollectionRepository {
    func getCollections() async -> [DataModel.Collection] { [] }
    func save(_ collection: DataModel.Collection) async throws {}
    func delete(_ collection: DataModel.Collection) async throws {}
}

/// Empty settings repository for isolated testing.
///
/// Returns nil and no-ops for all operations.
struct EmptySettingsRepository: SettingsRepository {
    func getSettings() async -> DataModel.Settings? { nil }
    func save(_ settings: DataModel.Settings) async throws {}
}

/// Empty list repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyListRepository: ListRepository {
    func getLists() async -> [DataModel.List] { [] }
    func save(_ list: DataModel.List) async throws {}
    func delete(_ list: DataModel.List) async throws {}
}

/// Empty tag repository for isolated testing.
///
/// Returns empty arrays and no-ops for all operations.
struct EmptyTagRepository: TagRepository {
    func getTags() async -> [DataModel.Tag] { [] }
    func save(_ tag: DataModel.Tag) async throws {}
    func delete(_ tag: DataModel.Tag) async throws {}
}
