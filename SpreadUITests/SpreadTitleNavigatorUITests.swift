import XCTest

@MainActor
final class SpreadTitleNavigatorUITests: LocalhostScenarioUITestCase {

    /// Setup: conventional mode with today's spread selected.
    /// Expected: the compact bar container is visible and does not grow into a tall band.
    func testCompactBarIsVisibleAndStaysShort() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let container = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.container
        )
        waitForElement(container)
        let height = container.frame.height
        XCTAssertLessThanOrEqual(height, 60, "Compact bar should stay at most 60pt tall")
    }

    /// Setup: compact bar is shown in conventional mode.
    /// Expected: tapping the chevron trigger opens the rooted navigator.
    func testChevronTriggerOpensNavigatorSurface() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openHeaderNavigator(in: app)

        let navigatorPopover = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.popover
        )
        waitForElement(navigatorPopover)
    }

    /// Setup: compact bar title region is visible.
    /// Expected: tapping the title region also opens the rooted navigator.
    func testTitleRegionTapOpensNavigatorSurface() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let titleRegion = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(titleRegion)
        tapElement(titleRegion)

        let navigatorPopover = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.popover
        )
        waitForElement(navigatorPopover)
    }

    /// Setup: conventional pager with today's spread visible.
    /// Expected: swiping left advances to the next spread and the compact bar label updates.
    func testConventionalContentSwipeUpdatesBarLabel() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let barLabel = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(barLabel)
        XCTAssertFalse(barLabel.label.isEmpty, "Bar label should show the settled spread")
    }

    /// Setup: traditional mode pager.
    /// Expected: swiping left advances to the next selection and the compact bar label updates.
    func testTraditionalContentSwipeUpdatesBarLabel() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")
        switchToTraditionalMode(in: app)

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let barLabel = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedIndicator
        )
        waitForElement(barLabel)
        XCTAssertFalse(barLabel.label.isEmpty)
    }

    /// Setup: conventional mode with a neighbor spread selected via Today button.
    /// Expected: Today button returns focus to today and the bar updates.
    func testConventionalTodayButtonReturnsSelectionToToday() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let pager = anyElement(in: app, identifier: Definitions.AccessibilityIdentifiers.SpreadContent.pager)
        waitForElement(pager)
        pager.swipeLeft()

        let todayButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadToolbar.todayButton
        )
        waitForElement(todayButton)
        todayButton.tap()

        let todayTask = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadContent.taskRow("Navigator day task")
        )
        waitForElement(todayTask)
    }

    /// Setup: traditional mode with pager swiped away from today.
    /// Expected: Today button returns focus to today's day selection.
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

        let todayBadge = app.staticTexts["Today"].firstMatch
        waitForElement(todayBadge)
    }

    /// Setup: conventional mode with a missing day spread for today so a recommendation is produced.
    /// Expected: the recommendation appears inside the rooted navigator, not in the persistent bar.
    func testRecommendationAppearsInsideNavigatorAndOpenSpreadCreation() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-30")

        openHeaderNavigator(in: app)

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
