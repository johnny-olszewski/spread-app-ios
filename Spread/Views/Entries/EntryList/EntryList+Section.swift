import Foundation

enum EntryList {}

extension EntryList {
    enum SectionTitleStyle {
        case primary
        case secondary
    }

    /// A section of grouped entries for display in an entry list.
    ///
    /// Contains a title, date, and the entries belonging to this section.
    /// Used by `EntryListView` to render grouped entries.
    struct Section: Identifiable {
        /// Unique identifier for the section.
        let id: String

        /// The display title for the section header.
        let title: String

        let titleStyle: SectionTitleStyle

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

        /// Optional per-section row rendering configuration. Falls back to the
        /// `EntryListView` configuration map when nil.
        let configurationMap: [EntryType: EntryRowView.Configuration]?

        /// Whether this section should show the inline add-task affordance.
        let allowsTaskCreation: Bool

        init(
            id: String,
            title: String,
            titleStyle: SectionTitleStyle = .primary,
            date: Date,
            entries: [any Entry],
            creationPeriod: Period,
            creationDate: Date,
            configurationMap: [EntryType: EntryRowView.Configuration]? = nil,
            allowsTaskCreation: Bool = true
        ) {
            self.id = id
            self.title = title
            self.titleStyle = titleStyle
            self.date = date
            self.entries = entries
            self.creationPeriod = creationPeriod
            self.creationDate = creationDate
            self.configurationMap = configurationMap
            self.allowsTaskCreation = allowsTaskCreation
        }
    }
}
