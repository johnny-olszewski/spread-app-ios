/// Sidebar items for iPad (regular width) sidebar navigation.
///
/// Defines the main navigation destinations accessible from the sidebar.
enum SidebarItem: String, Identifiable, Sendable {
    /// Spreads section showing journal spreads.
    case spreads

    /// Collections section showing all collections.
    case collections

    /// Settings section for app preferences.
    case settings

    /// Debug section for development tools and inspection.
    case debug

    // MARK: - Identifiable

    var id: String { rawValue }

    // MARK: - All Cases

    /// All sidebar items, conditionally including Debug when enabled.
    static var allCases: [SidebarItem] {
        var cases: [SidebarItem] = [.spreads, .collections, .settings]
        if BuildInfo.allowsDebugUI {
            cases.append(.debug)
        }
        return cases
    }

    // MARK: - Display

    /// The display title for this sidebar item.
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

    /// The SF Symbol name for this sidebar item's icon.
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
