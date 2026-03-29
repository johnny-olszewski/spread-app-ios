import XCTest

@MainActor
final class SpreadContentInteractionUITests: LocalhostScenarioUITestCase {

    func testTaskRowTapOpensExistingTaskEditSheet() throws {
        let app = launchScenario(.reassignment)

        tapTaskForEditing(title: "Reassign me", in: app)

        XCTAssertTrue(
            app.buttons[Definitions.AccessibilityIdentifiers.TaskDetailSheet.saveButton]
                .waitForExistence(timeout: 5)
        )
    }

    func testMultidaySpreadShowsEveryDaySectionIncludingEmptyDays() throws {
        let app = launchScenario(.multidayLayout, today: "2026-01-10")

        XCTAssertTrue(
            app.scrollViews[Definitions.AccessibilityIdentifiers.SpreadContent.multidayGrid]
                .waitForExistence(timeout: 5)
        )
        XCTAssertTrue(app.staticTexts["January 10"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["January 11"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["January 12"].waitForExistence(timeout: 5))

        XCTAssertTrue(
            app.staticTexts["Middle day task"].waitForExistence(timeout: 5)
        )
        XCTAssertFalse(app.staticTexts["Hidden multiday note"].exists)

        XCTAssertEqual(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "No tasks for this day.")).count,
            2
        )
    }
}
