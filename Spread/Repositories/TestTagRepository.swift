import Foundation

/// In-memory tag repository for unit testing.
///
/// Provides a working repository implementation that stores tags in memory.
/// Supports initialization with existing tags for test setup.
@MainActor
final class TestTagRepository: TagRepository {

    // MARK: - Properties

    private var tags: [UUID: DataModel.Tag]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.tags = [:]
    }

    /// Creates a repository pre-populated with tags.
    ///
    /// - Parameter tags: Initial tags to populate the repository.
    init(tags: [DataModel.Tag]) {
        self.tags = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0) })
    }

    // MARK: - TagRepository

    func getTags() async -> [DataModel.Tag] {
        Array(tags.values).sorted { $0.name < $1.name }
    }

    func save(_ tag: DataModel.Tag) async throws {
        tags[tag.id] = tag
    }

    func delete(_ tag: DataModel.Tag) async throws {
        tags.removeValue(forKey: tag.id)
    }
}
