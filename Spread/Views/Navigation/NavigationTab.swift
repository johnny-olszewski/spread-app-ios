/// Navigation tabs for iPhone (compact width) tab-based navigation.
///
/// Defines the main navigation destinations accessible from the tab bar.
/// In DEBUG builds, includes an additional Debug tab.
enum NavigationTab: String, Identifiable, Sendable {
    /// Spreads tab showing journal spreads.
    case spreads

    /// Collections tab showing all collections.
    case collections

    /// Settings tab for app preferences.
    case settings

    #if DEBUG
    /// Debug tab for development tools and inspection.
    case debug
    #endif

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - All Cases

    /// All navigation tabs, conditionally including Debug in DEBUG builds.
    static var allCases: [NavigationTab] {
        var cases: [NavigationTab] = [.spreads, .collections, .settings]
        #if DEBUG
        cases.append(.debug)
        #endif
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
        #if DEBUG
        case .debug:
            return "Debug"
        #endif
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
        #if DEBUG
        case .debug:
            return "ant"
        #endif
        }
    }
}
