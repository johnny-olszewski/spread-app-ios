#if DEBUG
import Foundation
import Testing
@testable import Spread

@MainActor
struct AppClockDebugTests {
    /// Conditions: A fixed-context clock is advanced one day through the debug control path.
    /// Expected: The shared AppClock refresh pipeline emits a day-boundary update and increments its revision.
    @Test("Debug clock advance reuses AppClock refresh pipeline")
    func debugAdvanceReusesRefreshPipeline() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let initialDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9))!
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

        clock.advanceDebugClock(by: DateComponents(day: 1), reason: .calendarDayChanged)

        let expectedDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 13, hour: 9))!
        #expect(clock.now == expectedDate)
        #expect(clock.semanticRefreshRevision == 1)
        #expect(clock.refreshMetadata.reason == .calendarDayChanged)
        #expect(clock.refreshMetadata.crossedDayBoundary)
    }

    /// Conditions: A debug-controlled clock mutates locale, time zone, and calendar identity.
    /// Expected: AppClock publishes the updated temporal context and semantic metadata for each change.
    @Test("Debug clock can change locale time zone and calendar context")
    func debugClockChangesTemporalContext() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "en_US")

        let initialDate = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9))!
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

        clock.setDebugTimeZone(TimeZone(identifier: "UTC")!)
        #expect(clock.refreshMetadata.reason == .systemTimeZoneChanged)
        #expect(clock.timeZone.secondsFromGMT() == 0)

        clock.setDebugLocale(Locale(identifier: "fr_FR"))
        #expect(clock.refreshMetadata.reason == .currentLocaleChanged)
        #expect(clock.locale.identifier == "fr_FR")

        clock.setDebugCalendarIdentifier(.buddhist)
        #expect(clock.refreshMetadata.reason == .currentCalendarChanged)
        #expect(clock.calendar.identifier == .buddhist)
        #expect(clock.semanticRefreshRevision == 3)
    }
}
#endif
