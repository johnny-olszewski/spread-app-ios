import Foundation
import SwiftUI

/// A journal entry with a unique identity and creation timestamp.
///
/// Entry is the parent protocol for all journal items: tasks, events, and notes.
/// Each entry type has distinct behavior around assignments and visibility.
protocol Entry: Identifiable, Hashable, EntryStatusIconRepresentable {
    /// Unique identifier for the entry.
    var id: UUID { get }

    /// The title of the entry.
    var title: String { get set }

    /// The date this entry was created.
    var createdDate: Date { get }

    /// The type of entry (task, event, or note).
    var entryType: EntryType { get }

    /// Whether this entry type can ever appear in the Inbox.
    ///
    /// A static per-type constant — independent of this instance's `date`/`status`/assignments.
    /// Per-instance Inbox membership still requires checking status and assignment state
    /// separately wherever a feature needs it.
    var isInboxEligible: Bool { get }

    /// Whether this entry type can ever be migrated between spreads.
    ///
    /// A static per-type constant — independent of this instance's `date`/`status`/assignments.
    var isMigratable: Bool { get }

    /// Whether this entry type can ever be flagged overdue.
    ///
    /// A static per-type constant — independent of this instance's `date`/`status`/assignments.
    var isOverdueEligible: Bool { get }

    // MARK: - Display requirements (default implementations in extension below)

    /// Optional one-line body preview shown below the title.
    var displayBodyPreview: String? { get }

    /// Display-only task priority.
    var displayPriority: DataModel.Task.Priority { get }

    var status: EntryStatus { get }

    /// The date used to chronologically order this entry within a section.
    var sortDate: Date { get }
}

extension Entry {
    var iconColor: Color? { nil }
    var displayBodyPreview: String? { nil }
    var displayPriority: DataModel.Task.Priority { .none }
    var isInboxEligible: Bool { false }
    var isMigratable: Bool { false }
    var isOverdueEligible: Bool { false }

    /// A stable key identifying this concrete type for use in `EntryRowView.Configuration.Map`.
    ///
    /// Uses `ObjectIdentifier` over the `EntryType` enum so new `Entry` conformers are
    /// automatically keyed without touching the enum. Call sites use `DataModel.Task.configurationKey`
    /// etc. to build maps, and `EntryListView` looks up via `ObjectIdentifier(type(of: entry))`.
    static var configurationKey: ObjectIdentifier { ObjectIdentifier(Self.self) }
}

/// An entry that can be assigned to spreads.
///
/// Assignable entries (tasks and notes) track their preferred date and period,
/// and maintain assignment history across spreads via the shared `Assignment` type.
protocol AssignableEntry: Entry {
    /// The preferred date for this entry.
    var date: Date { get set }

    /// The preferred period for this entry.
    var period: Period { get set }

    /// Assignment history for this entry across spreads.
    var assignments: [Assignment] { get set }
}

extension AssignableEntry {
    var sortDate: Date { date }
}

/// An entry whose visibility is computed from date range overlap.
///
/// Date range entries (events) do not have assignments. Instead, their
/// visibility on a spread is computed by checking if their date range
/// overlaps with the spread's time period.
protocol DateRangeEntry: Entry {
    /// The start date of this entry's range.
    var startDate: Date { get }

    /// The end date of this entry's range.
    var endDate: Date { get }

    /// Determines whether this entry appears on a spread.
    ///
    /// - Parameters:
    ///   - period: The spread's time period.
    ///   - date: The spread's normalized date.
    ///   - calendar: The calendar to use for date calculations.
    /// - Returns: `true` if this entry's date range overlaps with the spread.
    func appearsOn(period: Period, date: Date, calendar: Calendar) -> Bool
}

extension DateRangeEntry {
    var sortDate: Date { startDate }
}

protocol EntryStatusIconRepresentable {
    var baseShape: EntryStatusIcon.BaseShape { get }
}
