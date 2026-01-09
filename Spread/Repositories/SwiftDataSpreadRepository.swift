import Foundation
import SwiftData

/// SwiftData implementation of SpreadRepository.
///
/// Provides CRUD operations for spreads using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataSpreadRepository: SpreadRepository {

    // MARK: - Properties

    private let modelContainer: ModelContainer

    private var modelContext: ModelContext {
        modelContainer.mainContext
    }

    // MARK: - Initialization

    /// Creates a repository with the specified model container.
    ///
    /// - Parameter modelContainer: The SwiftData container for persistence.
    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - SpreadRepository

    func getSpreads() async -> [DataModel.Spread] {
        // Fetch all spreads, then sort by period (year > month > day > multiday), then date descending
        // SwiftData doesn't support sorting by enum directly, so we sort in memory
        let descriptor = FetchDescriptor<DataModel.Spread>()

        do {
            let spreads = try modelContext.fetch(descriptor)
            return spreads.sorted { lhs, rhs in
                if lhs.period != rhs.period {
                    return periodSortOrder(lhs.period) < periodSortOrder(rhs.period)
                }
                return lhs.date > rhs.date
            }
        } catch {
            return []
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
        modelContext.insert(spread)
        try modelContext.save()
    }

    func delete(_ spread: DataModel.Spread) async throws {
        modelContext.delete(spread)
        try modelContext.save()
    }
}
