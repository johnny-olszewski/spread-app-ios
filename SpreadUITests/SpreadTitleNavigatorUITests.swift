import XCTest

@MainActor
final class SpreadTitleNavigatorUITests: LocalhostScenarioUITestCase {

    func testConventionalStripTapSelectsVisibleNeighbor() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let neighbor = anyElement(in: app, identifier: "spreads.strip.day.31")
        waitForElement(neighbor)
        tapElement(neighbor)

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        XCTAssertTrue(selectedIndicator.label.contains("31"))
    }

    func testSelectedCapsuleOpensNavigatorSurfaceAndHeaderTitleIsRemoved() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        XCTAssertFalse(app.staticTexts[Definitions.AccessibilityIdentifiers.SpreadContent.title].exists)

        openHeaderNavigator(in: app)

        let currentYearRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.yearRow(2026)
        )
        waitForElement(currentYearRow)
    }

    func testConventionalContentSwipeUpdatesSelectedStripAfterSettle() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        XCTAssertTrue(selectedIndicator.label.contains("31"))
    }

    func testTraditionalContentSwipeUpdatesSelectedStripAfterSettle() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")
        switchToTraditionalMode(in: app)

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        XCTAssertEqual(selectedIndicator.label, "Jan")
    }

    func testConventionalTodayButtonReturnsSelectionToToday() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let neighbor = anyElement(in: app, identifier: "spreads.strip.day.31")
        waitForElement(neighbor)
        tapElement(neighbor)

        let todayButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
        )
        waitForElement(todayButton)
        todayButton.tap()

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        let todayTask = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator day task")
        )
        waitForElement(todayTask)
    }

    func testTraditionalTodayButtonReturnsSelectionToToday() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")
        switchToTraditionalMode(in: app)

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let todayButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
        )
        waitForElement(todayButton)
        todayButton.tap()

        let selectedIndicator = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(selectedIndicator)
        let todayBadge = app.staticTexts["Today"].firstMatch
        waitForElement(todayBadge)
    }

    func testSingleRecommendationOpensSpreadCreationSheet() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-30")

        let dayRecommendation = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.recommendation("day")
        )
        waitForElement(dayRecommendation)
        tapElement(dayRecommendation)

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton]
        waitForElement(createButton)
    }
}
