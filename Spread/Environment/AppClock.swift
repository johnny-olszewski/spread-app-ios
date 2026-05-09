import Foundation
import Observation
import OSLog

struct AppClockContext {
    let now: Date
    let calendar: Calendar
    let timeZone: TimeZone
    let locale: Locale

    func updating(
        now: Date? = nil,
        calendar: Calendar? = nil,
        timeZone: TimeZone? = nil,
        locale: Locale? = nil
    ) -> AppClockContext {
        let resolvedTimeZone = timeZone ?? self.timeZone
        let resolvedLocale = locale ?? self.locale
        var resolvedCalendar = calendar ?? self.calendar
        resolvedCalendar.timeZone = resolvedTimeZone
        resolvedCalendar.locale = resolvedLocale

        return AppClockContext(
            now: now ?? self.now,
            calendar: resolvedCalendar,
            timeZone: resolvedTimeZone,
            locale: resolvedLocale
        )
    }
}

struct AppClockSnapshot {
    let now: Date
    let calendar: Calendar
    let timeZone: TimeZone
    let locale: Locale
    let refreshMetadata: AppClockRefreshMetadata
    let refreshRevision: Int
    let semanticRefreshRevision: Int
}

struct AppClockRefreshMetadata {
    enum Reason: Equatable {
        case initial
        case sceneDidBecomeActive
        case significantTimeChange
        case calendarDayChanged
        case systemTimeZoneChanged
        case currentLocaleChanged
        case currentCalendarChanged
        case manual
    }

    let reason: Reason
    let previousNow: Date
    let refreshedAt: Date
    let crossedDayBoundary: Bool
    let calendarChanged: Bool
    let timeZoneChanged: Bool
    let localeChanged: Bool

    static func classify(
        previous: AppClockContext,
        current: AppClockContext,
        reason: Reason
    ) -> AppClockRefreshMetadata {
        AppClockRefreshMetadata(
            reason: reason,
            previousNow: previous.now,
            refreshedAt: current.now,
            crossedDayBoundary: !current.calendar.isDate(previous.now, inSameDayAs: current.now),
            calendarChanged: AppClockCalendarSignature(calendar: previous.calendar)
                != AppClockCalendarSignature(calendar: current.calendar),
            timeZoneChanged: previous.timeZone.identifier != current.timeZone.identifier,
            localeChanged: previous.locale.identifier != current.locale.identifier
        )
    }
}

private struct AppClockCalendarSignature: Equatable {
    let identifier: Calendar.Identifier
    let firstWeekday: Int
    let minimumDaysInFirstWeek: Int

    init(calendar: Calendar) {
        identifier = calendar.identifier
        firstWeekday = calendar.firstWeekday
        minimumDaysInFirstWeek = calendar.minimumDaysInFirstWeek
    }
}

@MainActor
final class AppClockSource {
    private let nowProvider: () -> Date
    private let calendarProvider: () -> Calendar
    private let timeZoneProvider: () -> TimeZone
    private let localeProvider: () -> Locale
    private var fixedContext: AppClockContext?

    init(
        now: @escaping () -> Date,
        calendar: @escaping () -> Calendar,
        timeZone: @escaping () -> TimeZone,
        locale: @escaping () -> Locale,
        fixedContext: AppClockContext? = nil
    ) {
        nowProvider = now
        calendarProvider = calendar
        timeZoneProvider = timeZone
        localeProvider = locale
        self.fixedContext = fixedContext
    }

    static func live(fixedContext: AppClockContext? = nil) -> AppClockSource {
        AppClockSource(
            now: { .now },
            calendar: { .autoupdatingCurrent },
            timeZone: { .autoupdatingCurrent },
            locale: { .autoupdatingCurrent },
            fixedContext: fixedContext
        )
    }

    func currentContext() -> AppClockContext {
        if let fixedContext {
            return fixedContext
        }

        let now = nowProvider()
        let timeZone = timeZoneProvider()
        let locale = localeProvider()
        var calendar = calendarProvider()
        calendar.timeZone = timeZone
        calendar.locale = locale

        return AppClockContext(
            now: now,
            calendar: calendar,
            timeZone: timeZone,
            locale: locale
        )
    }

    func setFixedContext(_ context: AppClockContext?) {
        fixedContext = context
    }

    var isUsingFixedContext: Bool {
        fixedContext != nil
    }
}

@Observable
@MainActor
final class AppClock {
    private static let logger = Logger(subsystem: "dev.johnnyo.Spread", category: "AppClock")

    private let source: AppClockSource
    private let notificationBridge: AppClockNotificationBridge?
    private var observers: [UUID: (AppClockSnapshot) -> Void] = [:]

    private(set) var now: Date
    private(set) var calendar: Calendar
    private(set) var timeZone: TimeZone
    private(set) var locale: Locale
    private(set) var refreshMetadata: AppClockRefreshMetadata
    private(set) var refreshRevision = 0
    private(set) var semanticRefreshRevision = 0

    init(
        source: AppClockSource? = nil,
        notificationBridge: AppClockNotificationBridge? = nil
    ) {
        let resolvedSource = source ?? AppClockSource.live()
        let initialContext = resolvedSource.currentContext()
        self.source = resolvedSource
        self.notificationBridge = notificationBridge
        now = initialContext.now
        calendar = initialContext.calendar
        timeZone = initialContext.timeZone
        locale = initialContext.locale
        refreshMetadata = AppClockRefreshMetadata(
            reason: .initial,
            previousNow: initialContext.now,
            refreshedAt: initialContext.now,
            crossedDayBoundary: false,
            calendarChanged: false,
            timeZoneChanged: false,
            localeChanged: false
        )
        notificationBridge?.start { [weak self] reason in
            self?.refresh(reason: reason)
        }
    }

    static func live() -> AppClock {
        AppClock(
            source: .live(),
            notificationBridge: AppClockNotificationBridge.live()
        )
    }

    static func fixed(
        now: Date,
        calendar: Calendar,
        timeZone: TimeZone,
        locale: Locale
    ) -> AppClock {
        AppClock(
            source: AppClockSource(
                now: { now },
                calendar: { calendar },
                timeZone: { timeZone },
                locale: { locale },
                fixedContext: AppClockContext(
                    now: now,
                    calendar: calendar,
                    timeZone: timeZone,
                    locale: locale
                )
            ),
            notificationBridge: nil
        )
    }

    var context: AppClockContext {
        AppClockContext(now: now, calendar: calendar, timeZone: timeZone, locale: locale)
    }

    var snapshot: AppClockSnapshot {
        AppClockSnapshot(
            now: now,
            calendar: calendar,
            timeZone: timeZone,
            locale: locale,
            refreshMetadata: refreshMetadata,
            refreshRevision: refreshRevision,
            semanticRefreshRevision: semanticRefreshRevision
        )
    }

    @discardableResult
    func addObserver(_ observer: @escaping (AppClockSnapshot) -> Void) -> UUID {
        let id = UUID()
        observers[id] = observer
        return id
    }

    func removeObserver(_ id: UUID) {
        observers[id] = nil
    }

    var isUsingFixedContext: Bool {
        source.isUsingFixedContext
    }

    func sceneDidBecomeActive() {
        refresh(reason: .sceneDidBecomeActive)
    }

    func setContextOverride(
        _ context: AppClockContext?,
        reason: AppClockRefreshMetadata.Reason
    ) {
        source.setFixedContext(context)
        refresh(reason: reason)
    }

    func refresh(reason: AppClockRefreshMetadata.Reason) {
        let previousContext = context
        let nextContext = source.currentContext()
        refreshMetadata = AppClockRefreshMetadata.classify(
            previous: previousContext,
            current: nextContext,
            reason: reason
        )
        now = nextContext.now
        calendar = nextContext.calendar
        timeZone = nextContext.timeZone
        locale = nextContext.locale
        refreshRevision += 1
        semanticRefreshRevision += 1

        Self.logger.debug(
            "Refreshed app clock. reason=\(String(describing: reason), privacy: .public) revision=\(self.refreshRevision) semanticRevision=\(self.semanticRefreshRevision)"
        )

        let latestSnapshot = snapshot
        for observer in observers.values {
            observer(latestSnapshot)
        }
    }
}
