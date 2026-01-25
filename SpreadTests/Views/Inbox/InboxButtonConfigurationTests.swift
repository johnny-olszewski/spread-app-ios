import Testing
@testable import Spread

/// Tests for InboxButtonConfiguration.
///
/// Verifies that the inbox button configuration correctly determines
/// the tint color and icon based on inbox count.
@Suite("Inbox Button Configuration Tests")
struct InboxButtonConfigurationTests {

    // MARK: - Tint Color Tests

    /// When inbox count is 0,
    /// the configuration should use the default tint (no special color).
    @Test("Empty inbox uses default tint")
    func emptyInboxUsesDefaultTint() {
        let config = InboxButtonConfiguration(inboxCount: 0)

        #expect(config.hasEntries == false)
        #expect(config.usesYellowTint == false)
    }

    /// When inbox count is 1,
    /// the configuration should use yellow tint.
    @Test("Single entry uses yellow tint")
    func singleEntryUsesYellowTint() {
        let config = InboxButtonConfiguration(inboxCount: 1)

        #expect(config.hasEntries == true)
        #expect(config.usesYellowTint == true)
    }

    /// When inbox count is greater than 1,
    /// the configuration should use yellow tint.
    @Test("Multiple entries use yellow tint")
    func multipleEntriesUseYellowTint() {
        let config = InboxButtonConfiguration(inboxCount: 5)

        #expect(config.hasEntries == true)
        #expect(config.usesYellowTint == true)
    }

    // MARK: - Icon Tests

    /// When inbox is empty,
    /// the icon should be the regular tray.
    @Test("Empty inbox shows tray icon")
    func emptyInboxShowsTrayIcon() {
        let config = InboxButtonConfiguration(inboxCount: 0)

        #expect(config.iconName == "tray")
    }

    /// When inbox has entries,
    /// the icon should be tray.full.
    @Test("Non-empty inbox shows tray.full icon")
    func nonEmptyInboxShowsTrayFullIcon() {
        let config = InboxButtonConfiguration(inboxCount: 3)

        #expect(config.iconName == "tray.full")
    }

    // MARK: - Accessibility Tests

    /// When inbox is empty,
    /// the accessibility label should indicate empty state.
    @Test("Empty inbox accessibility label")
    func emptyInboxAccessibilityLabel() {
        let config = InboxButtonConfiguration(inboxCount: 0)

        #expect(config.accessibilityLabel == "Inbox, empty")
    }

    /// When inbox has entries,
    /// the accessibility label should indicate count.
    @Test("Non-empty inbox accessibility label with count")
    func nonEmptyInboxAccessibilityLabel() {
        let config = InboxButtonConfiguration(inboxCount: 3)

        #expect(config.accessibilityLabel == "Inbox, 3 entries")
    }

    /// When inbox has exactly 1 entry,
    /// the accessibility label should use singular form.
    @Test("Single entry accessibility label uses singular")
    func singleEntryAccessibilityLabelUsesSingular() {
        let config = InboxButtonConfiguration(inboxCount: 1)

        #expect(config.accessibilityLabel == "Inbox, 1 entry")
    }
}
