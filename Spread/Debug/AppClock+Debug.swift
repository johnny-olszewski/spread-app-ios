#if DEBUG
import Foundation

extension AppClock {
    func setDebugReferenceDate(
        _ date: Date,
        reason: AppClockRefreshMetadata.Reason = .manual
    ) {
        let updatedContext = context.updating(now: date)
        setContextOverride(updatedContext, reason: reason)
    }

    func advanceDebugClock(
        by components: DateComponents,
        reason: AppClockRefreshMetadata.Reason
    ) {
        guard let nextDate = calendar.date(byAdding: components, to: now) else {
            return
        }

        setDebugReferenceDate(nextDate, reason: reason)
    }

    func setDebugTimeZone(_ timeZone: TimeZone) {
        let updatedContext = context.updating(timeZone: timeZone)
        setContextOverride(updatedContext, reason: .systemTimeZoneChanged)
    }

    func setDebugLocale(_ locale: Locale) {
        let updatedContext = context.updating(locale: locale)
        setContextOverride(updatedContext, reason: .currentLocaleChanged)
    }

    func setDebugCalendarIdentifier(_ identifier: Calendar.Identifier) {
        var calendar = Calendar(identifier: identifier)
        calendar.firstWeekday = context.calendar.firstWeekday
        calendar.minimumDaysInFirstWeek = context.calendar.minimumDaysInFirstWeek
        let updatedContext = context.updating(calendar: calendar)
        setContextOverride(updatedContext, reason: .currentCalendarChanged)
    }

    func clearDebugOverride(
        reason: AppClockRefreshMetadata.Reason = .manual
    ) {
        setContextOverride(nil, reason: reason)
    }
}
#endif
