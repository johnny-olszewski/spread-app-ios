import Testing
@testable import Spread

struct AppEnvironmentTests {

    // MARK: - Resolution from Launch Arguments

    @Test func testResolvesProductionFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "production"],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .production)
    }

    @Test func testResolvesDevelopmentFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "development"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .development)
    }

    @Test func testResolvesPreviewFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "preview"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .preview)
    }

    @Test func testResolvesTestingFromLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Resolution from Environment Variables

    @Test func testResolvesProductionFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "production"],
            isDebugBuild: true
        )
        #expect(environment == .production)
    }

    @Test func testResolvesDevelopmentFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "development"],
            isDebugBuild: false
        )
        #expect(environment == .development)
    }

    @Test func testResolvesPreviewFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "preview"],
            isDebugBuild: false
        )
        #expect(environment == .preview)
    }

    @Test func testResolvesTestingFromEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "testing"],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Launch Arguments Take Priority Over Environment Variables

    @Test func testLaunchArgumentTakesPriorityOverEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "testing"],
            environmentVariables: ["APP_ENVIRONMENT": "production"],
            isDebugBuild: false
        )
        #expect(environment == .testing)
    }

    // MARK: - Default Based on Build Configuration

    @Test func testDefaultsToDevelopmentInDebugBuild() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .development)
    }

    @Test func testDefaultsToProductionInReleaseBuild() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            isDebugBuild: false
        )
        #expect(environment == .production)
    }

    // MARK: - isStoredInMemoryOnly

    @Test func testProductionIsNotStoredInMemoryOnly() {
        #expect(AppEnvironment.production.isStoredInMemoryOnly == false)
    }

    @Test func testDevelopmentIsNotStoredInMemoryOnly() {
        #expect(AppEnvironment.development.isStoredInMemoryOnly == false)
    }

    @Test func testPreviewIsStoredInMemoryOnly() {
        #expect(AppEnvironment.preview.isStoredInMemoryOnly == true)
    }

    @Test func testTestingIsStoredInMemoryOnly() {
        #expect(AppEnvironment.testing.isStoredInMemoryOnly == true)
    }

    // MARK: - usesMockData

    @Test func testProductionDoesNotUseMockData() {
        #expect(AppEnvironment.production.usesMockData == false)
    }

    @Test func testDevelopmentDoesNotUseMockData() {
        #expect(AppEnvironment.development.usesMockData == false)
    }

    @Test func testPreviewUsesMockData() {
        #expect(AppEnvironment.preview.usesMockData == true)
    }

    @Test func testTestingDoesNotUseMockData() {
        #expect(AppEnvironment.testing.usesMockData == false)
    }

    // MARK: - containerName

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

    @Test func testProductionContainerName() {
        #expect(AppEnvironment.production.containerName == "Spread")
    }

    @Test func testDevelopmentContainerName() {
        #expect(AppEnvironment.development.containerName == "Spread.development")
    }

    @Test func testPreviewContainerName() {
        #expect(AppEnvironment.preview.containerName == "Spread.preview")
    }

    @Test func testTestingContainerName() {
        #expect(AppEnvironment.testing.containerName == "Spread.testing")
    }

    // MARK: - Invalid Values

    @Test func testIgnoresInvalidLaunchArgument() {
        let environment = AppEnvironment.resolve(
            launchArguments: ["-AppEnvironment", "invalid"],
            environmentVariables: [:],
            isDebugBuild: true
        )
        #expect(environment == .development)
    }

    @Test func testIgnoresInvalidEnvironmentVariable() {
        let environment = AppEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["APP_ENVIRONMENT": "invalid"],
            isDebugBuild: false
        )
        #expect(environment == .production)
    }
}
