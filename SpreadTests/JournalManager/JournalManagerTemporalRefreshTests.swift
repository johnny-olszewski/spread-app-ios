import Foundation
import Testing
@testable import Spread

@MainActor
struct JournalManagerTemporalRefreshTests {
    /// Conditions: An open day task exists, the shared AppClock crosses midnight, and the
    /// JournalManager remains alive in the same session.
    /// Expected: Overdue semantics refresh from the shared clock while dataVersion stays stable,
    /// so temporal refresh remains passive instead of looking like a data mutation.
    @Test("JournalManager refreshes overdue semantics on clock day-boundary changes")
    func overdueSemanticsRefreshAfterDayBoundary() async throws {
        let clockSource = AppClockSource(
            now: { Self.initialContext.now },
            calendar: { Self.calendar },
            timeZone: { Self.calendar.timeZone },
            locale: { Self.calendar.locale! },
            fixedContext: Self.initialContext
        )
        let appClock = AppClock(source: clockSource, notificationBridge: nil)
        let manager = try await JournalManager(
            appClock: appClock,
        )
        _ = try await manager.addTask(
            title: "Follow up",
            date: Self.initialContext.now,
            period: .day
        )
        let initialDataVersion = manager.dataVersion

        #expect(manager.overdueTaskCount == 0)

        clockSource.setFixedContext(Self.nextDayContext)
        appClock.refresh(reason: .sceneDidBecomeActive)

        #expect(manager.today == Self.nextDayContext.now)
        #expect(manager.overdueTaskCount == 1)
        #expect(manager.dataVersion == initialDataVersion)
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private static var initialContext: AppClockContext {
        AppClockContext(
            now: calendar.date(from: DateComponents(year: 2026, month: 4, day: 13, hour: 10))!,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale!
        )
    }

    private static var nextDayContext: AppClockContext {
        AppClockContext(
            now: calendar.date(from: DateComponents(year: 2026, month: 4, day: 14, hour: 9))!,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale!
        )
    }
}
