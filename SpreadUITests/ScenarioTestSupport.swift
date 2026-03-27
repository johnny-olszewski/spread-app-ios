import XCTest

@MainActor
class LocalhostScenarioUITestCase: XCTestCase {

    enum ScenarioDataSet: String {
        case assignmentExistingSpread = "scenarioAssignmentExistingSpread"
        case assignmentInboxFallback = "scenarioAssignmentInboxFallback"
        case inboxResolution = "scenarioInboxResolution"
        case migrationMonthBound = "scenarioMigrationMonthBound"
        case migrationDayUpgrade = "scenarioMigrationDayUpgrade"
        case migrationDaySuperseded = "scenarioMigrationDaySuperseded"
        case reassignment = "scenarioReassignment"
        case overdueReview = "scenarioOverdueReview"
        case overdueInbox = "scenarioOverdueInbox"
        case traditionalOverdue = "scenarioTraditionalOverdue"
        case noteExclusions = "scenarioNoteExclusions"
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func launchScenario(
        _ dataSet: ScenarioDataSet,
        today: String = "2026-01-12",
        extraArguments: [String] = []
    ) -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-DataEnvironment", "localhost",
            "-MockDataSet", dataSet.rawValue,
            "-Today", today
        ] + extraArguments
        app.launch()
        return app
    }

    func waitForElement(
        _ element: XCUIElement,
        timeout: TimeInterval = 5,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: timeout), file: file, line: line)
    }

    func anyElement(
        in app: XCUIApplication,
        identifier: String
    ) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    func openCreateTask(in app: XCUIApplication) {
        let createMenu = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.button]
        waitForElement(createMenu)
        createMenu.tap()

        let createTask = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.createTask]
        waitForElement(createTask)
        createTask.tap()

        let titleField = app.textFields[Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField]
        waitForElement(titleField)
    }

    func openCreateSpread(in app: XCUIApplication) {
        let createMenu = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.button]
        waitForElement(createMenu)
        createMenu.tap()

        let createSpread = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.createSpread]
        waitForElement(createSpread)
        createSpread.tap()

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton]
        waitForElement(createButton)
    }

    func createTask(
        title: String,
        periodRawValue: String? = nil,
        day: Int? = nil,
        in app: XCUIApplication
    ) {
        openCreateTask(in: app)

        let titleField = app.textFields[Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField]
        titleField.tap()
        titleField.typeText(title)

        if let periodRawValue {
            let segment = app.buttons[
                Definitions.AccessibilityIdentifiers.TaskCreationSheet.periodSegment(periodRawValue)
            ]
            waitForElement(segment)
            segment.tap()
        }

        if let day {
            selectGraphicalDay(
                day,
                pickerIdentifier: Definitions.AccessibilityIdentifiers.TaskCreationSheet.datePicker,
                in: app
            )
        }

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskCreationSheet.createButton]
        waitForElement(createButton)
        createButton.tap()
    }

    func createDaySpread(day: Int, in app: XCUIApplication) {
        openCreateSpread(in: app)

        let daySegment = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodSegment("day")
        ]
        waitForElement(daySegment)
        daySegment.tap()

        selectGraphicalDay(
            day,
            pickerIdentifier: Definitions.AccessibilityIdentifiers.SpreadCreationSheet.standardDatePicker,
            in: app
        )

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton]
        waitForElement(createButton)
        createButton.tap()
    }

    func openInbox(in app: XCUIApplication) {
        let inboxButton = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Inbox.button)
        waitForElement(inboxButton)
        inboxButton.tap()

        let doneButton = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Inbox.doneButton)
        waitForElement(doneButton)
    }

    func dismissInbox(in app: XCUIApplication) {
        let doneButton = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.Inbox.doneButton)
        waitForElement(doneButton)
        doneButton.tap()
    }

    func openTaskForEditing(title: String, in app: XCUIApplication) {
        let taskLabel = app.staticTexts[title].firstMatch
        waitForElement(taskLabel)
        taskLabel.swipeLeft()

        let editButton = app.buttons["Edit"].firstMatch
        waitForElement(editButton)
        editButton.tap()

        let saveButton = app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
        waitForElement(saveButton)
    }

    func selectGraphicalDay(
        _ day: Int,
        pickerIdentifier: String,
        in app: XCUIApplication
    ) {
        let picker = anyElement(in: app, identifier: pickerIdentifier)
        waitForElement(picker)

        let dayString = String(day)
        let descendants = picker.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", dayString))
        for index in 0..<descendants.count {
            let element = descendants.element(boundBy: index)
            if element.exists && element.isHittable {
                element.tap()
                return
            }
        }

        let staticTexts = picker.staticTexts.matching(NSPredicate(format: "label == %@", dayString))
        for index in 0..<staticTexts.count {
            let element = staticTexts.element(boundBy: index)
            if element.exists && element.isHittable {
                element.tap()
                return
            }
        }

        XCTFail("Unable to select day \(dayString) in picker \(pickerIdentifier)")
    }

    func openMigrationReview(in app: XCUIApplication) {
        let identifiedButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        let button = identifiedButton.waitForExistence(timeout: 2) ? identifiedButton : app.buttons["Review"]
        waitForElement(button)
        tapElement(button)
        let identifiedSubmit = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.submitButton
        )
        if identifiedSubmit.waitForExistence(timeout: 2) {
            return
        }
        waitForElement(app.buttons["Migrate Selected"])
    }

    func openOverdueReview(in app: XCUIApplication) {
        let identifiedButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Overdue.button
        )
        let button = identifiedButton.waitForExistence(timeout: 2) ? identifiedButton : app.buttons.matching(identifier: "Overdue tasks").firstMatch
        waitForElement(button)
        tapElement(button)
        let identifiedDone = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Overdue.doneButton
        )
        if identifiedDone.waitForExistence(timeout: 2) {
            return
        }
        waitForElement(app.buttons["Done"])
    }

    func openYear(_ year: Int, in app: XCUIApplication) {
        tapHierarchyControl(
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearIdentifier(year),
            in: app
        )
    }

    func openMonth(year: Int, month: Int, in app: XCUIApplication) {
        tapHierarchyControl(
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.monthIdentifier(year: year, month: month),
            in: app
        )
    }

    func openDay(year: Int, month: Int, day: Int, in app: XCUIApplication) {
        tapHierarchyControl(
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.dayIdentifier(year: year, month: month, day: day),
            in: app
        )
    }

    func tapTab(_ title: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[title].firstMatch
        waitForElement(tabButton)
        tabButton.tap()
    }

    func switchToTraditionalMode(in app: XCUIApplication) {
        tapTab("Settings", in: app)
        let option = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Settings.modeOption("traditional")
        )
        waitForElement(option)
        option.tap()
        tapTab("Spreads", in: app)
        _ = app.otherElements["traditionalYearView"].firstMatch.waitForExistence(timeout: 2)
    }

    func openTraditionalMonth(_ month: Int, in app: XCUIApplication) {
        let monthCell = app.otherElements["monthCell_\(month)"].firstMatch
        waitForElement(monthCell)
        monthCell.tap()
        XCTAssertTrue(app.otherElements["traditionalMonthView"].waitForExistence(timeout: 5))
    }

    func openTraditionalDay(_ day: Int, in app: XCUIApplication) {
        let dayCell = app.otherElements["dayCell_\(day)"].firstMatch
        waitForElement(dayCell)
        dayCell.tap()
        XCTAssertTrue(app.otherElements["traditionalDayView"].waitForExistence(timeout: 5))
    }

    func submitMigration(in app: XCUIApplication) {
        let submit = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.submitButton
        )
        let button = submit.waitForExistence(timeout: 2) ? submit : app.buttons["Migrate Selected"]
        waitForElement(button)
        tapElement(button)
    }

    private func tapHierarchyControl(_ identifier: String, in app: XCUIApplication) {
        let control = anyElement(in: app, identifier: identifier)
        waitForElement(control)
        tapElement(control)
    }

    private func tapElement(_ element: XCUIElement) {
        if element.isHittable {
            element.tap()
        } else {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        }
    }
}
