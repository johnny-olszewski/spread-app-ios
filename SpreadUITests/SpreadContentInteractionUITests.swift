import XCTest

@MainActor
final class SpreadContentInteractionUITests: LocalhostScenarioUITestCase {

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

        let list = app.otherElements[Definitions.AccessibilityIdentifiers.SpreadContent.list]
        waitForElement(list)
        list.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.95)).tap()

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
        XCTAssertEqual(app.textFields.firstMatch.value as? String, "Reassign me updated")
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

        let addButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton]
        waitForElement(addButton)
        addButton.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        app.typeText("Inline save task")

        let saveButton = app.buttons["Save"].firstMatch
        waitForElement(saveButton)
        saveButton.tap()

        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [keyboardGone], timeout: 5), .completed)
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

        let addButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadContent.addTaskButton]
        waitForElement(addButton)
        addButton.tap()

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        app.typeText("Inline return task\n")

        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(XCTWaiter().wait(for: [keyboardGone], timeout: 5), .completed)
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

        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "No tasks for this day.")).count,
            2
        )
    }

    func testMultidayTodayCardShowsTodayLabelAndFooterButton() throws {
        let app = launchScenario(.multidayLayout, today: "2026-01-10")
        let dateID = "2026-01-10"

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

        let footerButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.multidayFooterButton(dateID)
        )
        waitForElement(footerButton)
        footerButton.tap()

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton]
        waitForElement(createButton)
        createButton.tap()

        let contentTitle = app.staticTexts[Definitions.AccessibilityIdentifiers.SpreadContent.title]
        waitForElement(contentTitle)
        XCTAssertEqual(contentTitle.label, "Friday, January 10, 2026")
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
