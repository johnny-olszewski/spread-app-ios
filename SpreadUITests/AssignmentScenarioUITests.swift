import XCTest

@MainActor
final class AssignmentScenarioUITests: LocalhostScenarioUITestCase {

    /// Conditions: A day spread already exists for today in localhost conventional mode.
    /// Expected: Creating a task from the current spread assigns it directly to that spread and leaves Inbox empty.
    func testTaskCreationAssignsDirectlyToExistingSpread() throws {
        let app = launchScenario(.assignmentExistingSpread)

        createTask(title: "Direct assignment task", in: app)

        XCTAssertTrue(app.staticTexts["Direct assignment task"].waitForExistence(timeout: 5))

        openSearch(in: app)
        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Search.section("inbox")
            )
            .waitForExistence(timeout: 2)
        )
    }

    /// Conditions: No matching spreads exist in localhost conventional mode.
    /// Expected: Creating a task routes it to Inbox instead of placing it on a spread.
    func testTaskCreationFallsBackToInboxWithoutMatchingSpread() throws {
        let app = launchScenario(.assignmentInboxFallback)

        createTask(title: "Inbox fallback task", in: app)

        openSearch(in: app)
        XCTAssertTrue(app.staticTexts["Inbox fallback task"].waitForExistence(timeout: 5))
    }

    /// Conditions: An Inbox task exists and its matching day spread is created later.
    /// Expected: The new destination-side migration section does not include Inbox-origin tasks.
    func testInboxTaskDoesNotAppearInDestinationMigrationSection() throws {
        let app = launchScenario(.inboxResolution)

        openSearch(in: app)
        XCTAssertTrue(app.staticTexts["Inbox resolution task"].waitForExistence(timeout: 5))

        let spreadsTab = app.tabBars.buttons["Spreads"].firstMatch
        waitForElement(spreadsTab)
        spreadsTab.tap()

        createDaySpread(day: 20, in: app)
        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
            )
            .waitForExistence(timeout: 2)
        )
    }

    /// Conditions: A task exists on a spread and is opened from the search tab.
    /// Expected: Tapping the search result switches back to Spreads and opens the task edit sheet there.
    func testSearchResultNavigatesToSpreadAndOpensTaskEditSheet() throws {
        let app = launchScenario(.assignmentExistingSpread)

        createTask(title: "Search navigation task", in: app)

        openSearch(in: app)

        let result = app.staticTexts["Search navigation task"].firstMatch
        waitForElement(result)
        result.tap()

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        XCTAssertTrue(app.tabBars.buttons["Spreads"].isSelected)
    }
}
