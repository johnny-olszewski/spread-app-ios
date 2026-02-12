import Foundation

/// In-memory task repository for unit testing.
///
/// Provides a working repository implementation that stores tasks in memory.
/// Supports initialization with existing tasks for test setup.
@MainActor
final class InMemoryTaskRepository: TaskRepository {

    // MARK: - Properties

    private var tasks: [UUID: DataModel.Task]

    // MARK: - Initialization

    /// Creates an empty in-memory repository.
    init() {
        self.tasks = [:]
    }

    /// Creates a repository pre-populated with tasks.
    ///
    /// - Parameter tasks: Initial tasks to populate the repository.
    init(tasks: [DataModel.Task]) {
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    // MARK: - TaskRepository

    func getTasks() async -> [DataModel.Task] {
        Array(tasks.values).sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ task: DataModel.Task) async throws {
        tasks[task.id] = task
    }

    func delete(_ task: DataModel.Task) async throws {
        tasks.removeValue(forKey: task.id)
    }
}
