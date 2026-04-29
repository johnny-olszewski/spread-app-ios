import XCTest

@MainActor
final class TemporalContextScenarioUITests: LocalhostScenarioUITestCase {

    /// Conditions: Launch the overdue localhost fixture, keep the selected day spread open,
    /// and advance the shared AppClock by one day from the localhost temporal harness.
    /// Expected: The selected spread stays put and its dynamic title updates from Today to Yesterday.
    func testRuntimeClockAdvanceRefreshesSelectedSpreadSemantics() throws {
        let app = launchScenario(
            .overdueReview,
            extraArguments: ["-ShowTemporalHarness", "YES"]
        )
        waitForTemporalHarness(in: app)

        let todayTitle = app.staticTexts["Today"].firstMatch
        waitForElement(todayTitle)
        let initialSelectionID = temporalDiagnosticLabel(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalSelectedSpreadID
        )
        let initialRefreshRevision = temporalDiagnosticLabel(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalRefreshRevision
        )

        advanceClockByOneDay(in: app)
        waitForTemporalDiagnosticChange(
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalRefreshRevision,
            from: initialRefreshRevision,
            in: app
        )

        let yesterdayTitle = app.staticTexts["Yesterday"].firstMatch
        waitForElement(yesterdayTitle)

        let currentSelectionID = temporalDiagnosticLabel(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalSelectedSpreadID
        )
        XCTAssertEqual(currentSelectionID, initialSelectionID)

        waitForTemporalDiagnostic(
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalSelectedSpreadTitle,
            in: app,
            satisfying: { $0.contains("Yesterday") }
        )
    }

    /// Conditions: Launch the overdue localhost fixture, open task creation, and advance the shared AppClock.
    /// Expected: The live clock diagnostics refresh, but the sheet keeps its presentation-frozen temporal defaults.
    func testTaskCreationKeepsFrozenTemporalContextAfterRuntimeClockAdvance() throws {
        let app = launchScenario(
            .overdueReview,
            extraArguments: ["-ShowTemporalHarness", "YES"]
        )

        openCreateTask(in: app)
        waitForTemporalHarness(in: app)

        let initialRefreshRevision = temporalDiagnosticLabel(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalRefreshRevision
        )
        let frozenToday = temporalDiagnosticLabel(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalPresentedToday
        )

        advanceClockByOneDay(in: app)

        waitForTemporalDiagnosticChange(
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalRefreshRevision,
            from: initialRefreshRevision,
            in: app
        )
        waitForTemporalDiagnostic(
            identifier: Definitions.AccessibilityIdentifiers.Debug.temporalToday,
            in: app,
            satisfying: { $0.contains("2026-01-13") }
        )

        XCTAssertEqual(
            temporalDiagnosticLabel(
                in: app,
                identifier: Definitions.AccessibilityIdentifiers.Debug.temporalPresentedToday
            ),
            frozenToday
        )
        XCTAssertTrue(
            app.textFields[Definitions.AccessibilityIdentifiers.TaskCreationSheet.titleField].exists
        )
    }
}
