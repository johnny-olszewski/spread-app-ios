import Foundation

/// Error-injecting task repository for unit tests.
///
/// Stores tasks in memory like `TestTaskRepository`, but throws `saveError`
/// from `save`/`saveAll` when set — enabling failure-path assertions
/// (e.g. that a failed edit-save surfaces an error to the user).
@MainActor
final class MockTaskRepository: TaskRepository {

    // MARK: - Properties

    /// Error thrown by `save`/`saveAll` when non-nil.
    var saveError: Error?

    private var tasks: [UUID: DataModel.Task]

    // MARK: - Initialization

    /// Creates an empty repository.
    init() {
        self.tasks = [:]
    }

    // MARK: - TaskRepository

    func getTasks() async -> [DataModel.Task] {
        Array(tasks.values).sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ task: DataModel.Task, change: EntityChange) async throws {
        if let saveError { throw saveError }
        tasks[task.id] = task
    }

    func saveAll(_ requests: [TaskSaveRequest]) async throws {
        if let saveError { throw saveError }
        for request in requests {
            tasks[request.task.id] = request.task
        }
    }

    func delete(_ task: DataModel.Task) async throws {
        tasks.removeValue(forKey: task.id)
    }
}
