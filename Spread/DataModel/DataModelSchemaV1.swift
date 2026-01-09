import SwiftData
import struct Foundation.Calendar
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
    /// Spreads can represent year, month, day, or multiday ranges. For multiday
    /// spreads, `startDate` and `endDate` define the custom range.
    @Model
    final class Spread {
        /// Unique identifier for the spread.
        @Attribute(.unique) var id: UUID

        /// The time period for this spread.
        var period: Period

        /// The normalized date for this spread.
        ///
        /// For year/month/day periods, this is the first day of that period.
        /// For multiday, this equals `startDate`.
        var date: Date

        /// The start date for multiday spreads.
        ///
        /// Only set when `period` is `.multiday`, otherwise `nil`.
        var startDate: Date?

        /// The end date for multiday spreads.
        ///
        /// Only set when `period` is `.multiday`, otherwise `nil`.
        var endDate: Date?

        /// The date this spread was created.
        var createdDate: Date

        /// Creates a spread for a year, month, or day period.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - period: The time period (must not be `.multiday`).
        ///   - date: The date within the period (will be normalized).
        ///   - calendar: The calendar to use for date normalization.
        ///   - createdDate: When the spread was created (defaults to now).
        init(
            id: UUID = UUID(),
            period: Period,
            date: Date,
            calendar: Calendar,
            createdDate: Date = .now
        ) {
            self.id = id
            self.period = period
            self.date = period.normalizeDate(date, calendar: calendar)
            self.startDate = nil
            self.endDate = nil
            self.createdDate = createdDate
        }

        /// Creates a multiday spread with a custom date range.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - startDate: The first day of the range.
        ///   - endDate: The last day of the range.
        ///   - calendar: The calendar to use for date normalization.
        ///   - createdDate: When the spread was created (defaults to now).
        init(
            id: UUID = UUID(),
            startDate: Date,
            endDate: Date,
            calendar: Calendar,
            createdDate: Date = .now
        ) {
            self.id = id
            self.period = .multiday
            self.date = startDate.startOfDay(calendar: calendar)
            self.startDate = startDate.startOfDay(calendar: calendar)
            self.endDate = endDate.startOfDay(calendar: calendar)
            self.createdDate = createdDate
        }

        /// Creates a multiday spread from a preset.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - preset: The multiday preset to use.
        ///   - today: The reference date for preset calculation.
        ///   - calendar: The calendar to use for calculations.
        ///   - firstWeekday: The user's first day of week preference.
        ///   - createdDate: When the spread was created (defaults to now).
        /// - Returns: A new spread, or `nil` if the preset calculation fails.
        init?(
            id: UUID = UUID(),
            preset: MultidayPreset,
            today: Date,
            calendar: Calendar,
            firstWeekday: FirstWeekday,
            createdDate: Date = .now
        ) {
            guard let range = preset.dateRange(from: today, calendar: calendar, firstWeekday: firstWeekday) else {
                return nil
            }
            self.id = id
            self.period = .multiday
            self.date = range.startDate
            self.startDate = range.startDate
            self.endDate = range.endDate
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
