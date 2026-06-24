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

    /// The preferred or range-start date for this entry, if any.
    ///
    /// `Task`/`Note` expose their own preferred `date` directly (`nil` means no
    /// preferred assignment); `DateRangeEntry` conformers (`Event`) default to `startDate`.
    var date: Date? { get }

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

/// A structural conformance layer between `Entry` and the SwiftData `@Model` classes
/// (`Task`, `Note`) that track a preferred date and assignment history.
///
/// `date` is satisfied directly via `Entry`. `period` stays off this protocol since
/// `Task.period: Period?` and `Note.period: Period` genuinely diverge in optionality —
/// nothing should dispatch over it polymorphically. `assignments` is declared here since
/// it's identical (`[Assignment]`) on both conformers and `JournalRuleEngine` (SPRD-248)
/// dispatches over it polymorphically for spread-matching logic shared by Task and Note.
/// This protocol also exists because the `@Model` macro's `PersistentModel`/`Hashable`
/// synthesis fails under this project's strict-concurrency build settings when `Task`/
/// `Note` conform directly to `Entry` — confirmed empirically; conforming through any
/// intermediate protocol (even an empty one) resolves it. `Event` doesn't need this
/// layer since it already conforms to `Entry` via `DateRangeEntry`.
protocol AssignableEntry: Entry {
    /// Assignment history for this entry across spreads.
    var assignments: [Assignment] { get set }
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
    var date: Date? { startDate }
}

protocol EntryStatusIconRepresentable {
    var baseShape: EntryStatusIcon.BaseShape { get }
}
