import Testing
@testable import Spread

struct AppEnvironmentTests {

    // MARK: - Resolution from Launch Arguments

    /// Conditions: Launch arguments contain "-AppEnvironment preview".
    /// Expected: Should resolve to preview environment.
    @Test func testResolvesPreviewFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "preview"],
            environmentVariables: [:]
        )
        #expect(environment == .preview)
    }

    /// Conditions: Launch arguments contain "-AppEnvironment testing".
    /// Expected: Should resolve to testing environment.
    @Test func testResolvesTestingFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: [:]
        )
        #expect(environment == .testing)
    }

    /// Conditions: Launch arguments contain "-AppEnvironment live".
    /// Expected: Should resolve to live environment.
    @Test func testResolvesLiveFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "live"],
            environmentVariables: [:]
        )
        #expect(environment == .live)
    }

    // MARK: - Resolution from Environment Variables

    /// Conditions: Environment variable APP_ENVIRONMENT set to "preview", no launch args.
    /// Expected: Should resolve to preview environment from env var.
    @Test func testResolvesPreviewFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "preview"]
        )
        #expect(environment == .preview)
    }

    /// Conditions: Environment variable APP_ENVIRONMENT set to "testing", no launch args.
    /// Expected: Should resolve to testing environment from env var.
    @Test func testResolvesTestingFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "testing"]
        )
        #expect(environment == .testing)
    }

    // MARK: - Launch Arguments Take Priority Over Environment Variables

    /// Conditions: Both launch arg (testing) and env var (preview) are set.
    /// Expected: Launch argument should take priority, resolving to testing.
    @Test func testLaunchArgumentTakesPriorityOverEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: ["APP_ENVIRONMENT": "preview"]
        )
        #expect(environment == .testing)
    }

    // MARK: - Default

    /// Conditions: No launch args or env vars.
    /// Expected: Should default to live.
    @Test func testDefaultsToLive() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:]
        )
        #expect(environment == .live)
    }

    // MARK: - isStoredInMemoryOnly

    /// Conditions: Live environment.
    /// Expected: Should use persistent storage (not memory-only).
    @Test func testLiveIsNotStoredInMemoryOnly() {
        #expect(AppEnvironment.live.isStoredInMemoryOnly == false)
    }

    /// Conditions: Preview environment.
    /// Expected: Should use in-memory storage for fast SwiftUI previews.
    @Test func testPreviewIsStoredInMemoryOnly() {
        #expect(AppEnvironment.preview.isStoredInMemoryOnly == true)
    }

    /// Conditions: Testing environment.
    /// Expected: Should use in-memory storage for test isolation.
    @Test func testTestingIsStoredInMemoryOnly() {
        #expect(AppEnvironment.testing.isStoredInMemoryOnly == true)
    }

    // MARK: - usesMockData

    /// Conditions: Live environment.
    /// Expected: Should not use mock data.
    @Test func testLiveDoesNotUseMockData() {
        #expect(AppEnvironment.live.usesMockData == false)
    }

    /// Conditions: Preview environment.
    /// Expected: Should use mock data for SwiftUI previews.
    @Test func testPreviewUsesMockData() {
        #expect(AppEnvironment.preview.usesMockData == true)
    }

    /// Conditions: Testing environment.
    /// Expected: Should not use mock data (tests control their own data).
    @Test func testTestingDoesNotUseMockData() {
        #expect(AppEnvironment.testing.usesMockData == false)
    }

    // MARK: - containerName

    /// Conditions: Check all three environment container names.
    /// Expected: Each environment should have a unique container name.
    @Test func testContainerNamesAreUnique() {
        let names = [
            AppEnvironment.live.containerName,
            AppEnvironment.preview.containerName,
            AppEnvironment.testing.containerName
        ]
        let uniqueNames = Set(names)
        #expect(uniqueNames.count == 3)
    }

    /// Conditions: Live environment.
    /// Expected: Container name should be "Spread" (base name).
    @Test func testLiveContainerName() {
        #expect(AppEnvironment.live.containerName == "Spread")
    }

    /// Conditions: Preview environment.
    /// Expected: Container name should be "Spread.preview".
    @Test func testPreviewContainerName() {
        #expect(AppEnvironment.preview.containerName == "Spread.preview")
    }

    /// Conditions: Testing environment.
    /// Expected: Container name should be "Spread.testing".
    @Test func testTestingContainerName() {
        #expect(AppEnvironment.testing.containerName == "Spread.testing")
    }

    // MARK: - Invalid Values

    /// Conditions: Launch argument has invalid value "invalid".
    /// Expected: Should fall back to live (default), ignoring invalid value.
    @Test func testIgnoresInvalidLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "invalid"],
            environmentVariables: [:]
        )
        #expect(environment == .live)
    }

    /// Conditions: Environment variable has invalid value "invalid".
    /// Expected: Should fall back to live (default), ignoring invalid value.
    @Test func testIgnoresInvalidEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "invalid"]
        )
        #expect(environment == .live)
    }
}
