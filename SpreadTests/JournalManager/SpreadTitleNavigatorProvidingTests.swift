import Foundation
import Testing
@testable import Spread

/// Tests for JournalManager conformance to SpreadTitleNavigatorProviding.
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

    // MARK: - Conventional Mode

    /// Condition: JournalManager is in conventional mode with one year spread.
    /// Expected: titleNavigatorModel uses conventional mode and carries the spread.
    @Test("Conventional mode: header model uses conventional mode")
    func testConventionalModeHeaderMode() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .conventional
        )
        let yearDate = Self.calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        _ = try await manager.addSpread(period: .year, date: yearDate)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.mode == .conventional)
    }

    /// Condition: JournalManager is in conventional mode.
    /// Expected: titleNavigatorModel header model carries no tasks or notes (strip shows explicit spreads only).
    @Test("Conventional mode: header model carries no tasks or notes")
    func testConventionalModeEmptyTasksAndNotes() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .conventional
        )
        _ = try await manager.addTask(title: "Task", date: Self.today, period: .day)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.tasks.isEmpty)
        #expect(model.headerModel.notes.isEmpty)
        #expect(model.headerModel.events.isEmpty)
    }

    /// Condition: JournalManager is in conventional mode with two spreads.
    /// Expected: titleNavigatorModel header model carries both spreads.
    @Test("Conventional mode: header model carries all spreads")
    func testConventionalModeCarriesSpreads() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .conventional
        )
        let yearDate = Self.calendar.date(from: .init(year: 2026, month: 1, day: 1))!
        let monthDate = Self.calendar.date(from: .init(year: 2026, month: 4, day: 1))!
        _ = try await manager.addSpread(period: .year, date: yearDate)
        _ = try await manager.addSpread(period: .month, date: monthDate)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.spreads.count == 2)
    }

    // MARK: - Traditional Mode

    /// Condition: JournalManager is in traditional mode.
    /// Expected: titleNavigatorModel uses traditional mode.
    @Test("Traditional mode: header model uses traditional mode")
    func testTraditionalModeHeaderMode() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .traditional
        )

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.mode == .traditional)
    }

    /// Condition: JournalManager is in traditional mode with tasks and notes.
    /// Expected: titleNavigatorModel header model carries those tasks and notes.
    @Test("Traditional mode: header model carries tasks and notes")
    func testTraditionalModeCarriesTasksAndNotes() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .traditional
        )
        _ = try await manager.addTask(title: "Task A", date: Self.today, period: .day)
        _ = try await manager.addTask(title: "Task B", date: Self.today, period: .day)

        let model = manager.titleNavigatorModel

        #expect(model.headerModel.tasks.count == 2)
    }

    // MARK: - Mode Switching

    /// Condition: JournalManager switches from conventional to traditional.
    /// Expected: titleNavigatorModel reflects the new mode immediately.
    @Test("Mode switch updates titleNavigatorModel mode")
    func testModeSwitchUpdatesTitleNavigatorModel() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .conventional
        )

        #expect(manager.titleNavigatorModel.headerModel.mode == .conventional)

        manager.bujoMode = .traditional

        #expect(manager.titleNavigatorModel.headerModel.mode == .traditional)
    }

    // MARK: - Overdue Items

    /// Condition: JournalManager has no overdue tasks.
    /// Expected: titleNavigatorModel carries an empty overdueItems list.
    @Test("No overdue tasks: overdueItems is empty")
    func testNoOverdueTasksProducesEmptyOverdueItems() async throws {
        let manager = try await JournalManager.make(
            calendar: Self.calendar,
            today: Self.today,
            bujoMode: .conventional
        )

        let model = manager.titleNavigatorModel

        #expect(model.overdueItems.isEmpty)
    }
}
