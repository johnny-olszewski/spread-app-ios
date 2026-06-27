import Foundation

/// In-memory list repository for unit testing.
///
/// Provides a working repository implementation that stores lists in memory.
/// Supports initialization with existing lists for test setup.
@MainActor
final class TestListRepository: ListRepository {

    // MARK: - Properties

    private var lists: [UUID: DataModel.List]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.lists = [:]
    }

    /// Creates a repository pre-populated with lists.
    ///
    /// - Parameter lists: Initial lists to populate the repository.
    init(lists: [DataModel.List]) {
        self.lists = Dictionary(uniqueKeysWithValues: lists.map { ($0.id, $0) })
    }

    // MARK: - ListRepository

    func getLists() async -> [DataModel.List] {
        Array(lists.values).sorted { $0.name < $1.name }
    }

    func save(_ list: DataModel.List) async throws {
        lists[list.id] = list
    }

    func delete(_ list: DataModel.List) async throws {
        lists.removeValue(forKey: list.id)
    }
}
