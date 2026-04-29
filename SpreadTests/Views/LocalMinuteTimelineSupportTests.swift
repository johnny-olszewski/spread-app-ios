import Foundation
import Testing
@testable import Spread

struct LocalMinuteTimelineSupportTests {
    /// Conditions: A minute-local rendering surface asks for context partway through a minute.
    /// Expected: The support layer snaps to the minute interval without relying on AppClock polling.
    @Test("Minute timeline context snaps to minute boundaries")
    func contextSnapsToMinuteBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")

        let date = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9, minute: 41, second: 27))!
        let context = LocalMinuteTimelineSupport.context(for: date, calendar: calendar)

        let expectedMinuteStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9, minute: 41))!
        let expectedNextMinuteStart = calendar.date(from: DateComponents(year: 2026, month: 1, day: 12, hour: 9, minute: 42))!

        #expect(context.now == date)
        #expect(context.minuteStart == expectedMinuteStart)
        #expect(context.nextMinuteStart == expectedNextMinuteStart)
    }

    /// Conditions: A minute-local rendering surface uses a non-default calendar and time zone.
    /// Expected: The support context preserves the supplied calendar semantics for future day-schedule rendering.
    @Test("Minute timeline context preserves supplied calendar")
    func contextPreservesSuppliedCalendar() {
        var calendar = Calendar(identifier: .buddhist)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        calendar.locale = Locale(identifier: "th_TH")

        let date = calendar.date(from: DateComponents(year: 2569, month: 1, day: 12, hour: 9, minute: 41))!
        let context = LocalMinuteTimelineSupport.context(for: date, calendar: calendar)

        #expect(context.calendar.identifier == .buddhist)
        #expect(context.calendar.timeZone.identifier == "America/New_York")
        #expect(context.calendar.locale?.identifier == "th_TH")
    }
}
