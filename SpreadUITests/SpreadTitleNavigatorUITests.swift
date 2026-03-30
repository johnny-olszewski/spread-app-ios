import XCTest

@MainActor
final class SpreadTitleNavigatorUITests: LocalhostScenarioUITestCase {

    func testConventionalStripTapSelectsVisibleNeighbor() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        let neighbor = anyElement(in: app, identifier: "spreads.strip.day.31")
        waitForElement(neighbor)
        tapElement(neighbor)

        let selectedCapsule = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadStrip.selectedCapsule
        )
        waitForElement(selectedCapsule)
        XCTAssertEqual(selectedCapsule.label, "31")
    }

    func testSelectedCapsuleOpensNavigatorSurfaceAndHeaderTitleIsRemoved() throws {
        let app = launchScenario(.spreadNavigator, today: "2026-03-29")

        XCTAssertFalse(app.staticTexts[Definitions.AccessibilityIdentifiers.SpreadContent.title].exists)

        openHeaderNavigator(in: app)

        let navigatorSurface = anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.popover
        )
        waitForElement(navigatorSurface)
    }
}
