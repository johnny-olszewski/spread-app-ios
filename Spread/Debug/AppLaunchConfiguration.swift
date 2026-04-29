#if DEBUG
import Foundation

struct AppLaunchConfiguration {
    let mockDataSet: MockDataSet?
    let today: Date?
    let now: Date?
    let timeZone: TimeZone?
    let locale: Locale?
    let calendarIdentifier: Calendar.Identifier?
    let bujoMode: BujoMode?
    let showsTemporalHarness: Bool

    static var current: AppLaunchConfiguration {
        resolve(launchArguments: ProcessInfo.processInfo.arguments)
    }

    static func resolve(launchArguments: [String]) -> AppLaunchConfiguration {
        let mockDataSet = mockDataSetValue(from: launchArguments)
        let timeZone = timeZoneValue(from: launchArguments)
        let today = todayValue(from: launchArguments, timeZone: timeZone ?? .current)
        let now = nowValue(from: launchArguments)
        let locale = localeValue(from: launchArguments)
        let calendarIdentifier = calendarIdentifierValue(from: launchArguments)
        let bujoMode = bujoModeValue(from: launchArguments)
        let showsTemporalHarness = boolValue(for: "-ShowTemporalHarness", in: launchArguments)
        return AppLaunchConfiguration(
            mockDataSet: mockDataSet,
            today: today,
            now: now,
            timeZone: timeZone,
            locale: locale,
            calendarIdentifier: calendarIdentifier,
            bujoMode: bujoMode,
            showsTemporalHarness: showsTemporalHarness
        )
    }

    var startupClockContext: AppClockContext? {
        let referenceDate = now ?? today
        guard referenceDate != nil
                || timeZone != nil
                || locale != nil
                || calendarIdentifier != nil else {
            return nil
        }

        let resolvedTimeZone = timeZone ?? .autoupdatingCurrent
        let resolvedLocale = locale ?? .autoupdatingCurrent
        var calendar = calendarIdentifier.map(Calendar.init(identifier:)) ?? .autoupdatingCurrent
        calendar.timeZone = resolvedTimeZone
        calendar.locale = resolvedLocale

        return AppClockContext(
            now: referenceDate ?? .now,
            calendar: calendar,
            timeZone: resolvedTimeZone,
            locale: resolvedLocale
        )
    }

    private static func mockDataSetValue(from launchArguments: [String]) -> MockDataSet? {
        guard let rawValue = value(for: "-MockDataSet", in: launchArguments) else {
            return nil
        }
        return MockDataSet(rawValue: rawValue)
    }

    private static func todayValue(
        from launchArguments: [String],
        timeZone: TimeZone
    ) -> Date? {
        guard let value = value(for: "-Today", in: launchArguments) else {
            return nil
        }
        return dateFromYMD(value, timeZone: timeZone)
    }

    private static func nowValue(from launchArguments: [String]) -> Date? {
        guard let value = value(for: "-Now", in: launchArguments) else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private static func timeZoneValue(from launchArguments: [String]) -> TimeZone? {
        guard let value = value(for: "-TimeZone", in: launchArguments) else {
            return nil
        }
        return TimeZone(identifier: value)
    }

    private static func localeValue(from launchArguments: [String]) -> Locale? {
        guard let value = value(for: "-Locale", in: launchArguments) else {
            return nil
        }
        return Locale(identifier: value)
    }

    private static func calendarIdentifierValue(
        from launchArguments: [String]
    ) -> Calendar.Identifier? {
        guard let value = value(for: "-Calendar", in: launchArguments) else {
            return nil
        }

        switch value {
        case "gregorian":
            return .gregorian
        case "buddhist":
            return .buddhist
        case "hebrew":
            return .hebrew
        case "islamic":
            return .islamic
        case "islamicCivil":
            return .islamicCivil
        case "islamicTabular":
            return .islamicTabular
        case "islamicUmmAlQura":
            return .islamicUmmAlQura
        case "iso8601":
            return .iso8601
        case "japanese":
            return .japanese
        case "persian":
            return .persian
        case "republicOfChina":
            return .republicOfChina
        case "indian":
            return .indian
        case "coptic":
            return .coptic
        case "ethiopicAmeteMihret":
            return .ethiopicAmeteMihret
        case "ethiopicAmeteAlem":
            return .ethiopicAmeteAlem
        default:
            return nil
        }
    }

    private static func bujoModeValue(from launchArguments: [String]) -> BujoMode? {
        guard let value = value(for: "-BujoMode", in: launchArguments) else {
            return nil
        }
        return BujoMode(rawValue: value)
    }

    private static func value(for key: String, in launchArguments: [String]) -> String? {
        guard let index = launchArguments.firstIndex(of: key),
              index + 1 < launchArguments.count else {
            return nil
        }
        return launchArguments[index + 1]
    }

    private static func boolValue(for key: String, in launchArguments: [String]) -> Bool {
        guard let index = launchArguments.firstIndex(of: key) else {
            return false
        }

        guard index + 1 < launchArguments.count else {
            return true
        }

        let candidate = launchArguments[index + 1]
        if candidate.hasPrefix("-") {
            return true
        }

        switch candidate.lowercased() {
        case "1", "true", "yes", "y", "on":
            return true
        default:
            return false
        }
    }

    private static func dateFromYMD(_ string: String, timeZone: TimeZone) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
#endif
