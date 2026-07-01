import Foundation
import Testing
@testable import Spread

@MainActor
struct PresentedTemporalContextTests {
    /// Conditions: A sheet captures temporal inputs from JournalManager, then the shared
    /// AppClock advances into the next day before the sheet would be dismissed.
    /// Expected: Configurations built from the captured context keep their original defaults
    /// while equivalent live configurations move to the new day.
    @Test("Presented temporal context freezes form defaults across AppClock refreshes")
    func presentedContextFreezesFormDefaults() async throws {
        let clockSource = AppClockSource(
            now: { Self.initialContext.now },
            calendar: { Self.calendar },
            timeZone: { Self.calendar.timeZone },
            locale: { Self.calendar.locale! },
            fixedContext: Self.initialContext
        )
        let appClock = AppClock(source: clockSource, notificationBridge: nil)
        let manager = try await JournalManager(appClock: appClock)
        let presentedContext = PresentedTemporalContext(journalManager: manager)

        clockSource.setFixedContext(Self.nextDayContext)
        appClock.refresh(reason: .significantTimeChange)

        let frozenTaskConfiguration = EntryCreationConfiguration(
            calendar: presentedContext.calendar,
            today: presentedContext.today
        )
        let liveTaskConfiguration = EntryCreationConfiguration(
            calendar: manager.calendar,
            today: manager.today
        )
        let frozenNoteConfiguration = EntryCreationConfiguration(
            calendar: presentedContext.calendar,
            today: presentedContext.today
        )
        let liveNoteConfiguration = EntryCreationConfiguration(
            calendar: manager.calendar,
            today: manager.today
        )
        let frozenSpreadConfiguration = SpreadCreationConfiguration(
            calendar: presentedContext.calendar,
            today: presentedContext.today,
            firstWeekday: .sunday,
            existingSpreads: []
        )
        let liveSpreadConfiguration = SpreadCreationConfiguration(
            calendar: manager.calendar,
            today: manager.today,
            firstWeekday: .sunday,
            existingSpreads: []
        )

        #expect(frozenTaskConfiguration.defaultSelection(from: DataModel.Spread?.none).date == Self.initialContext.now)
        #expect(liveTaskConfiguration.defaultSelection(from: DataModel.Spread?.none).date == Self.nextDayContext.now)
        #expect(frozenNoteConfiguration.defaultSelection(from: DataModel.Spread?.none).date == Self.initialContext.now)
        #expect(liveNoteConfiguration.defaultSelection(from: DataModel.Spread?.none).date == Self.nextDayContext.now)
        #expect(
            frozenSpreadConfiguration.minimumDate(for: .day)
            == Self.initialContext.now.startOfDay(calendar: Self.calendar)
        )
        #expect(
            liveSpreadConfiguration.minimumDate(for: .day)
            == Self.nextDayContext.now.startOfDay(calendar: Self.calendar)
        )
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
