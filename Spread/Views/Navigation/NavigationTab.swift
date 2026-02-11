/// Navigation tabs for iPhone (compact width) tab-based navigation.
///
/// Defines the main navigation destinations accessible from the tab bar.
enum NavigationTab: String, Identifiable, Sendable {
    /// Spreads tab showing journal spreads.
    case spreads

    /// Collections tab showing all collections.
    case collections

    /// Settings tab for app preferences.
    case settings

    /// Debug tab for development tools and inspection.
    case debug

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - All Cases

    /// All navigation tabs, conditionally including Debug when enabled.
    static var allCases: [NavigationTab] {
        var cases: [NavigationTab] = [.spreads, .collections, .settings]
        if BuildInfo.allowsDebugUI {
            cases.append(.debug)
        }
        return cases
    }

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
        case .debug:
            return "Debug"
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
        case .debug:
            return "ant"
        }
    }
}
