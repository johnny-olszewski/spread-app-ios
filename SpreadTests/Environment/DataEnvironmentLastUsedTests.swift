import Foundation
import Testing
@testable import Spread

/// Tests must run serially since they share UserDefaults state.
@Suite(.serialized)
struct DataEnvironmentLastUsedTests {

    // Use the same key as the implementation
    private static let lastUsedKey = "DataEnvironment.lastUsed"

    /// Clears the last-used value before each test.
    private func clearLastUsed() {
        UserDefaults.standard.removeObject(forKey: Self.lastUsedKey)
        UserDefaults.standard.synchronize()
    }

    // MARK: - Last Used Tracking

    /// Conditions: No last-used environment has been set.
    /// Expected: lastUsed returns nil.
    @Test func lastUsedReturnsNilWhenNotSet() {
        clearLastUsed()

        #expect(DataEnvironment.lastUsed == nil)
    }

    /// Conditions: Last-used environment is set to development.
    /// Expected: lastUsed returns .development.
    @Test func lastUsedReturnsStoredValue() {
        clearLastUsed()
        UserDefaults.standard.set("development", forKey: Self.lastUsedKey)

        #expect(DataEnvironment.lastUsed == .development)

        // Cleanup
        clearLastUsed()
    }

    /// Conditions: markAsLastUsed is called with .production.
    /// Expected: lastUsed returns .production.
    @Test func markAsLastUsedPersistsValue() {
        clearLastUsed()

        DataEnvironment.markAsLastUsed(.production)

        #expect(DataEnvironment.lastUsed == .production)

        // Cleanup
        clearLastUsed()
    }

    // MARK: - Launch Mismatch Detection

    /// Conditions: Last-used is localhost, current is development.
    /// Expected: requiresWipeOnLaunch returns true to isolate localhost data.
    @Test func requiresWipeOnLaunchDetectsLocalhostExit() {
        clearLastUsed()
        UserDefaults.standard.set("localhost", forKey: Self.lastUsedKey)

        let requiresWipe = DataEnvironment.requiresWipeOnLaunch(current: .development)

        #expect(requiresWipe == true)

        // Cleanup
        clearLastUsed()
    }

    /// Conditions: Last-used is development, current is localhost.
    /// Expected: requiresWipeOnLaunch returns true to isolate localhost data.
    @Test func requiresWipeOnLaunchDetectsLocalhostEntry() {
        clearLastUsed()
        UserDefaults.standard.set("development", forKey: Self.lastUsedKey)

        let requiresWipe = DataEnvironment.requiresWipeOnLaunch(current: .localhost)

        #expect(requiresWipe == true)

        // Cleanup
        clearLastUsed()
    }

    /// Conditions: Last-used matches current environment.
    /// Expected: requiresWipeOnLaunch returns false.
    @Test func requiresWipeOnLaunchReturnsFalseWhenMatching() {
        clearLastUsed()
        UserDefaults.standard.set("development", forKey: Self.lastUsedKey)

        let requiresWipe = DataEnvironment.requiresWipeOnLaunch(current: .development)

        #expect(requiresWipe == false)

        // Cleanup
        clearLastUsed()
    }

    /// Conditions: Last-used is development and current is production.
    /// Expected: requiresWipeOnLaunch returns false because only localhost transitions wipe.
    @Test func requiresWipeOnLaunchIgnoresProductEnvironmentMismatch() {
        clearLastUsed()
        UserDefaults.standard.set("development", forKey: Self.lastUsedKey)

        let requiresWipe = DataEnvironment.requiresWipeOnLaunch(current: .production)

        #expect(requiresWipe == false)

        // Cleanup
        clearLastUsed()
    }

    /// Conditions: No last-used environment (first launch).
    /// Expected: requiresWipeOnLaunch returns false.
    @Test func requiresWipeOnLaunchReturnsFalseOnFirstLaunch() {
        clearLastUsed()

        let requiresWipe = DataEnvironment.requiresWipeOnLaunch(current: .development)

        #expect(requiresWipe == false)
    }
}
