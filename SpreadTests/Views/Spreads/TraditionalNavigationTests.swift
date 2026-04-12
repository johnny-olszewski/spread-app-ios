import Foundation
import Testing
@testable import Spread

/// Tests for traditional mode navigation state transitions.
struct TraditionalNavigationTests {

    // MARK: - Test Helpers

    private static var testCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .init(identifier: "UTC")!
        calendar.firstWeekday = 1
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int = 1) -> Date {
        testCalendar.date(from: .init(year: year, month: month, day: day))!
    }

    // MARK: - Destination Hashable Conformance

    /// Month destinations with the same date should be equal.
    /// Setup: Two .month destinations with the same date.
    /// Expected: They are equal and have the same hash.
    @Test func testMonthDestinationsWithSameDateAreEqual() {
        let date = Self.makeDate(year: 2026, month: 3)
        let dest1 = TraditionalNavigationDestination.month(date)
        let dest2 = TraditionalNavigationDestination.month(date)

        #expect(dest1 == dest2)
        #expect(dest1.hashValue == dest2.hashValue)
    }

    /// Month destinations with different dates should not be equal.
    /// Setup: Two .month destinations with different dates.
    /// Expected: They are not equal.
    @Test func testMonthDestinationsWithDifferentDatesAreNotEqual() {
        let march = Self.makeDate(year: 2026, month: 3)
        let april = Self.makeDate(year: 2026, month: 4)
        let dest1 = TraditionalNavigationDestination.month(march)
        let dest2 = TraditionalNavigationDestination.month(april)

        #expect(dest1 != dest2)
    }

    /// Day destinations with the same date should be equal.
    /// Setup: Two .day destinations with the same date.
    /// Expected: They are equal.
    @Test func testDayDestinationsWithSameDateAreEqual() {
        let date = Self.makeDate(year: 2026, month: 3, day: 15)
        let dest1 = TraditionalNavigationDestination.day(date)
        let dest2 = TraditionalNavigationDestination.day(date)

        #expect(dest1 == dest2)
    }

    /// Month and day destinations are not equal even with the same date.
    /// Setup: A .month and .day destination with the same date.
    /// Expected: They are not equal.
    @Test func testMonthAndDayDestinationsAreNotEqual() {
        let date = Self.makeDate(year: 2026, month: 3)
        let monthDest = TraditionalNavigationDestination.month(date)
        let dayDest = TraditionalNavigationDestination.day(date)

        #expect(monthDest != dayDest)
    }

    // MARK: - Navigation Path Transitions

    /// Appending a month destination simulates year → month drill-in.
    /// Setup: Empty path, append .month.
    /// Expected: Path has one element.
    @Test func testYearToMonthTransition() {
        var path: [TraditionalNavigationDestination] = []
        let march = Self.makeDate(year: 2026, month: 3)

        path.append(.month(march))

        #expect(path.count == 1)
        #expect(path[0] == .month(march))
    }

    /// Appending month then day simulates year → month → day drill-in.
    /// Setup: Empty path, append .month then .day.
    /// Expected: Path has two elements in correct order.
    @Test func testYearToMonthToDayTransition() {
        var path: [TraditionalNavigationDestination] = []
        let march = Self.makeDate(year: 2026, month: 3)
        let march15 = Self.makeDate(year: 2026, month: 3, day: 15)

        path.append(.month(march))
        path.append(.day(march15))

        #expect(path.count == 2)
        #expect(path[0] == .month(march))
        #expect(path[1] == .day(march15))
    }

    /// Removing last from a month+day path simulates day → month back navigation.
    /// Setup: Path with [month, day], remove last.
    /// Expected: Path has one element (month).
    @Test func testDayBackToMonthTransition() {
        var path: [TraditionalNavigationDestination] = []
        let march = Self.makeDate(year: 2026, month: 3)
        let march15 = Self.makeDate(year: 2026, month: 3, day: 15)
        path.append(.month(march))
        path.append(.day(march15))

        path.removeLast()

        #expect(path.count == 1)
        #expect(path[0] == .month(march))
    }

    /// Removing last from a month-only path simulates month → year back navigation.
    /// Setup: Path with [month], remove last.
    /// Expected: Path is empty (root year view).
    @Test func testMonthBackToYearTransition() {
        var path: [TraditionalNavigationDestination] = []
        let march = Self.makeDate(year: 2026, month: 3)
        path.append(.month(march))

        path.removeLast()

        #expect(path.isEmpty)
    }

    /// Removing all elements returns to root year view.
    /// Setup: Path with [month, day], remove all.
    /// Expected: Path is empty.
    @Test func testFullBackToYearTransition() {
        var path: [TraditionalNavigationDestination] = []
        let march = Self.makeDate(year: 2026, month: 3)
        let march15 = Self.makeDate(year: 2026, month: 3, day: 15)
        path.append(.month(march))
        path.append(.day(march15))

        path.removeAll()

        #expect(path.isEmpty)
    }

    // MARK: - Day Data at Navigation Destination

    /// Day view at a navigation destination should show correct entries.
    /// Setup: Tasks on Mar 15, navigate to .day(Mar 15).
    /// Expected: Virtual spread data model has the matching tasks.
    @Test func testDayDestinationShowsCorrectEntries() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let march15 = Self.makeDate(year: 2026, month: 3, day: 15)

        let tasks = [
            DataModel.Task(title: "Task A", date: march15, period: .day),
            DataModel.Task(title: "Task B", date: march15, period: .day),
        ]

        // Simulate what the day view does at this destination
        let destination = TraditionalNavigationDestination.day(march15)
        if case .day(let dayDate) = destination {
            let dataModel = service.virtualSpreadDataModel(
                period: .day, date: dayDate, tasks: tasks, notes: [], events: []
            )
            #expect(dataModel.tasks.count == 2)
        }
    }

    /// Month view at a navigation destination should include only month-period entries.
    /// Setup: Day task in March, navigate to .month(March).
    /// Expected: Virtual spread data model excludes the day task.
    @Test func testMonthDestinationShowsCorrectEntries() {
        let service = TraditionalSpreadService(calendar: Self.testCalendar)
        let march1 = Self.makeDate(year: 2026, month: 3)
        let march15 = Self.makeDate(year: 2026, month: 3, day: 15)

        let tasks = [
            DataModel.Task(title: "Task A", date: march15, period: .day),
        ]

        // Simulate what the month view does at this destination
        let destination = TraditionalNavigationDestination.month(march1)
        if case .month(let monthDate) = destination {
            let dataModel = service.virtualSpreadDataModel(
                period: .month, date: monthDate, tasks: tasks, notes: [], events: []
            )
            #expect(dataModel.tasks.count == 0)
        }
    }
}
