import struct Foundation.UUID

/// Mock spread repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockSpreadRepository: SpreadRepository {

    // MARK: - Properties

    private var spreads: [UUID: DataModel.Spread]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample spreads.
    init() {
        let sampleSpreads = TestData.sampleSpreads()
        self.spreads = Dictionary(uniqueKeysWithValues: sampleSpreads.map { ($0.id, $0) })
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
