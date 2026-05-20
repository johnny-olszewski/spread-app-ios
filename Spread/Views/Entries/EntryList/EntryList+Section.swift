import Foundation

enum EntryList {}

extension EntryList {
    /// A section of grouped entries for display in an entry list.
    ///
    /// Contains a title, date, and the entries belonging to this section.
    /// Used by `EntryListView` to render grouped entries.
    struct Section: Identifiable, Sendable {
        /// Unique identifier for the section.
        let id: String

        /// The display title for the section header.
        ///
        /// For year spreads: "January 2026"
        /// For month spreads: "January 5"
        /// For day spreads: Empty string (no header shown)
        /// For multiday spreads: "January 5"
        let title: String

        /// The date this section represents.
        ///
        /// For year spreads: First day of the month
        /// For month/multiday spreads: The specific day
        /// For day spreads: The spread date
        let date: Date

        /// The entries in this section.
        let entries: [any Entry]

        /// The period/date context used when creating a new task from this section.
        let creationPeriod: Period
        let creationDate: Date
    }
}
