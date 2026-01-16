/// Navigation tabs for iPhone (compact width) tab-based navigation.
///
/// Defines the main navigation destinations accessible from the tab bar.
enum NavigationTab: String, CaseIterable, Identifiable, Sendable {
    /// Spreads tab showing journal spreads.
    case spreads

    /// Collections tab showing all collections.
    case collections

    /// Settings tab for app preferences.
    case settings

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - Display

    /// The display title for this tab.
    var title: String {
        switch self {
        case .spreads:
            return "Spreads"
        case .collections:
            return "Collections"
        case .settings:
            return "Settings"
        }
    }

    /// The SF Symbol name for this tab's icon.
    var systemImage: String {
        switch self {
        case .spreads:
            return "book"
        case .collections:
            return "folder"
        case .settings:
            return "gear"
        }
    }
}
