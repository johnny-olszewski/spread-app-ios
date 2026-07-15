import Foundation
import Testing
@testable import Spread

/// Reproduction tests for a live bug report: a task with preferred period `.day` whose
/// preferred day has no created day spread — so its *current* assignment falls back to a
/// covering multiday spread (`findBestSpread`) — appears to lose its `scheduledTime` after
/// a sync round-trip, even though the create/edit code paths persist it correctly in
/// isolation. These tests exercise the exact production call sequence (`JournalManager` →
/// `TaskCoordinator` → `JournalRuleEngine`) end-to-end to pin down which step, if any,
/// actually clears it, since `TaskScheduledTimeMigrationTests` only tests
/// `reconcileScheduledTime` in isolation, not the full multiday-fallback shape.
@MainActor
struct ScheduledTimeMultidayFallbackTests {

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func makeDate(year: Int, month: Int, day: Int, hour: Int = 0, minute: Int = 0) -> Date {
        makeCalendar().date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    /// Setup: only a multiday spread covering "this week" exists (no day spread for
    /// tomorrow). A task is created with preferred period `.day`/date tomorrow and a
    /// scheduled time — so its *current* assignment falls back to the multiday spread
    /// while its *preferred* fields remain day/tomorrow (the exact shape reported live).
    /// Expected: The task's current assignment is the multiday spread (confirming the
    /// fallback), and `scheduledTime` survives creation.
    @Test("Creating a day-preferred task with a time falls back to multiday assignment but keeps the time")
    func createWithTimeFallsBackToMultidayButKeepsTime() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 7, day: 13)
        let tomorrow = Self.makeDate(year: 2026, month: 7, day: 14)
        let scheduledTime = Self.makeDate(year: 2026, month: 7, day: 14, hour: 13, minute: 0)

        let journalManager = try await JournalManager(calendar: calendar, today: today)
        _ = try await journalManager.addMultidaySpread(
            startDate: Self.makeDate(year: 2026, month: 7, day: 13),
            endDate: Self.makeDate(year: 2026, month: 7, day: 19)
        )

        let task = try await journalManager.addTask(
            title: "Surf 28",
            date: tomorrow,
            period: .day,
            preferredSpreadID: nil,
            body: nil,
            priority: .none,
            dueDate: nil,
            scheduledTime: scheduledTime
        )

        #expect(task.currentAssignments.count == 1)
        #expect(task.currentAssignments.first?.period == .multiday)
        #expect(task.date == tomorrow)
        #expect(task.period == .day)
        #expect(task.scheduledTime == scheduledTime)
        #expect(task.scheduledTimeUpdatedAt != nil)
    }

    /// Setup: same multiday-fallback shape, but the task is created *without* a time
    /// first (mirroring "ive tried both ways" — edit case), then a time is added via
    /// `updateTaskMetadata` exactly as `TaskEntrySheet.saveEdits` calls it.
    /// Expected: `scheduledTime` is set and survives the metadata save.
    @Test("Adding a time via updateTaskMetadata survives on a multiday-fallback task")
    func addingTimeViaMetadataSurvivesOnMultidayFallbackTask() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 7, day: 13)
        let tomorrow = Self.makeDate(year: 2026, month: 7, day: 14)
        let scheduledTime = Self.makeDate(year: 2026, month: 7, day: 14, hour: 13, minute: 0)

        let journalManager = try await JournalManager(calendar: calendar, today: today)
        _ = try await journalManager.addMultidaySpread(
            startDate: Self.makeDate(year: 2026, month: 7, day: 13),
            endDate: Self.makeDate(year: 2026, month: 7, day: 19)
        )

        let task = try await journalManager.addTask(
            title: "Surf 28",
            date: tomorrow,
            period: .day,
            preferredSpreadID: nil,
            body: nil,
            priority: .none,
            dueDate: nil,
            scheduledTime: nil
        )
        #expect(task.currentAssignments.first?.period == .multiday)
        #expect(task.scheduledTime == nil)

        try await journalManager.updateTaskMetadata(
            task,
            body: task.body,
            priority: task.priority,
            dueDate: task.dueDate,
            scheduledTime: scheduledTime,
            list: task.list,
            tags: task.tags
        )

        #expect(task.scheduledTime == scheduledTime)
    }

    /// Setup: replicates `TaskEntrySheet.saveEdits`'s *exact* two-step sequence on an
    /// existing multiday-fallback task — `updateTaskMetadata` (setting the time) followed
    /// unconditionally by `updateTaskDateAndPeriod` with the task's *unchanged* preferred
    /// date/period/spreadID (mirroring what the sheet calls when its "did anything change"
    /// check trips, and — to be thorough — even when it wouldn't need to).
    /// Expected: `scheduledTime` set by the metadata step is still present after the
    /// subsequent date/period reconciliation call, since the date/period genuinely didn't
    /// change (day → same day).
    @Test("Time survives a same-day updateTaskDateAndPeriod call that follows the metadata save")
    func timeSurvivesRedundantDateAndPeriodReconciliation() async throws {
        let calendar = Self.makeCalendar()
        let today = Self.makeDate(year: 2026, month: 7, day: 13)
        let tomorrow = Self.makeDate(year: 2026, month: 7, day: 14)
        let scheduledTime = Self.makeDate(year: 2026, month: 7, day: 14, hour: 13, minute: 0)

        let journalManager = try await JournalManager(calendar: calendar, today: today)
        _ = try await journalManager.addMultidaySpread(
            startDate: Self.makeDate(year: 2026, month: 7, day: 13),
            endDate: Self.makeDate(year: 2026, month: 7, day: 19)
        )

        let task = try await journalManager.addTask(
            title: "Surf 28",
            date: tomorrow,
            period: .day,
            preferredSpreadID: nil,
            body: nil,
            priority: .none,
            dueDate: nil,
            scheduledTime: nil
        )
        let fallbackMultidaySpreadID = task.currentAssignments.first(where: { $0.period == .multiday })?.spreadID

        try await journalManager.updateTaskMetadata(
            task,
            body: task.body,
            priority: task.priority,
            dueDate: task.dueDate,
            scheduledTime: scheduledTime,
            list: task.list,
            tags: task.tags
        )
        #expect(task.scheduledTime == scheduledTime)

        // Exactly what saveEdits passes: task's own current preferred date/period, and the
        // multiday spread ID the form model would have captured from currentAssignments.
        try await journalManager.updateTaskDateAndPeriod(
            task,
            newDate: tomorrow,
            newPeriod: .day,
            preferredSpreadID: fallbackMultidaySpreadID
        )

        #expect(task.scheduledTime == scheduledTime)
        #expect(task.currentAssignments.first?.period == .multiday)
    }
}
