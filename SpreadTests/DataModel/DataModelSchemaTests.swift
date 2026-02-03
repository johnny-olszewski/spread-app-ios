import struct Foundation.Calendar
import struct Foundation.Date
import struct Foundation.TimeZone
import SwiftData
import Testing
@testable import Spread

struct DataModelSchemaTests {

    // MARK: - Test Helpers

    private var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    // MARK: - Schema Tests

    /// Conditions: Access schema version identifier.
    /// Expected: Version should be 1.0.0.
    @Test func testSchemaVersionIsCorrect() {
        let version = DataModelSchemaV1.versionIdentifier
        #expect(version.major == 1)
        #expect(version.minor == 0)
        #expect(version.patch == 0)
    }

    /// Conditions: Access schema models.
    /// Expected: Should contain 7 models: Spread, Task, Event, Note, Collection, SyncMutation, SyncCursor.
    @Test func testSchemaContainsAllModels() {
        let models = DataModelSchemaV1.models
        #expect(models.count == 7)

        let modelTypes = models.map { String(describing: $0) }
        #expect(modelTypes.contains { $0.contains("Spread") })
        #expect(modelTypes.contains { $0.contains("Task") })
        #expect(modelTypes.contains { $0.contains("Event") })
        #expect(modelTypes.contains { $0.contains("Note") })
        #expect(modelTypes.contains { $0.contains("Collection") })
        #expect(modelTypes.contains { $0.contains("SyncMutation") })
        #expect(modelTypes.contains { $0.contains("SyncCursor") })
    }

    // MARK: - Migration Plan Tests

    /// Conditions: Access migration plan schemas.
    /// Expected: Should have one schema (DataModelSchemaV1).
    @Test func testMigrationPlanHasCorrectSchema() {
        let schemas = DataModelMigrationPlan.schemas
        #expect(schemas.count == 1)
        #expect(schemas.first == DataModelSchemaV1.self)
    }

    /// Conditions: Access migration plan stages.
    /// Expected: Should be empty (no migrations for v1).
    @Test func testMigrationPlanHasEmptyStages() {
        let stages = DataModelMigrationPlan.stages
        #expect(stages.isEmpty)
    }

    // MARK: - ModelContainerFactory Tests

    /// Conditions: Create in-memory container.
    /// Expected: Container should have 7 entity types in schema.
    @Test func testCreateInMemoryContainer() throws {
        let container = try ModelContainerFactory.makeInMemory()
        #expect(container.schema.entities.count == 7)
    }

    /// Conditions: Create test container.
    /// Expected: Container should have 7 entity types in schema.
    @Test func testCreateTestContainer() throws {
        let container = try ModelContainerFactory.makeForTesting()
        #expect(container.schema.entities.count == 7)
    }

    /// Conditions: Create in-memory container and check configuration.
    /// Expected: Configuration should have isStoredInMemoryOnly = true.
    @Test func testInMemoryContainerIsNotPersistent() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let configuration = container.configurations.first
        #expect(configuration?.isStoredInMemoryOnly == true)
    }

    /// Conditions: Create containers for testing and in-memory use.
    /// Expected: Both should use in-memory storage.
    @Test func testContainerConfigurationForInMemoryFactories() throws {
        // Testing factory should use in-memory storage
        let testingContainer = try ModelContainerFactory.makeForTesting()
        let testingConfig = testingContainer.configurations.first
        #expect(testingConfig?.isStoredInMemoryOnly == true)

        // In-memory factory should use in-memory storage
        let inMemoryContainer = try ModelContainerFactory.makeInMemory()
        let inMemoryConfig = inMemoryContainer.configurations.first
        #expect(inMemoryConfig?.isStoredInMemoryOnly == true)
    }

    // MARK: - Model CRUD Tests

    /// Conditions: Insert and save a Spread model to test container.
    /// Expected: Spread should be fetchable with correct id and period.
    @MainActor
    @Test func testSpreadModelCanBeSavedAndFetched() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        let spread = DataModel.Spread(period: .day, date: Date.now, calendar: testCalendar)
        context.insert(spread)
        try context.save()

        let descriptor = FetchDescriptor<DataModel.Spread>()
        let spreads = try context.fetch(descriptor)
        #expect(spreads.count == 1)
        #expect(spreads.first?.id == spread.id)
        #expect(spreads.first?.period == .day)
    }

    /// Conditions: Insert and save a Task model to test container.
    /// Expected: Task should be fetchable with correct id.
    @MainActor
    @Test func testTaskModelCanBeSavedAndFetched() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        let task = DataModel.Task()
        context.insert(task)
        try context.save()

        let descriptor = FetchDescriptor<DataModel.Task>()
        let tasks = try context.fetch(descriptor)
        #expect(tasks.count == 1)
        #expect(tasks.first?.id == task.id)
    }

    /// Conditions: Insert and save an Event model to test container.
    /// Expected: Event should be fetchable with correct id.
    @MainActor
    @Test func testEventModelCanBeSavedAndFetched() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        let event = DataModel.Event()
        context.insert(event)
        try context.save()

        let descriptor = FetchDescriptor<DataModel.Event>()
        let events = try context.fetch(descriptor)
        #expect(events.count == 1)
        #expect(events.first?.id == event.id)
    }

    /// Conditions: Insert and save a Note model to test container.
    /// Expected: Note should be fetchable with correct id.
    @MainActor
    @Test func testNoteModelCanBeSavedAndFetched() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        let note = DataModel.Note()
        context.insert(note)
        try context.save()

        let descriptor = FetchDescriptor<DataModel.Note>()
        let notes = try context.fetch(descriptor)
        #expect(notes.count == 1)
        #expect(notes.first?.id == note.id)
    }

    /// Conditions: Insert and save a Collection model to test container.
    /// Expected: Collection should be fetchable with correct id.
    @MainActor
    @Test func testCollectionModelCanBeSavedAndFetched() throws {
        let container = try ModelContainerFactory.makeForTesting()
        let context = container.mainContext

        let collection = DataModel.Collection()
        context.insert(collection)
        try context.save()

        let descriptor = FetchDescriptor<DataModel.Collection>()
        let collections = try context.fetch(descriptor)
        #expect(collections.count == 1)
        #expect(collections.first?.id == collection.id)
    }
}
