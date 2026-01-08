import Foundation
import SwiftData

/// SwiftData implementation of TaskRepository.
///
/// Provides CRUD operations for tasks using SwiftData persistence.
/// All operations run on the main actor for thread safety with SwiftData.
@MainActor
final class SwiftDataTaskRepository: TaskRepository {

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

    // MARK: - TaskRepository

    func getTasks() async -> [DataModel.Task] {
        let descriptor = FetchDescriptor<DataModel.Task>(
            sortBy: [SortDescriptor(\.createdDate, order: .forward)]
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            return []
        }
    }

    func save(_ task: DataModel.Task) async throws {
        modelContext.insert(task)
        try modelContext.save()
    }

    func delete(_ task: DataModel.Task) async throws {
        modelContext.delete(task)
        try modelContext.save()
    }
}
