/// Configuration for the inbox button appearance and accessibility.
///
/// Determines the icon, tint color, and accessibility label based on
/// the current inbox count. Uses yellow tint instead of badge count
/// for liquid glass compatibility.
struct InboxButtonConfiguration: Sendable {

    // MARK: - Properties

    /// The number of entries in the inbox.
    let inboxCount: Int

    // MARK: - Computed Properties

    /// Whether the inbox has any entries.
    var hasEntries: Bool {
        inboxCount > 0
    }

    /// Whether to use yellow tint for the button.
    ///
    /// Returns `true` when inbox has entries.
    var usesYellowTint: Bool {
        hasEntries
    }

    /// The SF Symbol name for the inbox icon.
    ///
    /// Returns "tray.full" when inbox has entries, "tray" when empty.
    var iconName: String {
        hasEntries ? "tray.full" : "tray"
    }

    /// The accessibility label for the inbox button.
    ///
    /// Includes the count when inbox has entries.
    var accessibilityLabel: String {
        if inboxCount == 0 {
            return "Inbox, empty"
        } else if inboxCount == 1 {
            return "Inbox, 1 entry"
        } else {
            return "Inbox, \(inboxCount) entries"
        }
    }
}
