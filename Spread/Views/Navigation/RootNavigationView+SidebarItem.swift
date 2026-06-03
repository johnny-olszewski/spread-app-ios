import Foundation

extension RootNavigationView {

    /// A discriminated union representing an item that can be selected in the app sidebar.
    ///
    /// The sidebar mixes top-level navigation destinations (entries, settings, etc.) with year
    /// subitems that live under the Spreads section. A single selection binding covers both.
    enum SidebarItem: Hashable, Identifiable, Sendable {

        /// A top-level navigation destination other than the spreads year list.
        case destination(Content)

        /// A year subitem under the Spreads section; the associated value is the calendar year.
        case spreadsYear(Int)

        var id: Self { self }
    }
}
