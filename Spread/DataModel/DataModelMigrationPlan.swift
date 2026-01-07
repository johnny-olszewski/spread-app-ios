import SwiftData

/// Migration plan for the data model schema.
///
/// Defines the migration path between schema versions. Currently empty
/// as we only have V1. Future migrations will be added as new schema
/// versions are created.
enum DataModelMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [DataModelSchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // No migrations yet - will be added when DataModelSchemaV2 is created
        []
    }
}
