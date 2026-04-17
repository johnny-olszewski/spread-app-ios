import XCTest

@MainActor
final class OverdueScenarioUITests: LocalhostScenarioUITestCase {

    func testConventionalOverdueBadgesAppearOnAssignedSpreadsAndSelectedBadgePersists() throws {
        let app = launchScenario(.overdueReview)

        XCTAssertFalse(
            app.descendants(matching: .any)["overdue.toolbar.button"].waitForExistence(timeout: 1)
        )

        let overdueDayItem = anyElement(in: app, identifier: "spreads.strip.day.10")
        waitForElement(overdueDayItem)

        let overdueBadge = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.overdueBadge("spreads.strip.day.10")
        )
        waitForElement(overdueBadge)
        XCTAssertEqual(overdueBadge.label, "1 overdue tasks")

        tapElement(identifier: "spreads.strip.day.10", in: app)

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        XCTAssertTrue(selectedIndicator.label.contains("10"))
        waitForElement(overdueBadge)
    }

    func testInboxOverdueTasksDoNotProduceSpreadBadges() throws {
        let app = launchScenario(.overdueInbox)

        XCTAssertFalse(
            app.descendants(matching: .any)["overdue.toolbar.button"].waitForExistence(timeout: 1)
        )

        let januaryBadge = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.overdueBadge("spreads.strip.month.jan")
        )
        XCTAssertFalse(januaryBadge.waitForExistence(timeout: 1))
    }

    func testTraditionalModeShowsOverdueBadgesWithoutMigrationUI() throws {
        let app = launchScenario(.traditionalOverdue)

        switchToTraditionalMode(in: app)

        let overdueBadge = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.overdueBadge("spreads.strip.day.10")
        )
        waitForElement(overdueBadge)
        XCTAssertEqual(overdueBadge.label, "1 overdue tasks")
        XCTAssertFalse(
            anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader)
                .waitForExistence(timeout: 2)
        )
    }
}
