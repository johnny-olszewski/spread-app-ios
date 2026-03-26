import XCTest

@MainActor
class LocalhostScenarioUITestCase: XCTestCase {

    enum ScenarioDataSet: String {
        case assignmentExistingSpread = "scenarioAssignmentExistingSpread"
        case assignmentInboxFallback = "scenarioAssignmentInboxFallback"
        case inboxResolution = "scenarioInboxResolution"
        case migrationMonthBound = "scenarioMigrationMonthBound"
        case migrationDayUpgrade = "scenarioMigrationDayUpgrade"
        case reassignment = "scenarioReassignment"
        case overdueReview = "scenarioOverdueReview"
        case overdueInbox = "scenarioOverdueInbox"
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

    func openMigrationReview(in app: XCUIApplication) {
        let identifiedButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Migration.reviewButton
        )
        let button = identifiedButton.waitForExistence(timeout: 2) ? identifiedButton : app.buttons["Review"]
        waitForElement(button)
        button.tap()
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
        button.tap()
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
        let button = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearIdentifier(year)
        ]
        waitForElement(button)
        button.tap()
    }

    func openMonth(year: Int, month: Int, in app: XCUIApplication) {
        let button = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.monthIdentifier(year: year, month: month)
        ]
        waitForElement(button)
        button.tap()
    }

    func openDay(year: Int, month: Int, day: Int, in app: XCUIApplication) {
        let button = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.dayIdentifier(year: year, month: month, day: day)
        ]
        waitForElement(button)
        button.tap()
    }
}
