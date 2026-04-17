#if DEBUG
import Foundation
import Testing
@testable import Spread

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
}
#endif
