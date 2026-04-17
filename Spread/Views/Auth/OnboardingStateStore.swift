import Foundation

protocol OnboardingStateStoring {
    var hasCompletedOnboarding: Bool { get }
    func markCompleted()
}

/// UserDefaults-backed onboarding completion store.
struct OnboardingStateStore: OnboardingStateStoring {
    private let userDefaults: UserDefaults
    private let key: String

    init(
        userDefaults: UserDefaults = .standard,
        key: String = "hasCompletedOnboarding"
    ) {
        self.userDefaults = userDefaults
        self.key = key
    }

    var hasCompletedOnboarding: Bool {
        userDefaults.bool(forKey: key)
    }

    func markCompleted() {
        userDefaults.set(true, forKey: key)
    }
}
