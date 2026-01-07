import SwiftData
import struct Foundation.Date
import struct Foundation.UUID

/// Version 1.0.0 of the data model schema.
///
/// Contains all @Model classes for the Spread app. Future schema versions
/// will be added as separate VersionedSchema types with migration stages.
enum DataModelSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version {
        Schema.Version(1, 0, 0)
    }

    static var models: [any PersistentModel.Type] {
        [
            Spread.self,
            Task.self,
            Event.self,
            Note.self,
            Collection.self
        ]
    }

    // MARK: - Spread Model

    /// A journaling page tied to a time period and normalized date.
    ///
    /// Full implementation with Period enum and date normalization in SPRD-8.
    @Model
    final class Spread {
        /// Unique identifier for the spread.
        @Attribute(.unique) var id: UUID

        /// The date this spread was created.
        var createdDate: Date

        init(id: UUID = UUID(), createdDate: Date = .now) {
            self.id = id
            self.createdDate = createdDate
        }
    }

    // MARK: - Task Model

    /// An assignable entry with status and migration history.
    ///
    /// Full implementation with Entry protocol conformance, status enum,
    /// and TaskAssignment array in SPRD-9.
    @Model
    final class Task {
        /// Unique identifier for the task.
        @Attribute(.unique) var id: UUID

        /// The title of the task.
        var title: String

        /// The date this task was created.
        var createdDate: Date

        init(id: UUID = UUID(), title: String = "", createdDate: Date = .now) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
        }
    }

    // MARK: - Event Model

    /// A date-range entry that appears on overlapping spreads.
    ///
    /// Full implementation with EventTiming enum and date range properties in SPRD-9.
    @Model
    final class Event {
        /// Unique identifier for the event.
        @Attribute(.unique) var id: UUID

        /// The title of the event.
        var title: String

        /// The date this event was created.
        var createdDate: Date

        init(id: UUID = UUID(), title: String = "", createdDate: Date = .now) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
        }
    }

    // MARK: - Note Model

    /// An assignable entry with explicit-only migration.
    ///
    /// Full implementation with content field and NoteAssignment array in SPRD-9.
    @Model
    final class Note {
        /// Unique identifier for the note.
        @Attribute(.unique) var id: UUID

        /// The title of the note.
        var title: String

        /// The date this note was created.
        var createdDate: Date

        init(id: UUID = UUID(), title: String = "", createdDate: Date = .now) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
        }
    }

    // MARK: - Collection Model

    /// A plain text page for collections.
    ///
    /// Full implementation with content field and modifiedDate in SPRD-39.
    @Model
    final class Collection {
        /// Unique identifier for the collection.
        @Attribute(.unique) var id: UUID

        /// The title of the collection.
        var title: String

        /// The date this collection was created.
        var createdDate: Date

        init(id: UUID = UUID(), title: String = "", createdDate: Date = .now) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
        }
    }
}
