import XCTest

@MainActor
final class MigrationScenarioUITests: LocalhostScenarioUITestCase {

    func testMonthBoundTaskAppearsOnMonthDestinationButNotDayDestination() throws {
        let app = launchScenario(.migrationMonthBound)

        let monthSection = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
        )
        waitForElement(monthSection)

        let dayApp = launchScenario(.migrationMonthBound, today: "2026-01-20")
        let daySection = anyElement(
            in: dayApp,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
        )
        XCTAssertFalse(daySection.waitForExistence(timeout: 2))
    }

    func testSourceMigrationMovesTaskToMigratedSectionAndDestination() throws {
        let app = launchScenario(.migrationDaySuperseded)

        tapSourceMigrationButton(taskTitle: "Day upgrade migration task", in: app)

        let alert = app.alerts.firstMatch
        waitForElement(alert)
        XCTAssertTrue(alert.staticTexts["Move \"Day upgrade migration task\" to January 20, 2026?"].waitForExistence(timeout: 2))
        alert.buttons["Migrate"].tap()

        let taskRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Day upgrade migration task")
        )
        XCTAssertFalse(taskRow.waitForExistence(timeout: 2))

        let migratedHeader = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.migratedSectionHeader
        )
        waitForElement(migratedHeader)
        tapElement(migratedHeader)
        XCTAssertTrue(app.staticTexts["Day upgrade migration task"].waitForExistence(timeout: 5))

        openDayInStrip(20, in: app)
        XCTAssertTrue(app.staticTexts["Day upgrade migration task"].waitForExistence(timeout: 5))
        let sectionHeader = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
        )
        XCTAssertFalse(sectionHeader.waitForExistence(timeout: 2))
    }

    func testDestinationMigrationSectionExcludesNotes() throws {
        let app = launchScenario(.noteExclusions, today: "2026-01-20")
        expandDestinationMigrationSection(in: app)

        let taskRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationRow("Scenario migration task")
        )
        let noteRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationRow("Scenario migration note")
        )
        waitForElement(taskRow)
        XCTAssertFalse(noteRow.waitForExistence(timeout: 2))
    }

    func testTappingMigratedTaskNavigatesToDestinationBeforeOpeningEditSheet() throws {
        let app = launchScenario(.migrationDaySuperseded)

        tapSourceMigrationButton(taskTitle: "Day upgrade migration task", in: app)
        let alert = app.alerts.firstMatch
        waitForElement(alert)
        alert.buttons["Migrate"].tap()

        let migratedHeader = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.migratedSectionHeader
        )
        waitForElement(migratedHeader)
        tapElement(migratedHeader)

        let migratedTaskRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Day upgrade migration task")
        )
        waitForElement(migratedTaskRow)
        tapElement(migratedTaskRow)

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        saveButton.tap()

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Day upgrade migration task")
            ).waitForExistence(timeout: 5)
        )
        let contentTitle = app.staticTexts[Definitions.AccessibilityIdentifiers.SpreadContent.title]
        waitForElement(contentTitle)
        XCTAssertEqual(contentTitle.label, "January 20, 2026")
    }
}
