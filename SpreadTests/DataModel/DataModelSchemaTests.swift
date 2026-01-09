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

    @Test func testSchemaVersionIsCorrect() {
        let version = DataModelSchemaV1.versionIdentifier
        #expect(version.major == 1)
        #expect(version.minor == 0)
        #expect(version.patch == 0)
    }

    @Test func testSchemaContainsAllModels() {
        let models = DataModelSchemaV1.models
        #expect(models.count == 5)

        let modelTypes = models.map { String(describing: $0) }
        #expect(modelTypes.contains { $0.contains("Spread") })
        #expect(modelTypes.contains { $0.contains("Task") })
        #expect(modelTypes.contains { $0.contains("Event") })
        #expect(modelTypes.contains { $0.contains("Note") })
        #expect(modelTypes.contains { $0.contains("Collection") })
    }

    // MARK: - Migration Plan Tests

    @Test func testMigrationPlanHasCorrectSchema() {
        let schemas = DataModelMigrationPlan.schemas
        #expect(schemas.count == 1)
        #expect(schemas.first == DataModelSchemaV1.self)
    }

    @Test func testMigrationPlanHasEmptyStages() {
        let stages = DataModelMigrationPlan.stages
        #expect(stages.isEmpty)
    }

    // MARK: - ModelContainerFactory Tests

    @Test func testCreateInMemoryContainer() throws {
        let container = try ModelContainerFactory.makeInMemory()
        #expect(container.schema.entities.count == 5)
    }

    @Test func testCreateTestContainer() throws {
        let container = try ModelContainerFactory.makeForTesting()
        #expect(container.schema.entities.count == 5)
    }

    @Test func testInMemoryContainerIsNotPersistent() throws {
        let container = try ModelContainerFactory.makeInMemory()
        let configuration = container.configurations.first
        #expect(configuration?.isStoredInMemoryOnly == true)
    }

    @Test func testContainerConfigurationForEnvironment() throws {
        // Testing environment should use in-memory storage
        let testingContainer = try ModelContainerFactory.make(for: .testing)
        let testingConfig = testingContainer.configurations.first
        #expect(testingConfig?.isStoredInMemoryOnly == true)

        // Preview environment should use in-memory storage
        let previewContainer = try ModelContainerFactory.make(for: .preview)
        let previewConfig = previewContainer.configurations.first
        #expect(previewConfig?.isStoredInMemoryOnly == true)
    }

    // MARK: - Model CRUD Tests

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
