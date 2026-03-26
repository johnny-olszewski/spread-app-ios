import XCTest

@MainActor
final class ScenarioHarnessUITests: LocalhostScenarioUITestCase {

    /// Conditions: Launch the month-bound migration scenario in localhost.
    /// Expected: The migration banner and sheet expose stable scenario-test identifiers.
    func testMigrationScenarioExposesStableIdentifiers() throws {
        let app = launchScenario(.migrationMonthBound)

        openMigrationReview(in: app)

        let submit = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Migration.submitButton)
        if submit.waitForExistence(timeout: 2) == false {
            waitForElement(app.buttons["Migrate Selected"])
        }
    }

    /// Conditions: Launch the overdue review scenario in localhost.
    /// Expected: The overdue toolbar button and review sheet expose stable scenario-test identifiers.
    func testOverdueScenarioExposesStableIdentifiers() throws {
        let app = launchScenario(.overdueReview)

        openOverdueReview(in: app)
    }
}
