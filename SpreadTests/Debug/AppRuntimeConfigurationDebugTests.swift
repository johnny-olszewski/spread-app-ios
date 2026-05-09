#if DEBUG
import Foundation
import Testing
@testable import Spread

@MainActor
struct AppRuntimeConfigurationDebugTests {

    /// Conditions: Debug launch config selects a mock data set in localhost mode.
    /// Expected: The data set is accepted for launch-time loading.
    @Test func localhostAllowsLaunchMockDataSet() {
        let launchConfiguration = AppLaunchConfiguration.resolve(
            launchArguments: ["-MockDataSet", "baseline"]
        )

        let dataSet = AppRuntimeConfiguration.mockDataSetToLoad(
            environment: .localhost,
            launchConfiguration: launchConfiguration
        )

        #expect(dataSet == .baseline)
    }

    /// Conditions: Debug launch config selects a mock data set in a product environment.
    /// Expected: Launch-time mock data loading is ignored.
    @Test func productEnvironmentIgnoresLaunchMockDataSet() {
        let launchConfiguration = AppLaunchConfiguration.resolve(
            launchArguments: ["-MockDataSet", "baseline"]
        )

        let dataSet = AppRuntimeConfiguration.mockDataSetToLoad(
            environment: .development,
            launchConfiguration: launchConfiguration
        )

        #expect(dataSet == nil)
    }

    /// Conditions: A localhost launch fixes multiple temporal inputs at startup.
    /// Expected: The debug runtime builds an AppClock with the specified date, time zone, locale, and calendar.
    @Test func launchConfigurationBuildsFixedStartupClockContext() {
        let launchConfiguration = AppLaunchConfiguration.resolve(
            launchArguments: [
                "-Today", "2026-01-12",
                "-TimeZone", "UTC",
                "-Locale", "fr_FR",
                "-Calendar", "buddhist"
            ]
        )

        let appClock = AppRuntimeConfiguration.appClock(for: launchConfiguration)

        #expect(appClock.isUsingFixedContext)
        #expect(appClock.timeZone.secondsFromGMT() == 0)
        #expect(appClock.locale.identifier == "fr_FR")
        #expect(appClock.calendar.identifier == .buddhist)
        #expect(appClock.now == launchConfiguration.today)
    }

    @Test func launchConfigurationCanEnableTemporalHarness() {
        let launchConfiguration = AppLaunchConfiguration.resolve(
            launchArguments: ["-ShowTemporalHarness", "YES"]
        )

        #expect(launchConfiguration.showsTemporalHarness)
    }
}
#endif
