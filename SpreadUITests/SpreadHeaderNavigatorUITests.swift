import XCTest

@MainActor
final class SpreadHeaderNavigatorUITests: LocalhostScenarioUITestCase {

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        return calendar
    }

    func testConventionalMonthNavigatorOpensWithCurrentContextExpanded() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)

        let marchRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: 2026, month: 3)
        )
        waitForElement(marchRow)

        let marchGrid = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: 2026, month: 3)
        )
        waitForElement(marchGrid)

        let dayTile = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(
                date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!,
                calendar: calendar
            )
        )
        waitForElement(dayTile)
    }

    func testConventionalNavigatorDisclosureCollapsesAndReexpandsYear() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)

        let marchRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: 2026, month: 3)
        )
        waitForElement(marchRow)

        tapNavigatorYearDisclosure(2026, in: app)
        XCTAssertFalse(marchRow.waitForExistence(timeout: 1))

        tapNavigatorYearDisclosure(2026, in: app)
        waitForElement(marchRow)

        let marchGrid = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: 2026, month: 3)
        )
        XCTAssertFalse(marchGrid.waitForExistence(timeout: 1))

        tapNavigatorMonthDisclosure(year: 2026, month: 3, in: app)
        waitForElement(marchGrid)
    }

    func testConventionalNavigatorSelectingDayNavigatesAndDismisses() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        openMonth(year: 2026, month: 3, in: app)
        openHeaderNavigator(in: app)
        tapNavigatorDayTile(year: 2026, month: 3, day: 29, calendar: calendar, in: app)

        let selectedCapsule = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedCapsule
        )
        waitForElement(selectedCapsule)
        XCTAssertEqual(selectedCapsule.label, "29")

        let marchRow = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.monthRow(year: 2026, month: 3)
        )
        XCTAssertFalse(marchRow.waitForExistence(timeout: 1))
    }

    func testTraditionalMonthNavigatorShowsDayGridWithoutMultidayTiles() throws {
        let app = launchScenario(
            .spreadNavigator,
            today: "2026-03-29",
            extraArguments: ["-BujoMode", "traditional"]
        )

        openTraditionalMonth(3, in: app)
        openHeaderNavigator(in: app)

        let marchGrid = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.grid(year: 2026, month: 3)
        )
        waitForElement(marchGrid)

        let dayTile = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.dayTile(
                date: calendar.date(from: DateComponents(year: 2026, month: 3, day: 29))!,
                calendar: calendar
            )
        )
        waitForElement(dayTile)

        let multidayTile = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.multidayTile(
                startDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 20))!,
                endDate: calendar.date(from: DateComponents(year: 2026, month: 3, day: 22))!,
                calendar: calendar
            )
        )
        XCTAssertFalse(multidayTile.waitForExistence(timeout: 1))
    }
}
