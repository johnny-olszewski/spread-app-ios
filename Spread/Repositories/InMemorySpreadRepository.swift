import Foundation

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
