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
struct DependencyContainer: Sendable {

    // MARK: - Properties

    /// The current application environment.
    let environment: AppEnvironment

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
    /// For production/development environments, this will create SwiftData-backed
    /// repositories (TODO: SPRD-5). For preview/testing, uses empty repositories.
    static func make(for environment: AppEnvironment) throws -> DependencyContainer {
        // TODO: SPRD-4, SPRD-5 - Create ModelContainer and SwiftData repositories
        // For now, use empty repositories for all environments
        DependencyContainer(
            environment: environment,
            taskRepository: EmptyTaskRepository(),
            spreadRepository: EmptySpreadRepository(),
            eventRepository: EmptyEventRepository(),
            noteRepository: EmptyNoteRepository(),
            collectionRepository: EmptyCollectionRepository()
        )
    }

    /// Creates a dependency container for testing with custom repositories.
    ///
    /// - Parameters:
    ///   - taskRepository: Custom task repository implementation.
    ///   - spreadRepository: Custom spread repository implementation.
    ///   - eventRepository: Custom event repository implementation.
    ///   - noteRepository: Custom note repository implementation.
    ///   - collectionRepository: Custom collection repository implementation.
    /// - Returns: A configured dependency container for testing.
    static func makeForTesting(
        taskRepository: any TaskRepository = EmptyTaskRepository(),
        spreadRepository: any SpreadRepository = EmptySpreadRepository(),
        eventRepository: any EventRepository = EmptyEventRepository(),
        noteRepository: any NoteRepository = EmptyNoteRepository(),
        collectionRepository: any CollectionRepository = EmptyCollectionRepository()
    ) -> DependencyContainer {
        DependencyContainer(
            environment: .testing,
            taskRepository: taskRepository,
            spreadRepository: spreadRepository,
            eventRepository: eventRepository,
            noteRepository: noteRepository,
            collectionRepository: collectionRepository
        )
    }

    /// Creates a dependency container for SwiftUI previews.
    ///
    /// Uses mock data seeded repositories for realistic preview content.
    /// - Returns: A configured dependency container for previews.
    static func makeForPreview() -> DependencyContainer {
        // TODO: SPRD-6 - Use mock repositories with seeded data
        DependencyContainer(
            environment: .preview,
            taskRepository: EmptyTaskRepository(),
            spreadRepository: EmptySpreadRepository(),
            eventRepository: EmptyEventRepository(),
            noteRepository: EmptyNoteRepository(),
            collectionRepository: EmptyCollectionRepository()
        )
    }

    // MARK: - Service Factory Methods

    // TODO: SPRD-11 - Add makeJournalManager when JournalManager is implemented
    // func makeJournalManager(
    //     calendar: Calendar = .current,
    //     today: Date = .now,
    //     bujoMode: DataModel.BujoMode = .conventional
    // ) -> JournalManager
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
