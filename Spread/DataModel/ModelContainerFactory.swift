import SwiftData

/// Factory for creating ModelContainer instances.
///
/// Provides environment-specific configurations for SwiftData persistence.
/// Use the appropriate factory method based on the target environment.
enum ModelContainerFactory {

    // MARK: - Factory Methods

    /// Creates a persistent ModelContainer for live app use.
    ///
    /// Uses a single container name for all data environments.
    static func makePersistent() throws -> ModelContainer {
        let schema = Schema(versionedSchema: DataModelSchemaV1.self)
        let configuration = ModelConfiguration(
            "Spread",
            schema: schema,
            isStoredInMemoryOnly: false
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: DataModelMigrationPlan.self,
            configurations: [configuration]
        )
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

}
