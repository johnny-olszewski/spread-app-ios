import struct Foundation.Calendar
import struct Foundation.Date

/// A section of inbox entries grouped by type.
///
/// Contains entries of a single type (tasks or notes) for display
/// in the inbox sheet.
struct InboxEntrySection: Identifiable, Sendable {
    /// Unique identifier for the section.
    let id: EntryType

    /// The type of entries in this section.
    let entryType: EntryType

    /// The display title for the section header.
    let title: String

    /// The entries in this section.
    let entries: [any Entry]

    /// The number of entries in this section.
    var count: Int {
        entries.count
    }
}

/// Groups inbox entries by type for display in the inbox sheet.
///
/// Entries are grouped into sections by type (tasks first, then notes).
/// Within each section, entries are sorted by preferred date (earliest first).
struct InboxEntryGrouper: Sendable {

    // MARK: - Properties

    /// The calendar for date comparisons.
    let calendar: Calendar

    // MARK: - Initialization

    /// Creates an inbox entry grouper.
    ///
    /// - Parameter calendar: The calendar for date comparisons.
    init(calendar: Calendar) {
        self.calendar = calendar
    }

    // MARK: - Grouping

    /// Groups entries into sections by type.
    ///
    /// - Parameter entries: The inbox entries to group.
    /// - Returns: An array of sections (tasks first, then notes).
    func group(_ entries: [any Entry]) -> [InboxEntrySection] {
        guard !entries.isEmpty else { return [] }

        var sections: [InboxEntrySection] = []

        // Group tasks
        let tasks = entries.compactMap { $0 as? DataModel.Task }
        if !tasks.isEmpty {
            let sortedTasks = tasks.sorted { $0.date < $1.date }
            sections.append(InboxEntrySection(
                id: .task,
                entryType: .task,
                title: "Tasks",
                entries: sortedTasks
            ))
        }

        // Group notes
        let notes = entries.compactMap { $0 as? DataModel.Note }
        if !notes.isEmpty {
            let sortedNotes = notes.sorted { $0.date < $1.date }
            sections.append(InboxEntrySection(
                id: .note,
                entryType: .note,
                title: "Notes",
                entries: sortedNotes
            ))
        }

        return sections
    }
}
