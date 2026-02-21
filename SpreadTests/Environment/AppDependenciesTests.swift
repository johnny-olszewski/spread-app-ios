import Foundation
import Testing
@testable import Spread

@MainActor
struct AppDependenciesTests {

    // MARK: - Factory Method Tests

    /// Conditions: Create dependencies using live factory method.
    /// Expected: Dependencies should have "live" configuration label and persistent storage.
    @Test @MainActor func testMakeForLiveSetsLiveConfiguration() throws {
        let dependencies = try AppDependencies.makeForLive()

        #expect(dependencies.configurationLabel == "live")
        #expect(dependencies.isStoredInMemoryOnly == false)
    }

    /// Conditions: Create dependencies using preview factory method.
    /// Expected: Dependencies should have "preview" configuration label and in-memory storage.
    @Test @MainActor func testMakeForPreviewSetsPreviewConfiguration() throws {
        let dependencies = try AppDependencies.makeForPreview()

        #expect(dependencies.configurationLabel == "preview")
        #expect(dependencies.isStoredInMemoryOnly == true)
    }

    /// Conditions: Create dependencies using testing factory method.
    /// Expected: Dependencies should have "testing" configuration label and in-memory storage.
    @Test func testMakeForTestingSetsTestingConfiguration() throws {
        let dependencies = try AppDependencies.make()

        #expect(dependencies.configurationLabel == "testing")
        #expect(dependencies.isStoredInMemoryOnly == true)
    }

    // MARK: - Repository Injection Tests

    /// Conditions: Create testing dependencies with no custom repositories.
    /// Expected: Should use empty repository implementations for all repositories.
    @Test func testMakeForTestingUsesDefaultEmptyRepositories() throws {
        let dependencies = try AppDependencies.make()

        #expect(dependencies.taskRepository is EmptyTaskRepository)
        #expect(dependencies.spreadRepository is EmptySpreadRepository)
        #expect(dependencies.eventRepository is EmptyEventRepository)
        #expect(dependencies.noteRepository is EmptyNoteRepository)
        #expect(dependencies.collectionRepository is EmptyCollectionRepository)
        #expect(dependencies.settingsRepository is EmptySettingsRepository)
    }

    /// Conditions: Create testing dependencies with custom task repository.
    /// Expected: Dependencies should use the injected task repository.
    @Test func testMakeForTestingAcceptsCustomTaskRepository() throws {
        let customRepo = StubTaskRepository()
        let dependencies = try AppDependencies.make(taskRepository: customRepo)

        #expect(dependencies.taskRepository is StubTaskRepository)
    }

    /// Conditions: Create testing dependencies with custom spread repository.
    /// Expected: Dependencies should use the injected spread repository.
    @Test func testMakeForTestingAcceptsCustomSpreadRepository() throws {
        let customRepo = StubSpreadRepository()
        let dependencies = try AppDependencies.make(spreadRepository: customRepo)

        #expect(dependencies.spreadRepository is StubSpreadRepository)
    }

    /// Conditions: Create testing dependencies with custom event repository.
    /// Expected: Dependencies should use the injected event repository.
    @Test func testMakeForTestingAcceptsCustomEventRepository() throws {
        let customRepo = StubEventRepository()
        let dependencies = try AppDependencies.make(eventRepository: customRepo)

        #expect(dependencies.eventRepository is StubEventRepository)
    }

    /// Conditions: Create testing dependencies with custom note repository.
    /// Expected: Dependencies should use the injected note repository.
    @Test func testMakeForTestingAcceptsCustomNoteRepository() throws {
        let customRepo = StubNoteRepository()
        let dependencies = try AppDependencies.make(noteRepository: customRepo)

        #expect(dependencies.noteRepository is StubNoteRepository)
    }

    /// Conditions: Create testing dependencies with custom collection repository.
    /// Expected: Dependencies should use the injected collection repository.
    @Test func testMakeForTestingAcceptsCustomCollectionRepository() throws {
        let customRepo = StubCollectionRepository()
        let dependencies = try AppDependencies.make(collectionRepository: customRepo)

        #expect(dependencies.collectionRepository is StubCollectionRepository)
    }

    /// Conditions: Create testing dependencies with all custom repositories.
    /// Expected: Dependencies should use all injected repositories.
    @Test func testMakeForTestingAcceptsAllCustomRepositories() throws {
        let dependencies = try AppDependencies.make(
            taskRepository: StubTaskRepository(),
            spreadRepository: StubSpreadRepository(),
            eventRepository: StubEventRepository(),
            noteRepository: StubNoteRepository(),
            collectionRepository: StubCollectionRepository()
        )

        #expect(dependencies.taskRepository is StubTaskRepository)
        #expect(dependencies.spreadRepository is StubSpreadRepository)
        #expect(dependencies.eventRepository is StubEventRepository)
        #expect(dependencies.noteRepository is StubNoteRepository)
        #expect(dependencies.collectionRepository is StubCollectionRepository)
    }

    // MARK: - Debug Summary Tests

    /// Conditions: Create testing dependencies and access debug summary.
    /// Expected: Debug summary should report "testing" environment.
    @Test func testDebugSummaryReturnsEnvironment() throws {
        let dependencies = try AppDependencies.make()
        let summary = dependencies.debugSummary

        #expect(summary.environment == "testing")
    }

    /// Conditions: Create testing dependencies with default repositories.
    /// Expected: Debug summary should report Empty repository types.
    @Test func testDebugSummaryReturnsRepositoryTypes() throws {
        let dependencies = try AppDependencies.make()
        let summary = dependencies.debugSummary

        #expect(summary.taskRepositoryType == "EmptyTaskRepository")
        #expect(summary.spreadRepositoryType == "EmptySpreadRepository")
        #expect(summary.eventRepositoryType == "EmptyEventRepository")
        #expect(summary.noteRepositoryType == "EmptyNoteRepository")
        #expect(summary.collectionRepositoryType == "EmptyCollectionRepository")
        #expect(summary.settingsRepositoryType == "EmptySettingsRepository")
    }

    /// Conditions: Debug info with various repository type names.
    /// Expected: shortTypeName should strip "Repository" suffix from type names.
    @Test func testShortTypeNameRemovesRepositorySuffix() {
        let summary = AppDependenciesDebugInfo(
            environment: "testing",
            taskRepositoryType: "EmptyTaskRepository",
            spreadRepositoryType: "SwiftDataSpreadRepository",
            eventRepositoryType: "MockEventRepository",
            noteRepositoryType: "TestNoteRepository",
            collectionRepositoryType: "EmptyCollectionRepository",
            settingsRepositoryType: "EmptySettingsRepository"
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
