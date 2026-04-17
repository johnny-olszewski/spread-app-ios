import Testing
@testable import Spread

struct DataEnvironmentTests {

    // MARK: - Resolution from Launch Arguments

    /// Conditions: Launch argument `-DataEnvironment localhost` is provided.
    /// Expected: Should resolve to localhost regardless of other inputs.
    @Test func testResolvesLocalhostFromLaunchArgument() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "localhost"],
            environmentVariables: [:],
            buildDefault: .production
        )
        #expect(result == .localhost)
    }

    /// Conditions: Launch argument `-DataEnvironment development` is provided.
    /// Expected: Should resolve to development.
    @Test func testResolvesDevelopmentFromLaunchArgument() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "development"],
            environmentVariables: [:],
            buildDefault: .production
        )
        #expect(result == .development)
    }

    /// Conditions: Launch argument `-DataEnvironment production` is provided.
    /// Expected: Launch args take highest priority, should resolve to production.
    @Test func testLaunchArgumentTakesHighestPriority() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "production"],
            environmentVariables: [:],
            buildDefault: .localhost
        )
        #expect(result == .production)
    }

    /// Conditions: Launch argument `-DataEnvironment` is present but the value is invalid.
    /// Expected: Should fall through to next resolution step.
    @Test func testInvalidLaunchArgumentFallsThrough() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "invalid"],
            environmentVariables: [:],
            buildDefault: .production
        )
        #expect(result == .production)
    }

    /// Conditions: Launch argument `-DataEnvironment` is present but missing the value.
    /// Expected: Should fall through to next resolution step.
    @Test func testMissingLaunchArgumentValueFallsThrough() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment"],
            environmentVariables: [:],
            buildDefault: .development
        )
        #expect(result == .development)
    }

    // MARK: - Resolution from Environment Variables

    /// Conditions: No launch args, env var `DATA_ENVIRONMENT=development` is set.
    /// Expected: Should resolve to development.
    @Test func testResolvesFromEnvironmentVariable() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["DATA_ENVIRONMENT": "development"],
            buildDefault: .production
        )
        #expect(result == .development)
    }

    /// Conditions: Launch arg and env var both set with different values.
    /// Expected: Launch arg takes priority over env var.
    @Test func testLaunchArgumentOverridesEnvironmentVariable() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "localhost"],
            environmentVariables: ["DATA_ENVIRONMENT": "production"],
            buildDefault: .development
        )
        #expect(result == .localhost)
    }

    /// Conditions: Invalid env var value, no launch args.
    /// Expected: Should fall through to build default.
    @Test func testInvalidEnvironmentVariableFallsThrough() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["DATA_ENVIRONMENT": "staging"],
            buildDefault: .production
        )
        #expect(result == .production)
    }

    // MARK: - Build Default Fallback

    /// Conditions: No args or env vars.
    /// Expected: Should use build default.
    @Test func testFallsBackToBuildDefault() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            buildDefault: .production
        )
        #expect(result == .production)
    }

    // MARK: - Behavior Flags

    /// Conditions: localhost data environment.
    /// Expected: No auth required, sync disabled, is local only.
    @Test func testLocalhostBehavior() {
        let env = DataEnvironment.localhost
        #expect(env.requiresAuth == false)
        #expect(env.syncEnabled == false)
        #expect(env.isLocalOnly == true)
    }

    /// Conditions: development data environment.
    /// Expected: Auth required, sync enabled, not local only.
    @Test func testDevelopmentBehavior() {
        let env = DataEnvironment.development
        #expect(env.requiresAuth == true)
        #expect(env.syncEnabled == true)
        #expect(env.isLocalOnly == false)
    }

    /// Conditions: production data environment.
    /// Expected: Auth required, sync enabled, not local only.
    @Test func testProductionBehavior() {
        let env = DataEnvironment.production
        #expect(env.requiresAuth == true)
        #expect(env.syncEnabled == true)
        #expect(env.isLocalOnly == false)
    }

    // MARK: - Full Resolution Order

    /// Conditions: All sources provide values (launch arg, env var, default).
    /// Expected: Launch argument wins.
    @Test func testFullPrecedenceOrderLaunchArgWins() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "localhost"],
            environmentVariables: ["DATA_ENVIRONMENT": "development"],
            buildDefault: .production
        )
        #expect(result == .localhost)
    }

    /// Conditions: No launch arg but env var and default both set.
    /// Expected: Environment variable wins.
    @Test func testFullPrecedenceOrderEnvVarWins() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["DATA_ENVIRONMENT": "development"],
            buildDefault: .localhost
        )
        #expect(result == .development)
    }
}
