import Foundation

/// A journal entry with a unique identity and creation timestamp.
///
/// Entry is the parent protocol for all journal items: tasks, events, and notes.
/// Each entry type has distinct behavior around assignments and visibility.
protocol Entry: Identifiable, Hashable {
    /// Unique identifier for the entry.
    var id: UUID { get }

    /// The title of the entry.
    var title: String { get set }

    /// The date this entry was created.
    var createdDate: Date { get }

    /// The type of entry (task, event, or note).
    var entryType: EntryType { get }
}

/// An entry that can be assigned to spreads.
///
/// Assignable entries (tasks and notes) track their preferred date and period,
/// and maintain assignment history across spreads. Assignment types are defined
/// separately (TaskAssignment, NoteAssignment).
protocol AssignableEntry: Entry {
    /// The assignment type for this entry.
    associatedtype AssignmentType

    /// The preferred date for this entry.
    var date: Date { get set }

    /// The preferred period for this entry.
    var period: Period { get set }

    /// Assignment history for this entry across spreads.
    var assignments: [AssignmentType] { get set }
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
