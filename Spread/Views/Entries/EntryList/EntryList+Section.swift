import Foundation

enum EntryList {}

extension EntryList {
    /// A section of grouped entries for display in an entry list.
    ///
    /// Contains optional grouping criteria, date, and the entries belonging to this section.
    /// Used by `EntryListView` to render grouped entries.
    struct Section: Identifiable {
        /// Unique identifier for the section.
        let id: String

        /// The criteria used to group this section.
        ///
        /// Nil criteria means the section has no rendered header.
        /// Day spread list sections use the backing list as criteria.
        let criteria: (any EntrySectionCriteria)?

        /// The display title for the section header.
        var title: String {
            criteria?.sectionTitle ?? ""
        }

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

protocol EntrySectionCriteria {
    var sectionID: String { get }
    var sectionTitle: String { get }
}

extension DataModel.List: EntrySectionCriteria {
    var sectionID: String { id.uuidString }
    var sectionTitle: String { name }
}

struct EntryTitleSectionCriteria: EntrySectionCriteria {
    let sectionID: String
    let sectionTitle: String
}
