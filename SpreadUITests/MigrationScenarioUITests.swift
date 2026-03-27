import XCTest

@MainActor
final class MigrationScenarioUITests: LocalhostScenarioUITestCase {

    func testMonthBoundTaskPromptsOnMonthButNotDay() throws {
        let app = launchScenario(.migrationMonthBound)

        openMonth(year: 2026, month: 1, in: app)
        let monthReview = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        waitForElement(monthReview)

        let dayApp = launchScenario(.migrationMonthBound)
        openDay(year: 2026, month: 1, day: 20, in: dayApp)
        let dayReview = anyElement(
            in: dayApp,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        XCTAssertFalse(dayReview.waitForExistence(timeout: 2))
    }

    func testDayDestinationSupersedesMonthPromptOnceDayExists() throws {
        let monthApp = launchScenario(.migrationDaySuperseded)

        openMonth(year: 2026, month: 1, in: monthApp)
        let monthReview = anyElement(
            in: monthApp,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        XCTAssertFalse(monthReview.waitForExistence(timeout: 2))

        let app = launchScenario(.migrationDaySuperseded)
        openDay(year: 2026, month: 1, day: 20, in: app)
        let dayReview = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        waitForElement(dayReview)
        openMigrationReview(in: app)

        XCTAssertTrue(app.staticTexts["Day upgrade migration task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Currently on: 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Move to: January 20, 2026"].waitForExistence(timeout: 5))

        submitMigration(in: app)
        XCTAssertTrue(app.staticTexts["Day upgrade migration task"].waitForExistence(timeout: 5))
    }

    func testMigrationReviewExcludesNotes() throws {
        let app = launchScenario(.noteExclusions)

        openDay(year: 2026, month: 1, day: 20, in: app)
        let reviewButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        waitForElement(reviewButton)
        openMigrationReview(in: app)

        XCTAssertTrue(app.staticTexts["Scenario migration task"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Scenario migration note"].waitForExistence(timeout: 2))
    }
}
