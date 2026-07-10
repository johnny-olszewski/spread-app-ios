import Foundation
import SwiftUI

enum EntryList {}

extension EntryList {
    /// Controls how `EntryListView` renders the section header.
    ///
    /// `.named` applies a prominent font at full opacity (a real list, tag, or status value).
    /// `.unnamed` applies a smaller font at reduced opacity (the nil-bucket fallback — "No list", "No tag", etc.).
    enum SectionHeaderStyle {
        case named
        case unnamed

        /// The font used to render this header style.
        var font: Font {
            switch self {
            case .named: SpreadTheme.Typography.title2
            case .unnamed: SpreadTheme.Typography.body
            }
        }

        /// The foreground color used to render this header style.
        var foregroundStyle: Color {
            switch self {
            case .named: .primary
            case .unnamed: .secondary
            }
        }
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

        /// Controls how the section header is rendered in `EntryListView`.
        /// `.named` for real values; `.unnamed` for nil-bucket fallbacks ("No list", "No tag", etc.).
        let headerStyle: EntryList.SectionHeaderStyle

        let rowSpacing: CGFloat
        let rowInsets: EdgeInsets
        let rowAreaPadding: EdgeInsets

        init(
            id: String,
            title: String,
            date: Date,
            entries: [any Entry],
            creationPeriod: Period,
            creationDate: Date,
            configurationMap: EntryRowView.ConfigurationMap? = nil,
            style: EntryList.SectionStyle? = nil,
            headerStyle: EntryList.SectionHeaderStyle = .named,
            rowSpacing: CGFloat = 8,
            rowInsets: EdgeInsets = .init(top: 0, leading: 8, bottom: 0, trailing: 8),
            rowAreaPadding: EdgeInsets = .init(top: 0, leading: 0, bottom: 8, trailing: 0)
        ) {
            self.id = id
            self.title = title
            self.date = date
            self.entries = entries
            self.creationPeriod = creationPeriod
            self.creationDate = creationDate
            self.configurationMap = configurationMap
            self.style = style
            self.headerStyle = headerStyle
            self.rowSpacing = rowSpacing
            self.rowInsets = rowInsets
            self.rowAreaPadding = rowAreaPadding
        }
    }
}
