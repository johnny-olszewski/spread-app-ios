import struct Foundation.Date
import Testing
@testable import Spread

struct DependencyContainerTests {

    // MARK: - Factory Method Tests

    @Test @MainActor func testMakeForEnvironmentReturnsContainer() throws {
        let container = try DependencyContainer.make(for: .development)

        #expect(container.environment == .development)
    }

    @Test @MainActor func testMakeForProductionSetsProductionEnvironment() throws {
        let container = try DependencyContainer.make(for: .production)

        #expect(container.environment == .production)
    }

    @Test func testMakeForPreviewSetsPreviewEnvironment() throws {
        let container = try DependencyContainer.makeForPreview()

        #expect(container.environment == .preview)
    }

    @Test func testMakeForTestingSetsTestingEnvironment() throws {
        let container = try DependencyContainer.makeForTesting()

        #expect(container.environment == .testing)
    }

    // MARK: - Repository Injection Tests

    @Test func testMakeForTestingUsesDefaultEmptyRepositories() throws {
        let container = try DependencyContainer.makeForTesting()

        #expect(container.taskRepository is EmptyTaskRepository)
        #expect(container.spreadRepository is EmptySpreadRepository)
        #expect(container.eventRepository is EmptyEventRepository)
        #expect(container.noteRepository is EmptyNoteRepository)
        #expect(container.collectionRepository is EmptyCollectionRepository)
    }

    @Test func testMakeForTestingAcceptsCustomTaskRepository() throws {
        let customRepo = StubTaskRepository()
        let container = try DependencyContainer.makeForTesting(taskRepository: customRepo)

        #expect(container.taskRepository is StubTaskRepository)
    }

    @Test func testMakeForTestingAcceptsCustomSpreadRepository() throws {
        let customRepo = StubSpreadRepository()
        let container = try DependencyContainer.makeForTesting(spreadRepository: customRepo)

        #expect(container.spreadRepository is StubSpreadRepository)
    }

    @Test func testMakeForTestingAcceptsCustomEventRepository() throws {
        let customRepo = StubEventRepository()
        let container = try DependencyContainer.makeForTesting(eventRepository: customRepo)

        #expect(container.eventRepository is StubEventRepository)
    }

    @Test func testMakeForTestingAcceptsCustomNoteRepository() throws {
        let customRepo = StubNoteRepository()
        let container = try DependencyContainer.makeForTesting(noteRepository: customRepo)

        #expect(container.noteRepository is StubNoteRepository)
    }

    @Test func testMakeForTestingAcceptsCustomCollectionRepository() throws {
        let customRepo = StubCollectionRepository()
        let container = try DependencyContainer.makeForTesting(collectionRepository: customRepo)

        #expect(container.collectionRepository is StubCollectionRepository)
    }

    @Test func testMakeForTestingAcceptsAllCustomRepositories() throws {
        let container = try DependencyContainer.makeForTesting(
            taskRepository: StubTaskRepository(),
            spreadRepository: StubSpreadRepository(),
            eventRepository: StubEventRepository(),
            noteRepository: StubNoteRepository(),
            collectionRepository: StubCollectionRepository()
        )

        #expect(container.taskRepository is StubTaskRepository)
        #expect(container.spreadRepository is StubSpreadRepository)
        #expect(container.eventRepository is StubEventRepository)
        #expect(container.noteRepository is StubNoteRepository)
        #expect(container.collectionRepository is StubCollectionRepository)
    }

    // MARK: - Debug Summary Tests

    @Test func testDebugSummaryReturnsEnvironment() throws {
        let container = try DependencyContainer.makeForTesting()
        let summary = container.debugSummary

        #expect(summary.environment == "testing")
    }

    @Test func testDebugSummaryReturnsRepositoryTypes() throws {
        let container = try DependencyContainer.makeForTesting()
        let summary = container.debugSummary

        #expect(summary.taskRepositoryType == "EmptyTaskRepository")
        #expect(summary.spreadRepositoryType == "EmptySpreadRepository")
        #expect(summary.eventRepositoryType == "EmptyEventRepository")
        #expect(summary.noteRepositoryType == "EmptyNoteRepository")
        #expect(summary.collectionRepositoryType == "EmptyCollectionRepository")
    }

    @Test func testShortTypeNameRemovesRepositorySuffix() {
        let summary = DependencyContainerDebugInfo(
            environment: "testing",
            taskRepositoryType: "EmptyTaskRepository",
            spreadRepositoryType: "SwiftDataSpreadRepository",
            eventRepositoryType: "MockEventRepository",
            noteRepositoryType: "TestNoteRepository",
            collectionRepositoryType: "EmptyCollectionRepository"
        )

        #expect(summary.shortTypeName(for: summary.taskRepositoryType) == "EmptyTask")
        #expect(summary.shortTypeName(for: summary.spreadRepositoryType) == "SwiftDataSpread")
        #expect(summary.shortTypeName(for: summary.eventRepositoryType) == "MockEvent")
    }
}

// MARK: - Test Doubles

private struct StubTaskRepository: TaskRepository {
    func getTasks() async -> [DataModel.Task] { [] }
    func save(_ task: DataModel.Task) async throws {}
    func delete(_ task: DataModel.Task) async throws {}
}

private struct StubSpreadRepository: SpreadRepository {
    func getSpreads() async -> [DataModel.Spread] { [] }
    func save(_ spread: DataModel.Spread) async throws {}
    func delete(_ spread: DataModel.Spread) async throws {}
}

private struct StubEventRepository: EventRepository {
    func getEvents() async -> [DataModel.Event] { [] }
    func getEvents(from startDate: Date, to endDate: Date) async -> [DataModel.Event] { [] }
    func save(_ event: DataModel.Event) async throws {}
    func delete(_ event: DataModel.Event) async throws {}
}

private struct StubNoteRepository: NoteRepository {
    func getNotes() async -> [DataModel.Note] { [] }
    func save(_ note: DataModel.Note) async throws {}
    func delete(_ note: DataModel.Note) async throws {}
}

private struct StubCollectionRepository: CollectionRepository {
    func getCollections() async -> [DataModel.Collection] { [] }
    func save(_ collection: DataModel.Collection) async throws {}
    func delete(_ collection: DataModel.Collection) async throws {}
}
