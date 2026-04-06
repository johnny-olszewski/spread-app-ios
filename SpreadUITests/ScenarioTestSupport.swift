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
        case multidayLayout = "scenarioMultidayLayout"
        case spreadNavigator = "scenarioSpreadNavigator"
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

    func tapTaskForEditing(title: String, in app: XCUIApplication) {
        let taskRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow(title)
        )
        if taskRow.waitForExistence(timeout: 2) {
            taskRow.tap()
        } else {
            let taskLabel = app.staticTexts[title].firstMatch
            waitForElement(taskLabel)
            taskLabel.tap()
        }

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

    func tapSourceMigrationButton(taskTitle: String, in app: XCUIApplication) {
        let button = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.sourceButton(taskTitle)
        )
        waitForElement(button)
        tapElement(button)
    }

    func expandDestinationMigrationSection(in app: XCUIApplication) {
        let header = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationSectionHeader
        )
        waitForElement(header)
        tapElement(header)
    }

    func tapDestinationMigrationRow(taskTitle: String, in app: XCUIApplication) {
        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationRow(taskTitle)
        )
        waitForElement(row)
        tapElement(row)
    }

    func tapDestinationMigrateAll(in app: XCUIApplication) {
        let button = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.destinationMigrateAllButton
        )
        waitForElement(button)
        tapElement(button)
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
        openHeaderNavigator(in: app)
        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearRow(year)
        )
        waitForElement(row)
        tapElement(row)
        waitForNavigatorDismissal(in: app)
    }

    func openMonth(year: Int, month: Int, in app: XCUIApplication) {
        openHeaderNavigator(in: app)
        expandNavigatorMonthIfNeeded(year: year, month: month, in: app)
        let viewMonthButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.viewMonthButton(year: year, month: month)
        )
        waitForElement(viewMonthButton)
        tapElement(viewMonthButton)
        waitForNavigatorDismissal(in: app)
    }

    func openDay(year: Int, month: Int, day: Int, in app: XCUIApplication) {
        openHeaderNavigator(in: app)
        expandNavigatorMonthIfNeeded(year: year, month: month, in: app)
        let dayTile = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(
                date: Calendar(identifier: .gregorian).date(from: DateComponents(year: year, month: month, day: day))!,
                calendar: Calendar(identifier: .gregorian)
            )
        )
        waitForElement(dayTile)
        tapElement(dayTile)
        waitForNavigatorDismissal(in: app)
    }

    func openDayInStrip(_ day: Int, in app: XCUIApplication) {
        let item = anyElement(
            in: app,
            identifier: "spreads.strip.day.\(Definitions.AccessibilityIdentifiers.token(String(day)))"
        )
        waitForElement(item)
        tapElement(item)
    }

    func openYearInStrip(_ year: Int, in app: XCUIApplication) {
        let item = anyElement(
            in: app,
            identifier: "spreads.strip.year.\(Definitions.AccessibilityIdentifiers.token(String(year)))"
        )
        waitForElement(item)
        tapElement(item)
    }

    func tapViewMonth(year: Int, month: Int, in app: XCUIApplication) {
        let button = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.viewMonthButton(year: year, month: month)
        )
        waitForElement(button)
        tapElement(button)
    }

    func expandNavigatorMonthIfNeeded(year: Int, month: Int, in app: XCUIApplication) {
        let grid = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: year, month: month)
        )
        if grid.waitForExistence(timeout: 1) {
            return
        }

        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: year, month: month)
        )
        waitForElement(row)
        tapElement(row)
        waitForElement(grid)
    }

    func tapTab(_ title: String, in app: XCUIApplication) {
        let tabButton = app.tabBars.buttons[title].firstMatch
        if tabButton.waitForExistence(timeout: 2) {
            tabButton.tap()
            return
        }

        ensureSidebarIsVisibleIfNeeded(in: app)

        let sidebarIdentifier = Definitions.AccessibilityIdentifiers.Navigation.sidebarItem(title.lowercased())
        let identifiedSidebarItem = anyElement(in: app, identifier: sidebarIdentifier)
        if identifiedSidebarItem.waitForExistence(timeout: 2) {
            tapElement(identifiedSidebarItem)
            return
        }

        let sidebarButton = app.buttons[title].firstMatch
        if sidebarButton.waitForExistence(timeout: 2) {
            sidebarButton.tap()
            return
        }

        let sidebarCell = app.cells.containing(.staticText, identifier: title).firstMatch
        if sidebarCell.waitForExistence(timeout: 2) {
            sidebarCell.tap()
            return
        }

        let sidebarText = app.staticTexts[title].firstMatch
        waitForElement(sidebarText)
        sidebarText.tap()
    }

    func ensureSidebarIsVisibleIfNeeded(in app: XCUIApplication) {
        guard !app.tabBars.firstMatch.exists else { return }

        let spreadsSidebarItem = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Navigation.sidebarItem("spreads")
        )
        if spreadsSidebarItem.waitForExistence(timeout: 1) {
            return
        }

        let sidebarButtons = [
            "Sidebar",
            "Show Sidebar",
            "Toggle Sidebar"
        ]

        for label in sidebarButtons {
            let button = app.buttons[label].firstMatch
            if button.waitForExistence(timeout: 1) {
                button.tap()
                if spreadsSidebarItem.waitForExistence(timeout: 2) {
                    return
                }
            }
        }

        let sidebarPredicate = NSPredicate(format: "label CONTAINS[c] 'sidebar' OR identifier CONTAINS[c] 'sidebar'")
        let genericSidebarButton = app.buttons.matching(sidebarPredicate).firstMatch
        if genericSidebarButton.waitForExistence(timeout: 1) {
            genericSidebarButton.tap()
        }
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
    }

    func openTraditionalMonth(_ month: Int, in app: XCUIApplication) {
        tapTab("Spreads", in: app)
        let yearView = anyElement(in: app, identifier: "traditionalYearView")
        waitForElement(yearView, timeout: 10)
        let monthCell = anyElement(in: app, identifier: "monthCell_\(month)")
        waitForElement(monthCell, timeout: 10)
        monthCell.tap()
        XCTAssertTrue(anyElement(in: app, identifier: "traditionalMonthView").waitForExistence(timeout: 5))
    }

    func openTraditionalDay(_ day: Int, in app: XCUIApplication) {
        let monthView = anyElement(in: app, identifier: "traditionalMonthView")
        waitForElement(monthView)
        let dayCell = anyElement(in: app, identifier: "dayCell_\(day)")
        waitForElement(dayCell)
        dayCell.tap()
        XCTAssertTrue(anyElement(in: app, identifier: "traditionalDayView").waitForExistence(timeout: 5))
    }

    func openHeaderNavigator(in app: XCUIApplication) {
        let titleButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.titleButton
        )
        if titleButton.waitForExistence(timeout: 5) {
            tapElement(titleButton)
            return
        }
        XCTFail("Spread header navigator title button was not found")
    }

    func waitForNavigatorDismissal(in app: XCUIApplication, timeout: TimeInterval = 5) {
        let surface = navigatorSurface(in: app)
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: surface)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    func tapNavigatorYearDisclosure(_ year: Int, in app: XCUIApplication) {
        let disclosure = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearDisclosure(year)
        )
        if disclosure.waitForExistence(timeout: 2) {
            tapElement(disclosure)
            return
        }

        let row = anyElement(
            in: navigatorSurface(in: app),
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearRow(year)
        )
        if row.waitForExistence(timeout: 2) {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            return
        }

        let labeledRow = navigatorSurface(in: app)
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", String(year)))
            .firstMatch
        if labeledRow.waitForExistence(timeout: 2) {
            labeledRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            return
        }

        let disclosureButtons = navigatorSurface(in: app)
            .buttons
            .matching(NSPredicate(format: "label == %@ OR label == %@", "Go Down", "Go Right"))
        let disclosureButton = disclosureButtons.element(boundBy: 0)
        waitForElement(disclosureButton)
        disclosureButton.tap()
    }

    func waitForNavigatorYearPage(_ year: Int, in app: XCUIApplication) {
        let page = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearPage(year)
        )
        waitForElement(page)
    }

    func swipeNavigatorToNextYear(in app: XCUIApplication) {
        let surface = navigatorSurface(in: app)
        waitForElement(surface)
        surface.swipeLeft()
    }

    func tapNavigatorMonthDisclosure(year: Int, month: Int, in app: XCUIApplication) {
        let disclosure = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthDisclosure(year: year, month: month)
        )
        if disclosure.waitForExistence(timeout: 2) {
            tapElement(disclosure)
            return
        }

        let row = anyElement(
            in: navigatorSurface(in: app),
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: year, month: month)
        )
        if row.waitForExistence(timeout: 2) {
            row.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            return
        }

        let monthName = Calendar.current.monthSymbols[month - 1]
        let labeledRow = navigatorSurface(in: app)
            .descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", monthName))
            .firstMatch
        if labeledRow.waitForExistence(timeout: 2) {
            labeledRow.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
            return
        }

        let disclosureButtons = navigatorSurface(in: app)
            .buttons
            .matching(NSPredicate(format: "label == %@ OR label == %@", "Go Down", "Go Right"))
        let disclosureButton = disclosureButtons.element(boundBy: 1)
        waitForElement(disclosureButton)
        disclosureButton.tap()
    }

    func tapNavigatorYearRow(_ year: Int, in app: XCUIApplication) {
        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearRow(year)
        )
        if row.waitForExistence(timeout: 2) {
            tapElement(row)
            return
        }

        let fallback = app.buttons[String(year)].firstMatch
        waitForElement(fallback)
        tapElement(fallback)
    }

    func tapNavigatorMonthRow(year: Int, month: Int, in app: XCUIApplication) {
        let row = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: year, month: month)
        )
        if row.waitForExistence(timeout: 2) {
            tapElement(row)
            return
        }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .init(identifier: "UTC")!
        formatter.dateFormat = "MMMM"
        let date = formatter.calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        let fallback = app.buttons[formatter.string(from: date)].firstMatch
        waitForElement(fallback)
        tapElement(fallback)
    }

    func tapNavigatorDayTile(
        year: Int,
        month: Int,
        day: Int,
        calendar: Calendar,
        in app: XCUIApplication
    ) {
        let date = calendar.date(from: DateComponents(year: year, month: month, day: day))!
        let tile = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(date: date, calendar: calendar)
        )
        waitForElement(tile)
        tapElement(tile)
    }

    private func tapHierarchyControl(_ identifier: String, in app: XCUIApplication) {
        let control = anyElement(in: app, identifier: identifier)
        waitForElement(control)
        tapElement(control)
    }

    private func navigatorSurface(in app: XCUIApplication) -> XCUIElement {
        anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.popover)
    }

    private func anyElement(
        in element: XCUIElement,
        identifier: String
    ) -> XCUIElement {
        element.descendants(matching: .any)[identifier].firstMatch
    }

    func tapElement(_ element: XCUIElement) {
        let frame = element.frame
        if !frame.isEmpty {
            element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            return
        }

        element.tap()
    }
}
