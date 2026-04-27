import Foundation
import Testing
@testable import Spread

@MainActor
struct AppRuntimeFactoryTests {
    /// Conditions: The runtime factory is given an explicit AppClock override during construction.
    /// Expected: The runtime and JournalManager both receive the exact same shared AppClock instance.
    @Test("Runtime factory reuses one shared AppClock instance")
    func runtimeReusesSharedClockInstance() async throws {
        let dependencies = try AppDependencies.make(
            makeNetworkMonitor: { MockNetworkMonitor() }
        )
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 2, day: 3, hour: 9))!
        let sharedClock = AppClock.fixed(
            now: referenceDate,
            calendar: calendar,
            timeZone: calendar.timeZone,
            locale: calendar.locale!
        )

        let runtime = try await AppRuntimeFactory.make(
            dependencies: dependencies,
            configuration: AppRuntimeConfiguration(
                makeAuthService: { _ in MockAuthService() },
                makeAppClock: { sharedClock },
                makeNetworkMonitor: { MockNetworkMonitor() }
            )
        )

        #expect(runtime.appClock === sharedClock)
        #expect(runtime.journalManager.appClock === sharedClock)
    }
}
