import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager list and tag operations from the task/note create-edit pickers.
@Suite("JournalManager List and Tag Tests")
@MainActor
struct JournalManagerListTagTests {

    // MARK: - Helpers

    private func makeManager(
        tasks: [DataModel.Task] = [],
        notes: [DataModel.Note] = [],
        lists: [DataModel.List] = [],
        tags: [DataModel.Tag] = []
    ) async throws -> JournalManager {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let today = TestDataBuilders.testDate
        let listRepo = InMemoryListRepository(lists: lists)
        let tagRepo = InMemoryTagRepository(tags: tags)
        return try await JournalManager(
            calendar: cal,
            today: today,
            taskRepository: TestTaskRepository(tasks: tasks),
            noteRepository: TestNoteRepository(notes: notes),
            listRepository: listRepo,
            tagRepository: tagRepo
        )
    }

    // MARK: - Task List

    /// Conditions: A task is saved via updateTaskMetadata with a selected List.
    /// Expected: task.list is set to that List.
    @Test("Saving task with selected list sets task.list")
    func testUpdateTaskMetadataSetsListOnTask() async throws {
        let list = DataModel.List(name: "Work")
        let task = DataModel.Task(title: "Write report")
        let manager = try await makeManager(tasks: [task], lists: [list])

        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: list,
            tags: []
        )

        #expect(manager.tasks[0].list?.name == "Work")
    }

    /// Conditions: A task with a List is saved via updateTaskMetadata with list = nil.
    /// Expected: task.list becomes nil.
    @Test("Clearing list in updateTaskMetadata sets task.list to nil")
    func testUpdateTaskMetadataClearsListOnTask() async throws {
        let list = DataModel.List(name: "Work")
        let task = DataModel.Task(title: "Write report", list: list)
        let manager = try await makeManager(tasks: [task], lists: [list])

        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: nil,
            tags: []
        )

        #expect(manager.tasks[0].list == nil)
    }

    // MARK: - Task Tags

    /// Conditions: A task is saved via updateTaskMetadata with selected Tags.
    /// Expected: task.tags is set to those Tags.
    @Test("Saving task with selected tags sets task.tags")
    func testUpdateTaskMetadataSetsTagsOnTask() async throws {
        let tag1 = DataModel.Tag(name: "Work")
        let tag2 = DataModel.Tag(name: "Urgent")
        let task = DataModel.Task(title: "Deadline")
        let manager = try await makeManager(tasks: [task], tags: [tag1, tag2])

        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: nil,
            tags: [tag1, tag2]
        )

        #expect(manager.tasks[0].tags.count == 2)
    }

    /// Conditions: updateTaskMetadata is called with 6 tags.
    /// Expected: The caller is responsible for enforcing the 5-tag limit; updateTaskMetadata
    ///   itself does not reject it — enforcement lives in the view. Verify the repo accepts any count.
    @Test("updateTaskMetadata accepts any tag count — view enforces 5-tag limit")
    func testSixTagsAcceptedByRepository() async throws {
        let tags = (1...6).map { DataModel.Tag(name: "Tag \($0)") }
        let task = DataModel.Task(title: "Many tags")
        let manager = try await makeManager(tasks: [task], tags: tags)

        // The limit is enforced in the view, not the repository. This test confirms
        // the underlying method accepts the call; the view must prevent reaching here with >5.
        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: nil,
            tags: tags
        )

        #expect(manager.tasks[0].tags.count == 6)
    }

    // MARK: - Task List/Tags Editable When Terminal

    /// Conditions: updateTaskMetadata is called on a task with status .complete.
    /// Expected: list and tags are updated successfully — terminal status does not block metadata edits.
    @Test("List and tags remain editable when task status is complete")
    func testMetadataEditableWhenTaskIsComplete() async throws {
        let list = DataModel.List(name: "Work")
        let task = DataModel.Task(title: "Done task", status: .complete)
        let manager = try await makeManager(tasks: [task], lists: [list])

        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: list,
            tags: []
        )

        #expect(manager.tasks[0].list?.name == "Work")
    }

    /// Conditions: updateTaskMetadata is called on a task with status .cancelled.
    /// Expected: list and tags are updated successfully.
    @Test("List and tags remain editable when task status is cancelled")
    func testMetadataEditableWhenTaskIsCancelled() async throws {
        let tag = DataModel.Tag(name: "Archive")
        let task = DataModel.Task(title: "Cancelled task", status: .cancelled)
        let manager = try await makeManager(tasks: [task], tags: [tag])

        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: nil,
            tags: [tag]
        )

        #expect(manager.tasks[0].tags.count == 1)
    }

    // MARK: - Inline List Creation

    /// Conditions: createList is called with a valid name.
    /// Expected: A new DataModel.List is created, saved to the repo, and journalManager.lists reflects it.
    @Test("createList creates and persists a new List")
    func testCreateListCreatesAndPersistsList() async throws {
        let manager = try await makeManager()

        let list = try await manager.createList(name: "Personal")

        #expect(list.name == "Personal")
        #expect(manager.lists.contains { $0.id == list.id })
    }

    /// Conditions: createList is called then updateTaskMetadata assigns it.
    /// Expected: task.list is the newly created List.
    @Test("Inline list creation and assignment sets task.list")
    func testInlineListCreationAssignsToTask() async throws {
        let task = DataModel.Task(title: "New task")
        let manager = try await makeManager(tasks: [task])

        let list = try await manager.createList(name: "Home")
        try await manager.updateTaskMetadata(
            manager.tasks[0],
            body: nil,
            priority: .none,
            dueDate: nil,
            list: list,
            tags: []
        )

        #expect(manager.tasks[0].list?.name == "Home")
    }

    // MARK: - Inline Tag Creation

    /// Conditions: createTag is called with a valid name.
    /// Expected: A new DataModel.Tag is created, saved to the repo, and journalManager.tags reflects it.
    @Test("createTag creates and persists a new Tag")
    func testCreateTagCreatesAndPersistsTag() async throws {
        let manager = try await makeManager()

        let tag = try await manager.createTag(name: "EOY Presentation")

        #expect(tag.name == "EOY Presentation")
        #expect(manager.tags.contains { $0.id == tag.id })
    }
}
