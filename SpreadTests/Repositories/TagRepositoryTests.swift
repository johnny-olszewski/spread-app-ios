import Foundation
import SwiftData
import Testing
@testable import Spread

/// Tests for `SwiftDataTagRepository` CRUD operations and many-to-many inverse relationships.
@MainActor
struct TagRepositoryTests {

    // MARK: - CRUD

    /// Conditions: Save a tag to an empty in-memory repository.
    /// Expected: getTags returns the saved tag with the correct name.
    @Test func testSaveAndRetrieve() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataTagRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "EOY Presentation")
        try await repo.save(tag)

        let tags = await repo.getTags()
        #expect(tags.count == 1)
        #expect(tags.first?.name == "EOY Presentation")
    }

    /// Conditions: Save three tags to the repository.
    /// Expected: getTags returns all three, sorted alphabetically by name.
    @Test func testGetTagsReturnsSortedByName() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataTagRepository(modelContainer: container)

        try await repo.save(DataModel.Tag(name: "Zebra Project"))
        try await repo.save(DataModel.Tag(name: "Alpha Task"))
        try await repo.save(DataModel.Tag(name: "Middle Work"))

        let tags = await repo.getTags()
        #expect(tags.count == 3)
        #expect(tags.map(\.name) == ["Alpha Task", "Middle Work", "Zebra Project"])
    }

    /// Conditions: Save a tag, update its name, save again.
    /// Expected: Only one tag exists with the updated name.
    @Test func testUpdateExistingTag() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataTagRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Original")
        try await repo.save(tag)

        tag.name = "Updated"
        try await repo.save(tag)

        let tags = await repo.getTags()
        #expect(tags.count == 1)
        #expect(tags.first?.name == "Updated")
    }

    /// Conditions: Save a tag then delete it.
    /// Expected: getTags returns an empty array.
    @Test func testDelete() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataTagRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Temporary")
        try await repo.save(tag)
        #expect(await repo.getTags().count == 1)

        try await repo.delete(tag)
        #expect(await repo.getTags().isEmpty)
    }

    // MARK: - Relationships

    /// Conditions: A tag is added to a task's tags array and the task is saved.
    /// Expected: The task's tags array contains the tag.
    @Test func testAddingTagToTaskSetsInverseRelationship() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let tagRepo = SwiftDataTagRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Baby Preparation")
        try await tagRepo.save(tag)

        let task = DataModel.Task(title: "Buy crib", tags: [tag])
        try await taskRepo.save(task)

        let tasks = await taskRepo.getTasks()
        #expect(tasks.first?.tags.map(\.name) == ["Baby Preparation"])
    }

    /// Conditions: Two tags are added to a task.
    /// Expected: The task's tags array contains both tags.
    @Test func testMultipleTagsOnTask() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let tagRepo = SwiftDataTagRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let tag1 = DataModel.Tag(name: "Work")
        let tag2 = DataModel.Tag(name: "Urgent")
        try await tagRepo.save(tag1)
        try await tagRepo.save(tag2)

        let task = DataModel.Task(title: "Critical deadline", tags: [tag1, tag2])
        try await taskRepo.save(task)

        let tasks = await taskRepo.getTasks()
        #expect(tasks.first?.tags.count == 2)
    }

    /// Conditions: Deleting a DataModel.Tag with nullify delete rule while tasks reference it.
    /// Expected: After deletion, the task's tags array no longer contains the deleted tag.
    @Test func testDeletingTagRemovesItFromTaskTags() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let tagRepo = SwiftDataTagRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Garage Reorganization")
        try await tagRepo.save(tag)

        let task = DataModel.Task(title: "Buy shelving", tags: [tag])
        try await taskRepo.save(task)

        try await tagRepo.delete(tag)

        let tasks = await taskRepo.getTasks()
        #expect(tasks.first?.tags.isEmpty == true)
    }

    // MARK: - Sync Outbox

    /// Conditions: Save a new tag.
    /// Expected: A SyncMutation with entityType "tags" and operation "create" is enqueued.
    @Test func testSaveEnqueuesCreateMutation() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let repo = SwiftDataTagRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Test Tag")
        try await repo.save(tag)

        let context = container.mainContext
        let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
        let tagMutation = mutations.first { $0.entityType == "tags" }
        #expect(tagMutation != nil)
        #expect(tagMutation?.operation == "create")
    }

    /// Conditions: Save a task with a tag, then save it again with the tag removed.
    /// Expected: A task_tags delete mutation is enqueued for the removed tag.
    @Test func testRemovingTagFromTaskEnqueuesTaskTagTombstone() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let tagRepo = SwiftDataTagRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "Removable")
        try await tagRepo.save(tag)

        let task = DataModel.Task(title: "Task with tag", tags: [tag])
        try await taskRepo.save(task)

        // Remove the tag and save again
        task.tags.removeAll()
        try await taskRepo.save(task)

        let context = container.mainContext
        let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
        let taskTagDelete = mutations.first { $0.entityType == "task_tags" && $0.operation == "delete" }
        #expect(taskTagDelete != nil)
    }

    /// Conditions: Save a task with no tags, then add a tag and save again.
    /// Expected: A task_tags create mutation is enqueued for the added tag.
    @Test func testAddingTagToExistingTaskEnqueuesTaskTagCreate() async throws {
        let container = try ModelContainerFactory.makeInMemory()
        let tagRepo = SwiftDataTagRepository(modelContainer: container)
        let taskRepo = SwiftDataTaskRepository(modelContainer: container)

        let tag = DataModel.Tag(name: "New Tag")
        try await tagRepo.save(tag)

        let task = DataModel.Task(title: "Task without tags")
        try await taskRepo.save(task)

        // Add a tag and save
        task.tags.append(tag)
        try await taskRepo.save(task)

        let context = container.mainContext
        let mutations = try context.fetch(FetchDescriptor<DataModel.SyncMutation>())
        let taskTagCreate = mutations.first { $0.entityType == "task_tags" && $0.operation == "create" }
        #expect(taskTagCreate != nil)
    }
}
