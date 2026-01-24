//
//  SpreadUITests.swift
//  SpreadUITests
//
//  Created by Johnny O on 1/6/26.
//

import XCTest

final class SpreadUITests: XCTestCase {

    private func launchApp(mockDataSet: String, today: String = "2026-01-15") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppEnvironment", "testing",
            "-MockDataSet", mockDataSet,
            "-Today", today
        ]
        app.launch()
        return app
    }

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    /// Conditions: Launch the app from a UI test.
    /// Expected: App launches successfully without errors.
    @MainActor
    func testExample() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        // Use XCTAssert and related functions to verify your tests produce the correct results.
    }

    /// Conditions: Start with empty mock data and create a 2026 year spread.
    /// Expected: Year tab shows 2026 and content area title shows 2026.
    @MainActor
    func testCreateYearSpreadFromEmptyState() throws {
        let app = launchApp(mockDataSet: "empty", today: "2026-01-01")

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.createButton]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let yearSegment = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodSegment("year")
        ]
        XCTAssertTrue(yearSegment.waitForExistence(timeout: 5))
        yearSegment.tap()

        let createSpreadButton = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton
        ]
        XCTAssertTrue(createSpreadButton.waitForExistence(timeout: 5))
        createSpreadButton.tap()

        let yearTab = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearIdentifier(2026)
        ]
        XCTAssertTrue(yearTab.waitForExistence(timeout: 5))

        let contentTitle = app.staticTexts[
            Definitions.AccessibilityIdentifiers.SpreadContent.title
        ]
        XCTAssertTrue(contentTitle.waitForExistence(timeout: 5))
        XCTAssertEqual(contentTitle.label, "2026")
    }

    /// Conditions: Boundary data set with multiple years (2026/2027).
    /// Expected: Selecting a different year from the menu updates the year tab.
    @MainActor
    func testYearMenuSelectionUpdatesYearTab() throws {
        let app = launchApp(mockDataSet: "boundary")

        let yearTab = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearIdentifier(2026)
        ]
        XCTAssertTrue(yearTab.waitForExistence(timeout: 5))
        yearTab.tap()

        let yearMenuItem = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearMenuItem(2027)
        ]
        XCTAssertTrue(yearMenuItem.waitForExistence(timeout: 5))
        yearMenuItem.tap()

        let updatedYearTab = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.yearIdentifier(2027)
        ]
        XCTAssertTrue(updatedYearTab.waitForExistence(timeout: 5))
    }

    /// Conditions: Boundary data set with current and next month in 2026.
    /// Expected: Selecting a different month from the menu updates the month tab.
    @MainActor
    func testMonthMenuSelectionUpdatesMonthTab() throws {
        let app = launchApp(mockDataSet: "boundary")

        let monthTab = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.monthIdentifier(year: 2026, month: 1)
        ]
        XCTAssertTrue(monthTab.waitForExistence(timeout: 5))
        monthTab.tap()

        let monthMenuItem = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.monthMenuItem(year: 2026, month: 2)
        ]
        XCTAssertTrue(monthMenuItem.waitForExistence(timeout: 5))
        monthMenuItem.tap()

        let updatedMonthTab = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.monthIdentifier(year: 2026, month: 2)
        ]
        XCTAssertTrue(updatedMonthTab.waitForExistence(timeout: 5))
    }

    /// Conditions: Open the spread creation sheet.
    /// Expected: Multiday selection shows presets and start/end date pickers only.
    @MainActor
    func testMultidaySelectionShowsPresetAndRangePickers() throws {
        let app = launchApp(mockDataSet: "empty")

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.createButton]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let multidaySegment = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodSegment("multiday")
        ]
        XCTAssertTrue(multidaySegment.waitForExistence(timeout: 5))
        multidaySegment.tap()

        let thisWeekPreset = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayPreset("thisWeek")
        ]
        XCTAssertTrue(thisWeekPreset.waitForExistence(timeout: 5))

        let nextWeekPreset = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayPreset("nextWeek")
        ]
        XCTAssertTrue(nextWeekPreset.waitForExistence(timeout: 5))

        let startDatePicker = app.datePickers[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayStartDatePicker
        ]
        XCTAssertTrue(startDatePicker.waitForExistence(timeout: 5))

        let endDatePicker = app.datePickers[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.multidayEndDatePicker
        ]
        XCTAssertTrue(endDatePicker.waitForExistence(timeout: 5))

        let standardDatePicker = app.datePickers[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.standardDatePicker
        ]
        XCTAssertFalse(standardDatePicker.exists)
    }

    /// Conditions: Open the spread creation sheet and tap cancel.
    /// Expected: The creation sheet dismisses.
    @MainActor
    func testCancelDismissesCreateSheet() throws {
        let app = launchApp(mockDataSet: "empty")

        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.SpreadHierarchyTabBar.createButton]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let cancelButton = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.cancelButton
        ]
        XCTAssertTrue(cancelButton.waitForExistence(timeout: 5))
        cancelButton.tap()

        let createSheetButton = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton
        ]
        XCTAssertFalse(createSheetButton.waitForExistence(timeout: 2))
    }

    /// Conditions: Measure app launch performance from a UI test.
    /// Expected: Launch completes and metrics are captured.
    @MainActor
    func testLaunchPerformance() throws {
        // This measures how long it takes to launch your application.
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
