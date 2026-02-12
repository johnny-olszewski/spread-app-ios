#if DEBUG
import Foundation

struct AppLaunchConfiguration {
    let mockDataSet: MockDataSet?
    let today: Date?

    static var current: AppLaunchConfiguration {
        resolve(launchArguments: ProcessInfo.processInfo.arguments)
    }

    static func resolve(launchArguments: [String]) -> AppLaunchConfiguration {
        let mockDataSet = mockDataSetValue(from: launchArguments)
        let today = todayValue(from: launchArguments)
        return AppLaunchConfiguration(mockDataSet: mockDataSet, today: today)
    }

    private static func mockDataSetValue(from launchArguments: [String]) -> MockDataSet? {
        guard let rawValue = value(for: "-MockDataSet", in: launchArguments) else {
            return nil
        }
        return MockDataSet(rawValue: rawValue)
    }

    private static func todayValue(from launchArguments: [String]) -> Date? {
        guard let value = value(for: "-Today", in: launchArguments) else {
            return nil
        }
        return dateFromYMD(value)
    }

    private static func value(for key: String, in launchArguments: [String]) -> String? {
        guard let index = launchArguments.firstIndex(of: key),
              index + 1 < launchArguments.count else {
            return nil
        }
        return launchArguments[index + 1]
    }

    private static func dateFromYMD(_ string: String) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: string)
    }
}
#endif
