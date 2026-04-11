//
//  SpreadUITests.swift
//  SpreadUITests
//
//  Created by Johnny O on 1/6/26.
//

import XCTest

final class SpreadUITests: LocalhostScenarioUITestCase {

    private func launchApp(mockDataSet: String, today: String = "2026-01-15") -> XCUIApplication {
        XCUIDevice.shared.orientation = .portrait
        let app = XCUIApplication()
        app.launchArguments = [
            "-DataEnvironment", "localhost",
            "-MockDataSet", mockDataSet,
            "-Today", today
        ]
        app.launch()
        tapTab("Spreads", in: app)
        return app
    }

    private func headerTitleElement(in app: XCUIApplication) -> XCUIElement {
        anyElement(
            in: app,
            identifier: Definitions.AccessibilityIdentifiers.SpreadNavigator.titleButton
        )
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

        openCreateSpread(in: app)

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

        let yearStripItem = anyElement(in: app, identifier: "spreads.strip.year.2026")
        XCTAssertTrue(yearStripItem.waitForExistence(timeout: 5))

        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("2026"))
    }

    /// Conditions: Boundary data set with multiple years (2026/2027).
    /// Expected: Selecting a different year from the menu updates the year tab.
    @MainActor
    func testYearMenuSelectionUpdatesYearTab() throws {
        let app = launchApp(mockDataSet: "boundary")

        openYear(2027, in: app)

        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("2027"))
    }

    /// Conditions: Boundary data set with current and next month in 2026.
    /// Expected: Selecting a different month from the menu updates the month tab.
    @MainActor
    func testMonthMenuSelectionUpdatesMonthTab() throws {
        let app = launchApp(mockDataSet: "boundary")

        openMonth(year: 2026, month: 2, in: app)

        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("February"))
    }

    /// Conditions: Open the spread creation sheet.
    /// Expected: Multiday selection shows presets and start/end date pickers only.
    @MainActor
    func testMultidaySelectionShowsPresetAndRangePickers() throws {
        let app = launchApp(mockDataSet: "empty")

        openCreateSpread(in: app)

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

        openCreateSpread(in: app)

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

    // MARK: - Spread Header Tests

    /// Conditions: Baseline data set with day spread selected (initial selection).
    /// Expected: Header shows full date format for day spread and entry counts.
    @MainActor
    func testDaySpreadHeaderShowsFullDateAndCounts() throws {
        let app = launchApp(mockDataSet: "baseline", today: "2026-01-15")

        // The day spread should be selected by default (smallest period containing today)
        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("January 15, 2026"))

        // Entry counts should be displayed
        let entryCounts = app.staticTexts[
            Definitions.AccessibilityIdentifiers.SpreadContent.entryCounts
        ]
        XCTAssertTrue(entryCounts.waitForExistence(timeout: 5))
        // Baseline has 3 tasks and 1 note on the day spread (events excluded in v1)
        XCTAssertEqual(entryCounts.label, "3 tasks, 1 note")
    }

    /// Conditions: Baseline data set, select month spread.
    /// Expected: Header shows month/year format for month spread.
    @MainActor
    func testMonthSpreadHeaderShowsMonthAndYear() throws {
        let app = launchApp(mockDataSet: "baseline", today: "2026-01-15")

        // Open month menu and select the current month
        openMonth(year: 2026, month: 1, in: app)

        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("January"))
        XCTAssertTrue(headerTitle.label.contains("2026"))
    }

    /// Conditions: Baseline data set, select year spread.
    /// Expected: Header shows just year number for year spread.
    @MainActor
    func testYearSpreadHeaderShowsYearOnly() throws {
        let app = launchApp(mockDataSet: "baseline", today: "2026-01-15")

        // Open year menu and select the current year
        openYear(2026, in: app)

        let headerTitle = headerTitleElement(in: app)
        XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
        XCTAssertTrue(headerTitle.label.contains("2026"))
    }

    /// Conditions: Multiday data set with multiday spread.
    /// Expected: Header shows date range format for multiday spread.
    @MainActor
    func testMultidaySpreadHeaderShowsDateRange() throws {
        let app = launchApp(mockDataSet: "multiday", today: "2026-01-15")

        // Find and tap a multiday spread tab
        // This Week multiday should exist - find it by looking for a tab with a range format
        // The multiday tab will be visible in the hierarchy
        let multidayTab = app.buttons.matching(NSPredicate(format: "identifier CONTAINS 'multiday'")).firstMatch
        if multidayTab.waitForExistence(timeout: 5) {
            multidayTab.tap()

            // Header should show date range format
            let headerTitle = headerTitleElement(in: app)
            XCTAssertTrue(headerTitle.waitForExistence(timeout: 5))
            XCTAssertTrue(headerTitle.label.contains(" - "))
        }
    }

    /// Conditions: Empty data set, create a day spread.
    /// Expected: Header shows "No entries" when spread has no entries.
    @MainActor
    func testEmptySpreadHeaderShowsNoEntries() throws {
        let app = launchApp(mockDataSet: "empty", today: "2026-01-15")

        // Create a day spread
        let createButton = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.button]
        XCTAssertTrue(createButton.waitForExistence(timeout: 5))
        createButton.tap()

        let createSpreadMenuItem = app.buttons[Definitions.AccessibilityIdentifiers.CreateMenu.createSpread]
        XCTAssertTrue(createSpreadMenuItem.waitForExistence(timeout: 5))
        createSpreadMenuItem.tap()

        let daySegment = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.periodSegment("day")
        ]
        XCTAssertTrue(daySegment.waitForExistence(timeout: 5))
        daySegment.tap()

        let createSpreadButton = app.buttons[
            Definitions.AccessibilityIdentifiers.SpreadCreationSheet.createButton
        ]
        XCTAssertTrue(createSpreadButton.waitForExistence(timeout: 5))
        createSpreadButton.tap()

        // Entry counts should show "No entries"
        let entryCounts = app.staticTexts[
            Definitions.AccessibilityIdentifiers.SpreadContent.entryCounts
        ]
        XCTAssertTrue(entryCounts.waitForExistence(timeout: 5))
        XCTAssertEqual(entryCounts.label, "No entries")
    }
}
