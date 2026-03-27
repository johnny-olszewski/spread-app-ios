import XCTest

@MainActor
final class AssignmentScenarioUITests: LocalhostScenarioUITestCase {

    /// Conditions: A day spread already exists for today in localhost conventional mode.
    /// Expected: Creating a task from the current spread assigns it directly to that spread and leaves Inbox empty.
    func testTaskCreationAssignsDirectlyToExistingSpread() throws {
        let app = launchScenario(.assignmentExistingSpread)

        createTask(title: "Direct assignment task", in: app)

        XCTAssertTrue(app.staticTexts["Direct assignment task"].waitForExistence(timeout: 5))

        openInbox(in: app)
        XCTAssertTrue(app.staticTexts["Inbox Empty"].waitForExistence(timeout: 5))
    }

    /// Conditions: No matching spreads exist in localhost conventional mode.
    /// Expected: Creating a task routes it to Inbox instead of placing it on a spread.
    func testTaskCreationFallsBackToInboxWithoutMatchingSpread() throws {
        let app = launchScenario(.assignmentInboxFallback)

        createTask(title: "Inbox fallback task", in: app)

        openInbox(in: app)
        XCTAssertTrue(app.staticTexts["Inbox fallback task"].waitForExistence(timeout: 5))
    }

    /// Conditions: An Inbox task exists and its matching day spread is created later.
    /// Expected: The new spread exposes migration review with the Inbox-origin task as a movable source.
    func testInboxTaskBecomesMigratableWhenMatchingSpreadIsCreated() throws {
        let app = launchScenario(.inboxResolution)

        openInbox(in: app)
        XCTAssertTrue(app.staticTexts["Inbox resolution task"].waitForExistence(timeout: 5))
        dismissInbox(in: app)

        createDaySpread(day: 20, in: app)
        openDay(year: 2026, month: 1, day: 20, in: app)
        openMigrationReview(in: app)

        XCTAssertTrue(app.staticTexts["Inbox resolution task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Currently on: Inbox"].waitForExistence(timeout: 5))
    }
}
