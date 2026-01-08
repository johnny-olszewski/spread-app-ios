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
        // TODO: SPRD-8 - Update sorting to use period (desc) then date when Period is added
        // Current sorting: createdDate descending (newest first)
        let descriptor = FetchDescriptor<DataModel.Spread>(
            sortBy: [SortDescriptor(\.createdDate, order: .reverse)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
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
