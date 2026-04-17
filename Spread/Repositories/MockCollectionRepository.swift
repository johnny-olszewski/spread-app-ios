import Foundation

/// Mock collection repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockCollectionRepository: CollectionRepository {

    // MARK: - Properties

    private var collections: [UUID: DataModel.Collection]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample collections.
    init() {
        let sampleCollections = TestData.sampleCollections()
        self.collections = Dictionary(uniqueKeysWithValues: sampleCollections.map { ($0.id, $0) })
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
