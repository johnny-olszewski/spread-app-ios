import SwiftUI

extension RootNavigationView {

    /// Navigation destinations for the sidebar and content column.
    ///
    /// Each case maps to a top-level section of the app. The sidebar renders one row per
    /// case; the selected case drives what appears in the content and detail columns.
    enum Content: String, Identifiable, Sendable {
        /// Spreads destination — journal spreads and the spread picker.
        case spreads

        /// Entries destination — cross-spread task and note browser.
        case entries

        /// Collections destination — all collections.
        case collections

        /// Settings destination — app preferences.
        case settings

        /// Debug destination — development tools and inspection.
        case debug

        // MARK: - Identifiable

        var id: String { rawValue }

        // MARK: - All Cases

        /// All navigation destinations, conditionally including Debug when enabled.
        static var allCases: [Content] {
            var cases: [Content] = [.spreads, .entries, .collections, .settings]
            if BuildInfo.allowsDebugUI {
                cases.append(.debug)
            }
            return cases
        }

        // MARK: - Display

        /// The display title for this destination.
        var title: String {
            switch self {
            case .spreads:      return "Spreads"
            case .entries:      return "Entries"
            case .collections:  return "Collections"
            case .settings:     return "Settings"
            case .debug:        return "Debug"
            }
        }

        /// The SF Symbol name for this destination's icon.
        var systemImage: String {
            switch self {
            case .spreads:      return "book"
            case .entries:      return "tray.full"
            case .collections:  return "folder"
            case .settings:     return "gear"
            case .debug:        return "ant"
            }
        }
    }
}
