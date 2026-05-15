import Foundation

/// Mock tag repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockTagRepository: TagRepository {

    // MARK: - Properties

    private var tags: [UUID: DataModel.Tag]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample tags.
    init() {
        let samples = [
            DataModel.Tag(name: "EOY Presentation"),
            DataModel.Tag(name: "Baby Preparation"),
            DataModel.Tag(name: "Garage Reorganization"),
        ]
        self.tags = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })
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
