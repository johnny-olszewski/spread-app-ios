import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager's titleNavigatorModel property.
@Suite("SpreadTitleNavigatorProviding Tests")
@MainActor
struct SpreadTitleNavigatorProvidingTests {

    // MARK: - Helpers

    private static var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = .init(identifier: "UTC")!
        return cal
    }

    private static var today: Date {
        calendar.date(from: .init(year: 2026, month: 4, day: 13))!
    }

    // MARK: - Header Model

    /// Condition: JournalManager has an existing task.
    /// Expected: titleNavigatorModel carries tasks for title-strip relevance logic.
    @Test("Header model carries tasks")
    func testHeaderModelCarriesTasks() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today
        )
        _ = try await manager.addTask(title: "Task", date: Self.today, period: .day)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.tasks.count == 1)
        #expect(model.headerModel.notes.isEmpty)
        #expect(model.headerModel.events.isEmpty)
    }

    /// Condition: JournalManager has two spreads.
    /// Expected: titleNavigatorModel header model carries both spreads.
    @Test("Header model carries all spreads")
    func testHeaderModelCarriesSpreads() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today
        )
        let yearDate = Self.calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let monthDate = Self.calendar.date(from: .init(year: 2026, month: 4, day: 1))!
        _ = try await manager.addSpread(period: .year, date: yearDate)
        _ = try await manager.addSpread(period: .month, date: monthDate)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.spreads.count == 2)
    }

    // MARK: - Overdue Items

    /// Condition: JournalManager has no overdue tasks.
    /// Expected: titleNavigatorModel carries an empty overdueItems list.
    @Test("No overdue tasks: overdueItems is empty")
    func testNoOverdueTasksProducesEmptyOverdueItems() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today
        )

        let model = manager.titleNavigatorModel

        #expect(model.overdueItems.isEmpty)
    }
}
