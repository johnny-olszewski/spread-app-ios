/// The bullet journal mode for entry display and navigation.
///
/// Affects how entries are displayed and how navigation works:
/// - Conventional: Migration history visible, entries appear on multiple spreads
/// - Traditional: Entries appear only on preferred date, calendar-style navigation
enum BujoMode: String, CaseIterable, Codable, Sendable {
    /// Track tasks across spreads with migration history.
    ///
    /// In conventional mode:
    /// - Entries may appear on multiple spreads with per-spread status
    /// - Migration history is visible
    /// - Spreads must be created explicitly
    case conventional

    /// View tasks on their preferred date only.
    ///
    /// In traditional mode:
    /// - Entries appear only on their preferred assignment
    /// - No migration history visible
    /// - All spreads available for navigation regardless of created spread records
    case traditional

    // MARK: - Display

    /// The display name for this mode.
    var displayName: String {
        switch self {
        case .conventional:
            return "Conventional"
        case .traditional:
            return "Traditional"
        }
    }

    /// A description of this mode for settings UI.
    var description: String {
        switch self {
        case .conventional:
            return "Track tasks across spreads with migration history"
        case .traditional:
            return "View tasks on their preferred date only"
        }
    }
}
