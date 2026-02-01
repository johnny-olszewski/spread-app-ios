import SwiftData
import struct Foundation.Calendar
import struct Foundation.Date

/// Central container for application dependencies.
///
/// Provides environment-specific configurations for repositories and services.
/// Use factory methods to create containers for different environments.
///
/// Example usage:
/// ```swift
/// let container = try DependencyContainer.make(for: .development)
/// let tasks = await container.taskRepository.getTasks()
/// ```
struct DependencyContainer: @unchecked Sendable {

    // MARK: - Properties

    /// The current application environment.
    let environment: AppEnvironment

    /// The SwiftData model container for persistence.
    let modelContainer: ModelContainer

    /// Repository for task persistence operations.
    let taskRepository: any TaskRepository

    /// Repository for spread persistence operations.
    let spreadRepository: any SpreadRepository

    /// Repository for event persistence operations.
    let eventRepository: any EventRepository

    /// Repository for note persistence operations.
    let noteRepository: any NoteRepository

    /// Repository for collection persistence operations.
    let collectionRepository: any CollectionRepository

    // MARK: - Factory Methods

    /// Creates a dependency container for the specified environment.
    ///
    /// - Parameter environment: The target application environment.
    /// - Returns: A configured dependency container.
    /// - Throws: An error if container creation fails.
    ///
    /// For production/development environments, creates SwiftData-backed repositories.
    /// For preview/testing, uses empty repositories for isolation.
    @MainActor
    static func make(for environment: AppEnvironment) throws -> DependencyContainer {
        let modelContainer = try ModelContainerFactory.make(for: environment)

        switch environment {
        case .live:
            return DependencyContainer(
                environment: environment,
                modelContainer: modelContainer,
                taskRepository: SwiftDataTaskRepository(modelContainer: modelContainer),
                spreadRepository: SwiftDataSpreadRepository(modelContainer: modelContainer),
                // TODO: SPRD-57 - Create SwiftDataEventRepository
                eventRepository: EmptyEventRepository(),
                // TODO: SPRD-58 - Create SwiftDataNoteRepository
                noteRepository: EmptyNoteRepository(),
                // TODO: SPRD-39 - Create SwiftDataCollectionRepository
                collectionRepository: EmptyCollectionRepository()
            )
        case .preview, .testing:
            return DependencyContainer(
                environment: environment,
                modelContainer: modelContainer,
                taskRepository: InMemoryTaskRepository(),
                spreadRepository: InMemorySpreadRepository(),
                eventRepository: InMemoryEventRepository(),
                noteRepository: InMemoryNoteRepository(),
                collectionRepository: EmptyCollectionRepository()
            )
        }
    }

    /// Creates a dependency container for testing with custom repositories.
    ///
    /// - Parameters:
    ///   - modelContainer: Optional custom model container. If nil, creates an in-memory container.
    ///   - taskRepository: Custom task repository implementation.
    ///   - spreadRepository: Custom spread repository implementation.
    ///   - eventRepository: Custom event repository implementation.
    ///   - noteRepository: Custom note repository implementation.
    ///   - collectionRepository: Custom collection repository implementation.
    /// - Returns: A configured dependency container for testing.
    /// - Throws: An error if model container creation fails.
    @MainActor
    static func makeForTesting(
        modelContainer: ModelContainer? = nil,
        taskRepository: (any TaskRepository)? = nil,
        spreadRepository: (any SpreadRepository)? = nil,
        eventRepository: (any EventRepository)? = nil,
        noteRepository: (any NoteRepository)? = nil,
        collectionRepository: (any CollectionRepository)? = nil
    ) throws -> DependencyContainer {
        let container = try modelContainer ?? ModelContainerFactory.makeForTesting()
        return DependencyContainer(
            environment: .testing,
            modelContainer: container,
            taskRepository: taskRepository ?? EmptyTaskRepository(),
            spreadRepository: spreadRepository ?? EmptySpreadRepository(),
            eventRepository: eventRepository ?? EmptyEventRepository(),
            noteRepository: noteRepository ?? EmptyNoteRepository(),
            collectionRepository: collectionRepository ?? EmptyCollectionRepository()
        )
    }

    /// Creates a dependency container for SwiftUI previews.
    ///
    /// Uses mock data seeded repositories for realistic preview content.
    /// - Returns: A configured dependency container for previews.
    /// - Throws: An error if model container creation fails.
    @MainActor
    static func makeForPreview() throws -> DependencyContainer {
        let modelContainer = try ModelContainerFactory.makeInMemory()
        return DependencyContainer(
            environment: .preview,
            modelContainer: modelContainer,
            taskRepository: MockTaskRepository(),
            spreadRepository: MockSpreadRepository(),
            // TODO: SPRD-57 - Create MockEventRepository with seeded data
            eventRepository: EmptyEventRepository(),
            // TODO: SPRD-58 - Create MockNoteRepository with seeded data
            noteRepository: EmptyNoteRepository(),
            // TODO: SPRD-39 - Create MockCollectionRepository with seeded data
            collectionRepository: EmptyCollectionRepository()
        )
    }

    // MARK: - Service Factory Methods

    /// Creates a JournalManager configured with this container's repositories.
    ///
    /// - Parameters:
    ///   - calendar: The calendar for date calculations (defaults to current).
    ///   - today: The current date (defaults to now).
    ///   - bujoMode: The initial BuJo mode (defaults to conventional).
    /// - Returns: A configured JournalManager with data loaded.
    func makeJournalManager(
        calendar: Calendar = .current,
        today: Date = .now,
        bujoMode: BujoMode = .conventional
    ) async throws -> JournalManager {
        try await JournalManager.makeForTesting(
            calendar: calendar,
            today: today,
            taskRepository: taskRepository,
            spreadRepository: spreadRepository,
            eventRepository: eventRepository,
            noteRepository: noteRepository,
            bujoMode: bujoMode
        )
    }
}

// MARK: - Debug Information

extension DependencyContainer {
    /// A summary of the container configuration for debugging.
    var debugSummary: DependencyContainerDebugInfo {
        DependencyContainerDebugInfo(
            environment: environment.rawValue,
            taskRepositoryType: String(describing: type(of: taskRepository)),
            spreadRepositoryType: String(describing: type(of: spreadRepository)),
            eventRepositoryType: String(describing: type(of: eventRepository)),
            noteRepositoryType: String(describing: type(of: noteRepository)),
            collectionRepositoryType: String(describing: type(of: collectionRepository))
        )
    }
}

/// Debug information about a DependencyContainer's configuration.
struct DependencyContainerDebugInfo: Sendable {
    let environment: String
    let taskRepositoryType: String
    let spreadRepositoryType: String
    let eventRepositoryType: String
    let noteRepositoryType: String
    let collectionRepositoryType: String

    /// Simplified repository type name (removes "Repository" suffix for display).
    func shortTypeName(for fullName: String) -> String {
        fullName.replacingOccurrences(of: "Repository", with: "")
    }
}
