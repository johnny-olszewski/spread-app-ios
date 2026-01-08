import struct Foundation.UUID

/// In-memory spread repository for unit testing.
///
/// Provides a working repository implementation that stores spreads in memory.
/// Supports initialization with existing spreads for test setup.
@MainActor
final class InMemorySpreadRepository: SpreadRepository {

    // MARK: - Properties

    private var spreads: [UUID: DataModel.Spread]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.spreads = [:]
    }

    /// Creates a repository pre-populated with spreads.
    ///
    /// - Parameter spreads: Initial spreads to populate the repository.
    init(spreads: [DataModel.Spread]) {
        self.spreads = Dictionary(uniqueKeysWithValues: spreads.map { ($0.id, $0) })
    }

    // MARK: - SpreadRepository

    func getSpreads() async -> [DataModel.Spread] {
        // TODO: SPRD-8 - Update sorting to use period (desc) then date when Period is added
        Array(spreads.values).sorted { $0.createdDate > $1.createdDate }
    }

    func save(_ spread: DataModel.Spread) async throws {
        spreads[spread.id] = spread
    }

    func delete(_ spread: DataModel.Spread) async throws {
        spreads.removeValue(forKey: spread.id)
    }
}
