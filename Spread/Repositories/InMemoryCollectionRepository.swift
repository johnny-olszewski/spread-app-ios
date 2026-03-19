import Foundation

/// In-memory collection repository for unit testing.
///
/// Provides a working repository implementation that stores collections in memory.
/// Collections are sorted by modifiedDate descending (newest first) per spec.
/// Supports initialization with existing collections for test setup.
@MainActor
final class InMemoryCollectionRepository: CollectionRepository {

    // MARK: - Properties

    private var collections: [UUID: DataModel.Collection]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.collections = [:]
    }

    /// Creates a repository pre-populated with collections.
    ///
    /// - Parameter collections: Initial collections to populate the repository.
    init(collections: [DataModel.Collection]) {
        self.collections = Dictionary(uniqueKeysWithValues: collections.map { ($0.id, $0) })
    }

    // MARK: - CollectionRepository

    func getCollections() async -> [DataModel.Collection] {
        Array(collections.values).sorted { $0.modifiedDate > $1.modifiedDate }
    }

    func save(_ collection: DataModel.Collection) async throws {
        collections[collection.id] = collection
    }

    func delete(_ collection: DataModel.Collection) async throws {
        collections.removeValue(forKey: collection.id)
    }
}
