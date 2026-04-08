import XCTest

@MainActor
final class SpreadContentInteractionUITests: LocalhostScenarioUITestCase {

    func testTaskRowTapOpensExistingTaskEditSheet() throws {
        let app = launchScenario(.reassignment)

        tapTaskForEditing(title: "Reassign me", in: app)

        XCTAssertTrue(
            app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
                .waitForExistence(timeout: 5)
        )
    }

    func testTaskEditSheetUsesStatusIconInsteadOfManualMigratedPicker() throws {
        let app = launchScenario(.reassignment)

        openTaskForEditing(title: "Reassign me", in: app)

        let statusToggle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Mark task complete"))
            .firstMatch
        XCTAssertTrue(
            statusToggle.waitForExistence(timeout: 5)
        )
        XCTAssertFalse(
            app.segmentedControls[Definitions.AccessibilityIdentifiers.TaskDetailSheet.statusPicker].exists
        )
    }

    func testTaskEditStatusToggleDisablesAndReenablesAssignmentControlsInDraft() throws {
        let app = launchScenario(.reassignment)

        openTaskForEditing(title: "Reassign me", in: app)

        let statusToggle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Mark task complete"))
            .firstMatch
        XCTAssertTrue(statusToggle.waitForExistence(timeout: 5))

        let periodMenu = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.TaskDetailSheet.periodPicker
        )
        waitForElement(periodMenu)
        XCTAssertTrue(periodMenu.isEnabled)

        statusToggle.tap()
        XCTAssertFalse(periodMenu.isEnabled)

        let reopenToggle = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", "Mark task open"))
            .firstMatch
        XCTAssertTrue(reopenToggle.waitForExistence(timeout: 5))
        reopenToggle.tap()
        XCTAssertTrue(periodMenu.isEnabled)
    }

    func testMultidaySpreadShowsEveryDaySectionIncludingEmptyDays() throws {
        let app = launchScenario(.multidayLayout, today: "2026-01-10")

        XCTAssertTrue(
            app.scrollViews[Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["January 10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["January 11"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["January 12"].waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.staticTexts["Middle day task"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Hidden multiday note"].exists)

        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "No tasks for this day.")).count,
            2
        )
    }

    func testYearSpreadShowsUntitledYearTasksAndMonthSections() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openYear(2026, in: app)

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator year task")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["January 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator January month task")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["April 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator month task without month spread")
            ).waitForExistence(timeout: 5)
        )
        let orphanDayContext = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskContextLabel(
                "Navigator day task without day or month spread"
            )
        )
        XCTAssertTrue(orphanDayContext.waitForExistence(timeout: 5))
        XCTAssertEqual(orphanDayContext.label, "15")
    }

    func testMonthSpreadShowsDayTaskContextLabels() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator March month task")
            ).waitForExistence(timeout: 5)
        )

        let dayContext = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskContextLabel("Navigator day task")
        )
        XCTAssertTrue(dayContext.waitForExistence(timeout: 5))
        XCTAssertEqual(dayContext.label, "29")
    }
}
