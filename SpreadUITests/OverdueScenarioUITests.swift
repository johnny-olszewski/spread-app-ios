import XCTest

@MainActor
final class OverdueScenarioUITests: LocalhostScenarioUITestCase {

    func testOverdueButtonShowsGlobalCountAndReviewContents() throws {
        let app = launchScenario(.overdueReview)

        let overdueButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Overdue.button
        )
        waitForElement(overdueButton)
        XCTAssertTrue(overdueButton.label.contains("3"))

        openOverdueReview(in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }

    func testInboxOverdueTasksAppearInGlobalReview() throws {
        let app = launchScenario(.overdueInbox)

        let overdueButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Overdue.button
        )
        waitForElement(overdueButton)
        XCTAssertTrue(overdueButton.label.contains("2"))

        openOverdueReview(in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }

    func testTraditionalModeShowsOverdueWithoutMigrationUI() throws {
        let app = launchScenario(.traditionalOverdue)

        switchToTraditionalMode(in: app)

        let overdueButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Overdue.button
        )
        waitForElement(overdueButton)
        XCTAssertFalse(
            anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Migration.banner)
                .waitForExistence(timeout: 2)
        )

        openOverdueReview(in: app)
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 5))
    }
}
