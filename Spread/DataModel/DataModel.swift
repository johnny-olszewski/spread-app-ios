/// Namespace for data model types.
///
/// All SwiftData @Model classes are defined in `DataModelSchemaV1` and
/// aliased here for convenient access (e.g., `DataModel.Task`, `DataModel.Spread`).
enum DataModel {
    /// A journaling page tied to a time period and normalized date.
    typealias Spread = DataModelSchemaV1.Spread

    /// An assignable entry with status and migration history.
    typealias Task = DataModelSchemaV1.Task

    /// A date-range entry that appears on overlapping spreads.
    typealias Event = DataModelSchemaV1.Event

    /// An assignable entry with explicit-only migration.
    typealias Note = DataModelSchemaV1.Note

    /// A plain text page for collections.
    /// Full implementation in SPRD-39.
    typealias Collection = DataModelSchemaV1.Collection
}
