import Foundation
import Testing
@testable import Spread

@Suite(.serialized)
struct OnboardingStateStoreTests {
    private let suiteName = "OnboardingStateStoreTests"
    private let key = "hasCompletedOnboarding"

    /// Conditions: The onboarding key has not been written yet.
    /// Expected: The store reports onboarding as incomplete.
    @Test func defaultsToIncomplete() {
        let userDefaults = makeUserDefaults()
        let store = OnboardingStateStore(userDefaults: userDefaults, key: key)

        #expect(store.hasCompletedOnboarding == false)
    }

    /// Conditions: The user completes onboarding.
    /// Expected: Completion persists in the backing UserDefaults store.
    @Test func markCompletedPersistsCompletion() {
        let userDefaults = makeUserDefaults()
        let store = OnboardingStateStore(userDefaults: userDefaults, key: key)

        store.markCompleted()

        #expect(store.hasCompletedOnboarding == true)
        #expect(userDefaults.bool(forKey: key) == true)
    }

    private func makeUserDefaults() -> UserDefaults {
        let userDefaults = UserDefaults(suiteName: suiteName)!
        userDefaults.removePersistentDomain(forName: suiteName)
        return userDefaults
    }
}
