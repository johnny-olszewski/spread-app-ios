import Foundation

/// Mock task repository pre-seeded with sample data for SwiftUI previews.
///
/// Provides realistic test data out of the box while supporting all
/// repository operations. Use for previews and UI development.
@MainActor
final class MockTaskRepository: TaskRepository {

    // MARK: - Properties

    private var tasks: [UUID: DataModel.Task]

    // MARK: - Initialization

    /// Creates a mock repository pre-seeded with sample tasks.
    init() {
        let sampleTasks = TestData.sampleTasks()
        self.tasks = Dictionary(uniqueKeysWithValues: sampleTasks.map { ($0.id, $0) })
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
