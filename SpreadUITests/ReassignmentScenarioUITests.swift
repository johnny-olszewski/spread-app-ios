import XCTest

@MainActor
final class ReassignmentScenarioUITests: LocalhostScenarioUITestCase {

    /// Conditions: A task starts on today's day spread and a later day spread already exists in the same month.
    /// Expected: Editing the task date moves it to the later day spread and leaves a migrated-history row on the source spread.
    func testEditingTaskDateMovesTaskAndShowsMigratedHistoryOnSourceSpread() throws {
        let app = launchScenario(.reassignment)

        openTaskForEditing(title: "Reassign me", in: app)
        selectGraphicalDay(
            20,
            pickerIdentifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.datePicker,
            in: app
        )

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        saveButton.tap()

        openDay(year: 2026, month: 1, day: 20, in: app)
        XCTAssertTrue(app.staticTexts["Reassign me"].waitForExistence(timeout: 5))

        openDay(year: 2026, month: 1, day: 12, in: app)
        let migratedSectionHeader = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.migratedSectionHeader
        )
        waitForElement(migratedSectionHeader)
        migratedSectionHeader.tap()

        XCTAssertTrue(app.staticTexts["Reassign me"].waitForExistence(timeout: 5))
    }

    /// Conditions: The seeded spread navigator data includes a year task on 2026 and no April month or April 6 day spread.
    /// Expected: Editing that task to April 6 day keeps it on the 2026 year spread and shows a day-context label of 6 in the April section.
    func testEditingSeededYearTaskToAprilDayKeepsTaskOnYearSpread() throws {
        let app = launchScenario(.spreadNavigator)
        openTaskForEditing(title: "Navigator year task", in: app)

        tapTaskDetailPeriodSegment(rawValue: "day", in: app)
        waitForElement(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.datePicker
            )
        )

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        saveButton.tap()
        openYear(2026, in: app)

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator year task")
            ).waitForExistence(timeout: 5)
        )

        let dayContext = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskContextLabel("Navigator year task")
        )
        waitForElement(dayContext)
        XCTAssertEqual(dayContext.label, "6")
    }

    /// Conditions: After the seeded year task is edited to April 6 day, an April 2026 month spread is created.
    /// Expected: The April month spread shows the task in `Migrate tasks`, and the 2026 year spread exposes the source-side migration arrow for that task.
    func testCreatingAprilMonthAfterYearTaskEditShowsMigrationSurfaces() throws {
        let app = launchScenario(.spreadNavigator)
        openTaskForEditing(title: "Navigator year task", in: app)

        tapTaskDetailPeriodSegment(rawValue: "day", in: app)
        waitForElement(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.datePicker
            )
        )

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        saveButton.tap()
        openYear(2026, in: app)

        createMonthSpread(monthName: "April", in: app)

        expandDestinationMigrationSection(in: app)
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Migration.destinationRow("Navigator year task")
            ).waitForExistence(timeout: 5)
        )

        openYear(2026, in: app)
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton("Navigator year task")
            ).waitForExistence(timeout: 5)
        )
    }
}
