import Foundation

/// Plain non-production stand-in for `ChangeAwareTaskRepository`, with no call-tracking
/// or error injection.
///
/// Provides a working repository implementation that stores tasks in memory.
/// Supports initialization with existing tasks for test setup.
///
/// - Note: `ChangeAware` is a temporary qualifier needed only while this type coexists
///   with the legacy `TaskRepository`. Once SPRD-249's cutover deletes that legacy
///   protocol, rename this to follow whatever test-double naming the legacy
///   `TaskRepository` double adopts at that time (see SPRD-245's renaming plan).
@MainActor
final class TestChangeAwareTaskRepository: ChangeAwareTaskRepository {

    // MARK: - Properties

    private var tasks: [UUID: DataModel.Task]

    // MARK: - Initialization

    /// Creates an empty repository.
    init() {
        self.tasks = [:]
    }

    /// Creates a repository pre-populated with tasks.
    ///
    /// - Parameter tasks: Initial tasks to populate the repository.
    init(tasks: [DataModel.Task]) {
        self.tasks = Dictionary(uniqueKeysWithValues: tasks.map { ($0.id, $0) })
    }

    // MARK: - ChangeAwareTaskRepository

    func getTasks() async -> [DataModel.Task] {
        Array(tasks.values).sorted { $0.createdDate < $1.createdDate }
    }

    func save(_ task: DataModel.Task, change: EntityChange<TaskAssignment>) async throws {
        tasks[task.id] = task
    }

    func saveAll(_ requests: [TaskSaveRequest]) async throws {
        for request in requests {
            tasks[request.task.id] = request.task
        }
    }

    func delete(_ task: DataModel.Task) async throws {
        tasks.removeValue(forKey: task.id)
    }
}
