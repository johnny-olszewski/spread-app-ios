import Foundation
import SwiftData

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
            Collection.self,
            SyncMutation.self,
            SyncCursor.self
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
    /// Tasks track their preferred date and period for assignment purposes.
    /// Assignment history is tracked via TaskAssignment (SPRD-10).
    @Model
    final class Task: AssignableEntry {
        /// The status of a task on a spread.
        enum Status: String, CaseIterable, Codable, Sendable {
            /// Task is open and not yet completed.
            case open

            /// Task has been completed.
            case complete

            /// Task has been migrated to another spread.
            case migrated

            /// Task has been cancelled and hidden from default views.
            case cancelled
        }

        /// Unique identifier for the task.
        @Attribute(.unique) var id: UUID

        /// The title of the task.
        var title: String

        /// The date this task was created.
        var createdDate: Date

        /// The preferred date for this task.
        var date: Date

        /// The preferred period for this task.
        var period: Period

        /// The current status of the task.
        var status: Status

        /// Assignment history for this task across spreads.
        var assignments: [TaskAssignment]

        /// The type of entry.
        var entryType: EntryType { .task }

        /// Creates a new task.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - title: The task title.
        ///   - createdDate: When the task was created (defaults to now).
        ///   - date: The preferred date (defaults to now).
        ///   - period: The preferred period (defaults to `.day`).
        ///   - status: The task status (defaults to `.open`).
        ///   - assignments: Assignment history (defaults to empty).
        init(
            id: UUID = UUID(),
            title: String = "",
            createdDate: Date = .now,
            date: Date = .now,
            period: Period = .day,
            status: Status = .open,
            assignments: [TaskAssignment] = []
        ) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
            self.date = date
            self.period = period
            self.status = status
            self.assignments = assignments
        }
    }

    // MARK: - Event Model

    /// A date-range entry that appears on overlapping spreads.
    ///
    /// Events do not have assignments. Their visibility on a spread is computed
    /// by checking if their date range overlaps with the spread's time period.
    @Model
    final class Event: DateRangeEntry {
        /// Unique identifier for the event.
        @Attribute(.unique) var id: UUID

        /// The title of the event.
        var title: String

        /// The date this event was created.
        var createdDate: Date

        /// The timing mode for this event.
        var timing: EventTiming

        /// The start date of this event.
        var startDate: Date

        /// The end date of this event.
        var endDate: Date

        /// The start time for timed events.
        ///
        /// Only set when `timing` is `.timed`, otherwise `nil`.
        var startTime: Date?

        /// The end time for timed events.
        ///
        /// Only set when `timing` is `.timed`, otherwise `nil`.
        var endTime: Date?

        /// The type of entry.
        var entryType: EntryType { .event }

        /// Creates a new event.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - title: The event title.
        ///   - createdDate: When the event was created (defaults to now).
        ///   - timing: The timing mode (defaults to `.singleDay`).
        ///   - startDate: The start date of the event.
        ///   - endDate: The end date of the event.
        ///   - startTime: The start time for timed events.
        ///   - endTime: The end time for timed events.
        init(
            id: UUID = UUID(),
            title: String = "",
            createdDate: Date = .now,
            timing: EventTiming = .singleDay,
            startDate: Date = .now,
            endDate: Date = .now,
            startTime: Date? = nil,
            endTime: Date? = nil
        ) {
            self.id = id
            self.title = title
            self.createdDate = createdDate
            self.timing = timing
            self.startDate = startDate
            self.endDate = endDate
            self.startTime = startTime
            self.endTime = endTime
        }

        /// Determines whether this event appears on a spread.
        ///
        /// An event appears on a spread if its date range overlaps with the
        /// spread's time period. The overlap is determined by normalizing dates
        /// to the spread's period and checking for intersection.
        ///
        /// - Parameters:
        ///   - period: The spread's time period.
        ///   - date: The spread's normalized date.
        ///   - calendar: The calendar to use for date calculations.
        /// - Returns: `true` if this event's date range overlaps with the spread.
        func appearsOn(period: Period, date: Date, calendar: Calendar) -> Bool {
            guard let component = period.calendarComponent else {
                // Multiday spread: check if event overlaps with the custom range
                // For multiday, `date` is the start date; we need the end date separately
                // This is handled by the caller providing the appropriate range
                return true
            }

            // Get the spread's date range for the period
            guard let spreadEnd = calendar.date(
                byAdding: component,
                value: 1,
                to: date
            ) else {
                return false
            }

            // Check for overlap: event range intersects spread range
            // Event is [startDate, endDate], Spread is [date, spreadEnd)
            // Overlap exists if eventStart < spreadEnd AND eventEnd >= spreadStart
            let eventStart = startDate.startOfDay(calendar: calendar)
            let eventEnd = endDate.startOfDay(calendar: calendar)
            let spreadStart = date

            return eventStart < spreadEnd && eventEnd >= spreadStart
        }
    }

    // MARK: - Note Model

    /// An assignable entry with explicit-only migration.
    ///
    /// Notes can have extended content and track their preferred date and period.
    /// Assignment history is tracked via NoteAssignment (SPRD-10).
    /// Notes only migrate when explicitly triggered by the user.
    @Model
    final class Note: AssignableEntry {
        /// The status of a note on a spread.
        enum Status: String, CaseIterable, Codable, Sendable {
            /// Note is active on the spread.
            case active

            /// Note has been migrated to another spread.
            case migrated
        }

        /// Unique identifier for the note.
        @Attribute(.unique) var id: UUID

        /// The title of the note.
        var title: String

        /// The extended content of the note.
        var content: String

        /// The date this note was created.
        var createdDate: Date

        /// The preferred date for this note.
        var date: Date

        /// The preferred period for this note.
        var period: Period

        /// The current status of the note.
        var status: Status

        /// Assignment history for this note across spreads.
        var assignments: [NoteAssignment]

        /// The type of entry.
        var entryType: EntryType { .note }

        /// Creates a new note.
        ///
        /// - Parameters:
        ///   - id: Unique identifier (defaults to new UUID).
        ///   - title: The note title.
        ///   - content: The extended content (defaults to empty string).
        ///   - createdDate: When the note was created (defaults to now).
        ///   - date: The preferred date (defaults to now).
        ///   - period: The preferred period (defaults to `.day`).
        ///   - status: The note status (defaults to `.active`).
        ///   - assignments: Assignment history (defaults to empty).
        init(
            id: UUID = UUID(),
            title: String = "",
            content: String = "",
            createdDate: Date = .now,
            date: Date = .now,
            period: Period = .day,
            status: Status = .active,
            assignments: [NoteAssignment] = []
        ) {
            self.id = id
            self.title = title
            self.content = content
            self.createdDate = createdDate
            self.date = date
            self.period = period
            self.status = status
            self.assignments = assignments
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
