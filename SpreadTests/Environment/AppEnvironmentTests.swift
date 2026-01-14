import Testing
@testable import Spread

struct AppEnvironmentTests {

    // MARK: - Resolution from Launch Arguments

    /// Conditions: Launch arguments contain "-AppEnvironment production", debug build is true.
    /// Expected: Should resolve to production environment, overriding debug default.
    @Test func testResolvesProductionFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "production"],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .production)
    }

    /// Conditions: Launch arguments contain "-AppEnvironment development", debug build is false.
    /// Expected: Should resolve to development environment.
    @Test func testResolvesDevelopmentFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "development"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .development)
    }

    /// Conditions: Launch arguments contain "-AppEnvironment preview", debug build is false.
    /// Expected: Should resolve to preview environment.
    @Test func testResolvesPreviewFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "preview"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .preview)
    }

    /// Conditions: Launch arguments contain "-AppEnvironment testing", debug build is false.
    /// Expected: Should resolve to testing environment.
    @Test func testResolvesTestingFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Resolution from Environment Variables

    /// Conditions: Environment variable APP_ENVIRONMENT set to "production", no launch args.
    /// Expected: Should resolve to production environment from env var.
    @Test func testResolvesProductionFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "production"],
            isDebugBuild: true
        )
        #expect(environment == .production)
    }

    /// Conditions: Environment variable APP_ENVIRONMENT set to "development", no launch args.
    /// Expected: Should resolve to development environment from env var.
    @Test func testResolvesDevelopmentFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "development"],
            isDebugBuild: false
        )
        #expect(environment == .development)
    }

    /// Conditions: Environment variable APP_ENVIRONMENT set to "preview", no launch args.
    /// Expected: Should resolve to preview environment from env var.
    @Test func testResolvesPreviewFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "preview"],
            isDebugBuild: false
        )
        #expect(environment == .preview)
    }

    /// Conditions: Environment variable APP_ENVIRONMENT set to "testing", no launch args.
    /// Expected: Should resolve to testing environment from env var.
    @Test func testResolvesTestingFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "testing"],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Launch Arguments Take Priority Over Environment Variables

    /// Conditions: Both launch arg (testing) and env var (production) are set.
    /// Expected: Launch argument should take priority, resolving to testing.
    @Test func testLaunchArgumentTakesPriorityOverEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: ["APP_ENVIRONMENT": "production"],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Default Based on Build Configuration

    /// Conditions: No launch args or env vars, debug build is true.
    /// Expected: Should default to development environment in debug builds.
    @Test func testDefaultsToDevelopmentInDebugBuild() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .development)
    }

    /// Conditions: No launch args or env vars, debug build is false.
    /// Expected: Should default to production environment in release builds.
    @Test func testDefaultsToProductionInReleaseBuild() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .production)
    }

    // MARK: - isStoredInMemoryOnly

    /// Conditions: Production environment.
    /// Expected: Should use persistent storage (not memory-only).
    @Test func testProductionIsNotStoredInMemoryOnly() {
        #expect(AppEnvironment.production.isStoredInMemoryOnly == false)
    }

    /// Conditions: Development environment.
    /// Expected: Should use persistent storage (not memory-only).
    @Test func testDevelopmentIsNotStoredInMemoryOnly() {
        #expect(AppEnvironment.development.isStoredInMemoryOnly == false)
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

    /// Conditions: Production environment.
    /// Expected: Should not use mock data.
    @Test func testProductionDoesNotUseMockData() {
        #expect(AppEnvironment.production.usesMockData == false)
    }

    /// Conditions: Development environment.
    /// Expected: Should not use mock data (uses real data store).
    @Test func testDevelopmentDoesNotUseMockData() {
        #expect(AppEnvironment.development.usesMockData == false)
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

    /// Conditions: Check all four environment container names.
    /// Expected: Each environment should have a unique container name.
    @Test func testContainerNamesAreUnique() {
        let names = [
            AppEnvironment.production.containerName,
            AppEnvironment.development.containerName,
            AppEnvironment.preview.containerName,
            AppEnvironment.testing.containerName
        ]
        let uniqueNames = Set(names)
        #expect(uniqueNames.count == 4)
    }

    /// Conditions: Production environment.
    /// Expected: Container name should be "Spread" (base name).
    @Test func testProductionContainerName() {
        #expect(AppEnvironment.production.containerName == "Spread")
    }

    /// Conditions: Development environment.
    /// Expected: Container name should be "Spread.development".
    @Test func testDevelopmentContainerName() {
        #expect(AppEnvironment.development.containerName == "Spread.development")
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

    /// Conditions: Launch argument has invalid value "invalid", debug build is true.
    /// Expected: Should fall back to development (debug default), ignoring invalid value.
    @Test func testIgnoresInvalidLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "invalid"],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .development)
    }

    /// Conditions: Environment variable has invalid value "invalid", release build.
    /// Expected: Should fall back to production (release default), ignoring invalid value.
    @Test func testIgnoresInvalidEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "invalid"],
            isDebugBuild: false
        )
        #expect(environment == .production)
    }
}
