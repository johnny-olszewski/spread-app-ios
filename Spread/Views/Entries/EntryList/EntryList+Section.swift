import Foundation
import SwiftUI

enum EntryList {}

extension EntryList {
    enum SectionTitleStyle {
        case primary
        case secondary
    }

    /// Controls the visual chrome applied to a section by `EntryListView`.
    ///
    /// When `nil` (the default), sections render inside the standard `List`.
    /// When non-nil, `EntryListView` extracts the section and renders it with
    /// the specified style above the standard list.
    enum SectionStyle {
        /// Renders the section inside a rounded-rectangle card with a low-opacity
        /// fill and solid stroke in the given color.
        case card(Color)
        
        var verticalPadding: CGFloat {
            switch self {
            case .card: 8
            }
        
        }
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
        let configurationMap: EntryRowView.ConfigurationMap?
        
        /// Optional visual style applied by `EntryListView`. `nil` means standard list rendering.
        let style: EntryList.SectionStyle?

        let headerButtonViewModel: SpreadButton.ViewModel?
        
        let rowSpacing: CGFloat
        let rowInsets: EdgeInsets
        let rowAreaPadding: EdgeInsets

        init(
            id: String,
            title: String,
            titleStyle: SectionTitleStyle = .primary,
            date: Date,
            entries: [any Entry],
            creationPeriod: Period,
            creationDate: Date,
            configurationMap: EntryRowView.ConfigurationMap? = nil,
            style: EntryList.SectionStyle? = nil,
            headerButtonViewModel: SpreadButton.ViewModel? = nil,
            rowSpacing: CGFloat = 8,
            rowInsets: EdgeInsets = .init(top: 0, leading: 8, bottom: 0, trailing: 8),
            rowAreaPadding: EdgeInsets = .init(top: 0, leading: 0, bottom: 8, trailing: 0)
        ) {
            self.id = id
            self.title = title
            self.titleStyle = titleStyle
            self.date = date
            self.entries = entries
            self.creationPeriod = creationPeriod
            self.creationDate = creationDate
            self.configurationMap = configurationMap
            self.style = style
            self.headerButtonViewModel = headerButtonViewModel
            self.rowSpacing = rowSpacing
            self.rowInsets = rowInsets
            self.rowAreaPadding = rowAreaPadding
        }
    }
}
