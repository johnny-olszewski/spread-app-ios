import XCTest

@MainActor
final class SpreadHeaderNavigatorUITests: LocalhostScenarioUITestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    func testConventionalNavigatorOpensOnCurrentYearWithCurrentMonthExpanded() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)

        let popover = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.popover
        )
        waitForElement(popover)
        expandNavigatorMonthIfNeeded(year: 2026, month: 3, in: app)
        waitForElement(
            anyElement(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: 2026, month: 3)
            )
        )
    }

    func testNavigatorPagingUpdatesYearTitleAfterSettling() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)
        expandNavigatorMonthIfNeeded(year: 2026, month: 3, in: app)

        XCTAssertTrue(app.navigationBars.staticTexts["2026"].firstMatch.waitForExistence(timeout: 2))
        swipeNavigatorToNextYear(in: app)
        XCTAssertTrue(app.navigationBars.staticTexts["2027"].firstMatch.waitForExistence(timeout: 2))
    }

    func testConventionalNavigatorShowsViewMonthAndDisablesDatesWithoutTargets() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)

        let viewMonthButton = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.viewMonthButton(year: 2026, month: 3)
        )
        waitForElement(viewMonthButton)

        let disabledDay = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(
                date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 11))!,
                calendar: calendar
            )
        )
        waitForElement(disabledDay)
        XCTAssertFalse(disabledDay.isEnabled)
    }

    func testConventionalNavigatorShowsChoiceForOverlappingDayAndMultidayTargets() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)
        tapNavigatorDayTile(year: 2026, month: 3, day: 21, calendar: calendar, in: app)

        let dayChoice = app.buttons["View Day"].firstMatch
        waitForElement(dayChoice)
        let multidayChoice = app.buttons["20-22"].firstMatch
        waitForElement(multidayChoice)
    }
}
