import SwiftData

/// Factory for creating ModelContainer instances.
///
/// Provides environment-specific configurations for SwiftData persistence.
/// Use the appropriate factory method based on the target environment.
enum ModelContainerFactory {

    // MARK: - Factory Methods

    /// Creates a ModelContainer for the specified environment.
    ///
    /// - Parameter environment: The target application environment.
    /// - Returns: A configured ModelContainer.
    /// - Throws: An error if container creation fails.
    static func make(for environment: AppEnvironment) throws -> ModelContainer {
        switch environment {
        case .production:
            return try makeProduction()
        case .development:
            return try makeDevelopment()
        case .preview:
            return try makeInMemory()
        case .testing:
            return try makeInMemory()
        }
    }

    /// Creates an in-memory ModelContainer for testing and previews.
    ///
    /// Data is not persisted to disk and is lost when the container is deallocated.
    /// - Returns: An in-memory ModelContainer.
    /// - Throws: An error if container creation fails.
    static func makeInMemory() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DataModelSchemaV1.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: DataModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Creates a ModelContainer for testing with isolated storage.
    ///
    /// Equivalent to `makeInMemory()` but with explicit testing semantics.
    /// - Returns: A test ModelContainer.
    /// - Throws: An error if container creation fails.
    static func makeForTesting() throws -> ModelContainer {
        try makeInMemory()
    }

    // MARK: - Private Factory Methods

    /// Creates a ModelContainer for production use.
    ///
    /// Uses persistent storage with CloudKit sync (TODO: SPRD-42).
    private static func makeProduction() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DataModelSchemaV1.self)
        let configuration = ModelConfiguration(
            AppEnvironment.production.containerName,
            schema: schema,
            isStoredInMemoryOnly: false
            // TODO: SPRD-42 - Add CloudKit configuration
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: DataModelMigrationPlan.self,
            configurations: [configuration]
        )
    }

    /// Creates a ModelContainer for development use.
    ///
    /// Uses persistent storage with a separate container name from production.
    private static func makeDevelopment() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DataModelSchemaV1.self)
        let configuration = ModelConfiguration(
            AppEnvironment.development.containerName,
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: DataModelMigrationPlan.self,
            configurations: [configuration]
        )
    }
}
