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
            persistedSelection: .production,
            allowsDebugUI: true,
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
            persistedSelection: nil,
            allowsDebugUI: false,
            buildDefault: .production
        )
        #expect(result == .development)
    }

    /// Conditions: Launch argument `-DataEnvironment production` is provided in a debug build
    /// with a persisted selection of localhost.
    /// Expected: Launch args take highest priority, should resolve to production.
    @Test func testLaunchArgumentOverridesPersistedSelection() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "production"],
            environmentVariables: [:],
            persistedSelection: .localhost,
            allowsDebugUI: true,
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
            persistedSelection: nil,
            allowsDebugUI: false,
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
            persistedSelection: nil,
            allowsDebugUI: false,
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
            persistedSelection: nil,
            allowsDebugUI: false,
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
            persistedSelection: nil,
            allowsDebugUI: true,
            buildDefault: .development
        )
        #expect(result == .localhost)
    }

    /// Conditions: Invalid env var value, no launch args.
    /// Expected: Should fall through to next resolution step.
    @Test func testInvalidEnvironmentVariableFallsThrough() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["DATA_ENVIRONMENT": "staging"],
            persistedSelection: nil,
            allowsDebugUI: false,
            buildDefault: .production
        )
        #expect(result == .production)
    }

    // MARK: - Persisted Selection (Debug/QA Only)

    /// Conditions: No args/env vars, debug UI allowed, persisted selection is development.
    /// Expected: Should use persisted selection.
    @Test func testUsesPersistedSelectionInDebugBuild() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            persistedSelection: .development,
            allowsDebugUI: true,
            buildDefault: .localhost
        )
        #expect(result == .development)
    }

    /// Conditions: No args/env vars, debug UI NOT allowed (Release), persisted selection exists.
    /// Expected: Should ignore persisted selection and use build default.
    @Test func testIgnoresPersistedSelectionInReleaseBuild() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            persistedSelection: .development,
            allowsDebugUI: false,
            buildDefault: .production
        )
        #expect(result == .production)
    }

    /// Conditions: No args/env vars, debug UI allowed, no persisted selection.
    /// Expected: Should use build default.
    @Test func testUsesDefaultWhenNoPersistedSelection() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            persistedSelection: nil,
            allowsDebugUI: true,
            buildDefault: .localhost
        )
        #expect(result == .localhost)
    }

    // MARK: - Build Default Fallback

    /// Conditions: No args, env vars, or persisted selection. Release build.
    /// Expected: Should use build default.
    @Test func testFallsBackToBuildDefault() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            persistedSelection: nil,
            allowsDebugUI: false,
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

    /// Conditions: All sources provide values (launch arg, env var, persisted, default).
    /// Expected: Launch argument wins.
    @Test func testFullPrecedenceOrderLaunchArgWins() {
        let result = DataEnvironment.resolve(
            launchArguments: ["-DataEnvironment", "localhost"],
            environmentVariables: ["DATA_ENVIRONMENT": "development"],
            persistedSelection: .production,
            allowsDebugUI: true,
            buildDefault: .production
        )
        #expect(result == .localhost)
    }

    /// Conditions: No launch arg but env var, persisted, and default all set.
    /// Expected: Environment variable wins.
    @Test func testFullPrecedenceOrderEnvVarWins() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: ["DATA_ENVIRONMENT": "development"],
            persistedSelection: .production,
            allowsDebugUI: true,
            buildDefault: .localhost
        )
        #expect(result == .development)
    }

    /// Conditions: No launch arg or env var, persisted and default set, debug build.
    /// Expected: Persisted selection wins.
    @Test func testFullPrecedenceOrderPersistedWins() {
        let result = DataEnvironment.resolve(
            launchArguments: [],
            environmentVariables: [:],
            persistedSelection: .production,
            allowsDebugUI: true,
            buildDefault: .localhost
        )
        #expect(result == .production)
    }
}
