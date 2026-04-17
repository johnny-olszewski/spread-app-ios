import XCTest

@MainActor
final class SpreadContentInteractionUITests: LocalhostScenarioUITestCase {

    private func openFirstMultidaySpread(in app: XCUIApplication) {
        let multidayGrid = app.scrollViews[Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid]
        if multidayGrid.waitForExistence(timeout: 2) {
            return
        }

        let multidayItem = firstHittableElement(
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "spreads.strip.multiday."))
        )
        tapElement(multidayItem)
    }

    func testOpenTaskRowTapStartsInlineEditingWithoutOpeningSheet() throws {
        let app = launchScenario(.reassignment)

        let rowIdentifier = Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
        let row = anyElement(in: app, identifier: rowIdentifier)
        waitForElement(row)

        XCTAssertTrue(
            row.waitForExistence(timeout: 5)
        )

        row.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(
            app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton].exists
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton("Reassign me")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu("Reassign me")
            ).waitForExistence(timeout: 5)
        )
    }

    func testTappingOutsideFocusedTaskRowDismissesInlineEditing() throws {
        let app = launchScenario(.reassignment)

        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
        )
        waitForElement(row)
        row.tap()

        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))

        let pager = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager
        )
        waitForElement(pager)
        pager.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.02)).tap()

        let keyboardGone = NSPredicate(format: "exists == false")
        let keyboardExpectation = XCTNSPredicateExpectation(
            predicate: keyboardGone,
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [keyboardExpectation], timeout: 5), .completed)

        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton("Reassign me")
            ).exists
        )
        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu("Reassign me")
            ).exists
        )
    }

    func testCompletedTaskRowTapOpensExistingTaskEditSheet() throws {
        let app = launchScenario(.reassignment)

        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
        )
        waitForElement(row)
        row.press(forDuration: 1.0)

        let completeButton = app.buttons["Complete"].firstMatch
        waitForElement(completeButton)
        completeButton.tap()

        row.tap()

        XCTAssertTrue(
            app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
                .waitForExistence(timeout: 5)
        )
    }

    func testInlinePencilCommitsDraftTitleBeforeOpeningSheet() throws {
        let app = launchScenario(.reassignment)

        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
        )
        waitForElement(row)
        row.tap()

        let titleField = app.textFields.firstMatch
        waitForElement(titleField)
        titleField.tap()
        titleField.typeText(" updated")

        let editButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineEditButton("Reassign me")
        )
        waitForElement(editButton)
        editButton.tap()

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "updated")
    }

    func testInlineMigrateMenuShowsValidOptionsAndAppliesImmediately() throws {
        let app = launchScenario(.reassignment, today: "2026-01-12")

        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
        )
        waitForElement(row)
        row.tap()

        let migrateMenu = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationMenu("Reassign me")
        )
        waitForElement(migrateMenu)
        app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: migrateMenu.frame.midX, dy: migrateMenu.frame.midY))
            .tap()

        XCTAssertTrue(app.buttons["Tomorrow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["February 2026"].exists)
        XCTAssertTrue(app.buttons["February 12, 2026"].exists)
        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskInlineMigrationOption(
                    "Reassign me",
                    option: "today"
                )
            ).exists
        )

        app.buttons["Tomorrow"].tap()

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Reassign me")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.buttons["Tomorrow"].exists)
    }

    func testInlineAddTaskSaveDismissesFieldAndKeyboardImmediately() throws {
        let app = launchScenario(.reassignment)

        let addButton = firstHittableElement(
            app.buttons.matching(identifier: Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton)
        )
        addButton.tap()

        let field = app.textFields[Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField]
        waitForElement(field)
        field.typeText("Inline save task")

        let saveButton = app.buttons["Save"].firstMatch
        waitForElement(saveButton)
        saveButton.tap()

        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField
            ).exists
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Inline save task")
            ).waitForExistence(timeout: 5)
        )
    }

    func testInlineAddTaskReturnDismissesFieldAndKeyboardImmediately() throws {
        let app = launchScenario(.reassignment)

        let addButton = firstHittableElement(
            app.buttons.matching(identifier: Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton)
        )
        addButton.tap()

        let field = app.textFields[Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField]
        waitForElement(field)
        field.typeText("Inline return task\n")

        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.inlineTaskCreationField
            ).exists
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Inline return task")
            ).waitForExistence(timeout: 5)
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
        openFirstMultidaySpread(in: app)

        XCTAssertTrue(
            app.scrollViews[Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection("2026-01-10")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection("2026-01-11")
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection("2026-01-12")
            ).waitForExistence(timeout: 5)
        )

        XCTAssertTrue(
            app.staticTexts["Middle day task"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Hidden multiday note"].exists)

        XCTAssertFalse(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidaySection("2026-01-11")
            )
            .staticTexts["Middle day task"]
            .exists
        )
    }

    func testMultidayTodayCardShowsTodayLabelAndFooterButton() throws {
        let app = launchScenario(.multidayLayout, today: "2026-01-10")
        let dateID = "2026-01-10"
        openFirstMultidaySpread(in: app)

        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayTodayLabel(dateID)
            ).waitForExistence(timeout: 5)
        )
        XCTAssertTrue(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID)
            ).waitForExistence(timeout: 5)
        )
    }

    func testMultidayFooterCreatesDaySpreadAndNavigatesToIt() throws {
        let app = launchScenario(.multidayLayout, today: "2026-01-10")
        let dateID = "2026-01-10"
        openFirstMultidaySpread(in: app)

        let footerButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID)
        )
        waitForElement(footerButton)
        footerButton.tap()

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton]
        waitForElement(createButton)
        createButton.tap()

        let headerTitle = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.titleButton
        )
        waitForElement(headerTitle)
        XCTAssertTrue(headerTitle.label.contains("January 10, 2026"))
    }

    func testYearSpreadShowsUntitledYearTasksAndMonthSections() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openYear(2026, in: app)

        XCTAssertTrue(app.staticTexts["Navigator year task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["January 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Navigator January month task"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["April 2026"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Navigator month task without month spread"].waitForExistence(timeout: 5))
        let orphanDayRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator day task without day or month spread")
        )
        waitForElement(orphanDayRow)
        XCTAssertTrue(orphanDayRow.staticTexts["15"].waitForExistence(timeout: 5))
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

        let dayRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator day task")
        )
        waitForElement(dayRow)
        XCTAssertTrue(dayRow.staticTexts["29"].waitForExistence(timeout: 5))
    }
}
