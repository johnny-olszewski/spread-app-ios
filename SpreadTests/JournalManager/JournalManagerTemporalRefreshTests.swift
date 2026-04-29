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
        let manager = try await JournalManager.make(
            appClock: appClock,
            bujoMode: .conventional
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

        #expect(manager.titleNavigatorModel.headerModel.today == Self.nextDayContext.now)
        #expect(manager.overdueTaskCount == 1)
        #expect(manager.dataVersion == initialDataVersion)
    }

    /// Conditions: The shared AppClock advances into a new month while the JournalManager and
    /// conventional title-navigator provider stay alive.
    /// Expected: Recommendations recompute from the refreshed temporal inputs without rebuilding
    /// the runtime or requiring explicit reload calls.
    @Test("Title navigator recommendations follow refreshed AppClock dates")
    func titleNavigatorRecommendationsRefreshFromAppClock() async throws {
        let clockSource = AppClockSource(
            now: { Self.monthBoundaryInitialContext.now },
            calendar: { Self.calendar },
            timeZone: { Self.calendar.timeZone },
            locale: { Self.calendar.locale! },
            fixedContext: Self.monthBoundaryInitialContext
        )
        let appClock = AppClock(source: clockSource, notificationBridge: nil)
        let manager = try await JournalManager.make(
            appClock: appClock,
            bujoMode: .conventional
        )
        let provider = TodayMissingSpreadRecommendationProvider()

        let initialRecommendations = provider.recommendations(for: manager.titleNavigatorModel.headerModel)
        #expect(initialRecommendations.map(\.date) == [
            Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 31))!
        ])

        clockSource.setFixedContext(Self.monthBoundaryNextContext)
        appClock.refresh(reason: .calendarDayChanged)

        let refreshedRecommendations = provider.recommendations(for: manager.titleNavigatorModel.headerModel)
        #expect(refreshedRecommendations.map(\.date) == [
            Self.calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!,
            Self.calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!,
            Self.calendar.date(from: DateComponents(year: 2026, month: 2, day: 1))!
        ])
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

    private static var monthBoundaryInitialContext: AppClockContext {
        AppClockContext(
            now: calendar.date(from: DateComponents(year: 2026, month: 1, day: 31, hour: 18))!,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale!
        )
    }

    private static var monthBoundaryNextContext: AppClockContext {
        AppClockContext(
            now: calendar.date(from: DateComponents(year: 2026, month: 2, day: 1, hour: 9))!,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale!
        )
    }
}
