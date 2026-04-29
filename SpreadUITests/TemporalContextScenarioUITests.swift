import XCTest

@MainActor
final class TemporalContextScenarioUITests: LocalhostScenarioUITestCase {

    /// Conditions: Launch the overdue localhost fixture, keep the selected day spread open,
    /// and advance the shared AppClock by one day from the Debug tab.
    /// Expected: The selected spread stays put and its dynamic title updates from Today to Yesterday.
    func testRuntimeClockAdvanceRefreshesSelectedSpreadSemantics() throws {
        let app = launchScenario(.overdueReview)

        let todayTitle = app.staticTexts["Today"].firstMatch
        waitForElement(todayTitle)

        advanceClockByOneDay(in: app)
        openSpreads(in: app)

        let yesterdayTitle = app.staticTexts["Yesterday"].firstMatch
        let deadline = Date().addingTimeInterval(5)
        repeat {
            if yesterdayTitle.exists {
                break
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        } while Date() < deadline

        XCTAssertTrue(yesterdayTitle.exists)
    }
}
