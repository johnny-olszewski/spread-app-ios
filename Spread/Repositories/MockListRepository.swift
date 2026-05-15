import Foundation

/// Mock list repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockListRepository: ListRepository {

    // MARK: - Properties

    private var lists: [UUID: DataModel.List]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample lists.
    init() {
        let samples = [
            DataModel.List(name: "Work"),
            DataModel.List(name: "Home"),
            DataModel.List(name: "Personal"),
        ]
        self.lists = Dictionary(uniqueKeysWithValues: samples.map { ($0.id, $0) })
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
