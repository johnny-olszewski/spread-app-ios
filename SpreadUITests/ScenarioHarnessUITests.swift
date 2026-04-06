import XCTest

@MainActor
final class ScenarioHarnessUITests: LocalhostScenarioUITestCase {

    /// Conditions: Launch the day-upgrade migration scenario in localhost.
    /// Expected: The inline source and destination migration surfaces expose stable identifiers.
    func testMigrationScenarioExposesStableIdentifiers() throws {
        let app = launchScenario(.migrationDaySuperseded)

        waitForElement(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton("Day upgrade migration task")
            )
        )

        let dayApp = launchScenario(.migrationDaySuperseded, today: "2026-01-20")
        waitForElement(
            anyElement(
                in: dayApp,
                identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
            )
        )
    }

    /// Conditions: Launch the overdue review scenario in localhost.
    /// Expected: The overdue toolbar button and review sheet expose stable scenario-test identifiers.
    func testOverdueScenarioExposesStableIdentifiers() throws {
        let app = launchScenario(.overdueReview)

        openOverdueReview(in: app)
    }
}
