import Foundation
import Testing
@testable import Spread

@MainActor
struct DependencyContainerTests {

    // MARK: - Factory Method Tests

    /// Conditions: Create container using live factory method.
    /// Expected: Container should have "live" configuration label and persistent storage.
    @Test @MainActor func testMakeForLiveSetsLiveConfiguration() throws {
        let container = try DependencyContainer.makeForLive()

        #expect(container.configurationLabel == "live")
        #expect(container.isStoredInMemoryOnly == false)
    }

    /// Conditions: Create container using preview factory method.
    /// Expected: Container should have "preview" configuration label and in-memory storage.
    @Test @MainActor func testMakeForPreviewSetsPreviewConfiguration() throws {
        let container = try DependencyContainer.makeForPreview()

        #expect(container.configurationLabel == "preview")
        #expect(container.isStoredInMemoryOnly == true)
    }

    /// Conditions: Create container using testing factory method.
    /// Expected: Container should have "testing" configuration label and in-memory storage.
    @Test func testMakeForTestingSetsTestingConfiguration() throws {
        let container = try DependencyContainer.makeForTesting()

        #expect(container.configurationLabel == "testing")
        #expect(container.isStoredInMemoryOnly == true)
    }

    // MARK: - Repository Injection Tests

    /// Conditions: Create testing container with no custom repositories.
    /// Expected: Should use empty repository implementations for all repositories.
    @Test func testMakeForTestingUsesDefaultEmptyRepositories() throws {
        let container = try DependencyContainer.makeForTesting()

        #expect(container.taskRepository is EmptyTaskRepository)
        #expect(container.spreadRepository is EmptySpreadRepository)
        #expect(container.eventRepository is EmptyEventRepository)
        #expect(container.noteRepository is EmptyNoteRepository)
        #expect(container.collectionRepository is EmptyCollectionRepository)
    }

    /// Conditions: Create testing container with custom task repository.
    /// Expected: Container should use the injected task repository.
    @Test func testMakeForTestingAcceptsCustomTaskRepository() throws {
        let customRepo = StubTaskRepository()
        let container = try DependencyContainer.makeForTesting(taskRepository: customRepo)

        #expect(container.taskRepository is StubTaskRepository)
    }

    /// Conditions: Create testing container with custom spread repository.
    /// Expected: Container should use the injected spread repository.
    @Test func testMakeForTestingAcceptsCustomSpreadRepository() throws {
        let customRepo = StubSpreadRepository()
        let container = try DependencyContainer.makeForTesting(spreadRepository: customRepo)

        #expect(container.spreadRepository is StubSpreadRepository)
    }

    /// Conditions: Create testing container with custom event repository.
    /// Expected: Container should use the injected event repository.
    @Test func testMakeForTestingAcceptsCustomEventRepository() throws {
        let customRepo = StubEventRepository()
        let container = try DependencyContainer.makeForTesting(eventRepository: customRepo)

        #expect(container.eventRepository is StubEventRepository)
    }

    /// Conditions: Create testing container with custom note repository.
    /// Expected: Container should use the injected note repository.
    @Test func testMakeForTestingAcceptsCustomNoteRepository() throws {
        let customRepo = StubNoteRepository()
        let container = try DependencyContainer.makeForTesting(noteRepository: customRepo)

        #expect(container.noteRepository is StubNoteRepository)
    }

    /// Conditions: Create testing container with custom collection repository.
    /// Expected: Container should use the injected collection repository.
    @Test func testMakeForTestingAcceptsCustomCollectionRepository() throws {
        let customRepo = StubCollectionRepository()
        let container = try DependencyContainer.makeForTesting(collectionRepository: customRepo)

        #expect(container.collectionRepository is StubCollectionRepository)
    }

    /// Conditions: Create testing container with all custom repositories.
    /// Expected: Container should use all injected repositories.
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

    /// Conditions: Create testing container and access debug summary.
    /// Expected: Debug summary should report "testing" environment.
    @Test func testDebugSummaryReturnsEnvironment() throws {
        let container = try DependencyContainer.makeForTesting()
        let summary = container.debugSummary

        #expect(summary.environment == "testing")
    }

    /// Conditions: Create testing container with default repositories.
    /// Expected: Debug summary should report Empty repository types.
    @Test func testDebugSummaryReturnsRepositoryTypes() throws {
        let container = try DependencyContainer.makeForTesting()
        let summary = container.debugSummary

        #expect(summary.taskRepositoryType == "EmptyTaskRepository")
        #expect(summary.spreadRepositoryType == "EmptySpreadRepository")
        #expect(summary.eventRepositoryType == "EmptyEventRepository")
        #expect(summary.noteRepositoryType == "EmptyNoteRepository")
        #expect(summary.collectionRepositoryType == "EmptyCollectionRepository")
    }

    /// Conditions: Debug info with various repository type names.
    /// Expected: shortTypeName should strip "Repository" suffix from type names.
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
