import Foundation

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
        Array(spreads.values).sorted { lhs, rhs in
            // Sort by period (year > month > day > multiday), then by date descending
            if lhs.period != rhs.period {
                return periodSortOrder(lhs.period) < periodSortOrder(rhs.period)
            }
            return lhs.date > rhs.date
        }
    }

    private func periodSortOrder(_ period: Period) -> Int {
        switch period {
        case .year: return 0
        case .month: return 1
        case .day: return 2
        case .multiday: return 3
        }
    }

    func save(_ spread: DataModel.Spread) async throws {
        spreads[spread.id] = spread
    }

    func delete(_ spread: DataModel.Spread) async throws {
        spreads.removeValue(forKey: spread.id)
    }
}
