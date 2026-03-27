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
}
