import Foundation
import Testing
@testable import Spread

@MainActor
struct AppClockTests {
    @Test("AppClock refresh updates temporal context and revision")
    func refreshUpdatesContextAndRevision() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let initialDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!
        let updatedDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 16, hour: 9))!
        let updatedTimeZone = TimeZone(identifier: "America/New_York")!
        let updatedLocale = Locale(identifier: "fr_FR")

        let source = AppClockSource(
            now: { initialDate },
            calendar: { calendar },
            timeZone: { calendar.timeZone },
            locale: { calendar.locale! },
            fixedContext: AppClockContext(
                now: initialDate,
                calendar: calendar,
                timeZone: calendar.timeZone,
                locale: calendar.locale!
            )
        )
        let clock = AppClock(source: source, notificationBridge: nil)

        var updatedCalendar = calendar
        updatedCalendar.timeZone = updatedTimeZone
        updatedCalendar.locale = updatedLocale
        source.setFixedContext(
            AppClockContext(
                now: updatedDate,
                calendar: updatedCalendar,
                timeZone: updatedTimeZone,
                locale: updatedLocale
            )
        )

        clock.refresh(reason: .manual)

        #expect(clock.now == updatedDate)
        #expect(clock.calendar.timeZone.identifier == updatedTimeZone.identifier)
        #expect(clock.locale.identifier == updatedLocale.identifier)
        #expect(clock.semanticRefreshRevision == 1)
        #expect(clock.refreshMetadata.reason == .manual)
        #expect(clock.refreshMetadata.crossedDayBoundary)
        #expect(clock.refreshMetadata.timeZoneChanged)
        #expect(clock.refreshMetadata.localeChanged)
    }

    @Test("AppClock notifies observers with latest snapshot")
    func observersReceiveLatestSnapshot() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let initialDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10))!
        let updatedDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 11))!

        let source = AppClockSource(
            now: { initialDate },
            calendar: { calendar },
            timeZone: { calendar.timeZone },
            locale: { calendar.locale! },
            fixedContext: AppClockContext(
                now: initialDate,
                calendar: calendar,
                timeZone: calendar.timeZone,
                locale: calendar.locale!
            )
        )
        let clock = AppClock(source: source, notificationBridge: nil)

        var observedSnapshot: AppClockSnapshot?
        let observerID = clock.addObserver { snapshot in
            observedSnapshot = snapshot
        }

        source.setFixedContext(
            AppClockContext(
                now: updatedDate,
                calendar: calendar,
                timeZone: calendar.timeZone,
                locale: calendar.locale!
            )
        )
        clock.refresh(reason: .sceneDidBecomeActive)
        clock.removeObserver(observerID)

        #expect(observedSnapshot?.now == updatedDate)
        #expect(observedSnapshot?.refreshMetadata.reason == .sceneDidBecomeActive)
        #expect(observedSnapshot?.semanticRefreshRevision == 1)
    }

    @Test("AppClock does not poll minute changes without an explicit refresh")
    func clockDoesNotIntroduceMinuteTicker() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let initialDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10, minute: 0))!
        let oneMinuteLater = calendar.date(from: DateComponents(year: 2026, month: 1, day: 15, hour: 10, minute: 1))!
        var currentDate = initialDate

        let source = AppClockSource(
            now: { currentDate },
            calendar: { calendar },
            timeZone: { calendar.timeZone },
            locale: { calendar.locale! }
        )
        let clock = AppClock(source: source, notificationBridge: nil)

        currentDate = oneMinuteLater

        #expect(clock.now == initialDate)
        #expect(clock.semanticRefreshRevision == 0)
    }
}
